include_recipe 'sysctl'

iptables_rule 'port_tinc' if node['tinc']['iptables']

package 'tinc'

# Find unique IP address by taking 16 bits from node name's MD5,
# double-checking for conflicts by search.

def hex_address_unique?(hex_address)
  return false if hex_address == '0000'
  return false if hex_address == 'ffff'
  if Chef::Config[:solo]
    Chef::Log.warn('Running solo, cannot check address uniqueness')
    return true
  else
    return search(:node, "tinc_hex_address:#{ha}").empty?
  end
end

unless node['tinc']['hex_address']
  require 'digest/md5'
  ha_base = node.name
  loop do
    ha = Digest::MD5.hexdigest(ha_base)[-4..-1]
    if hex_address_unique?(ha)
      node.set['tinc']['hex_address'] = ha
      node.save unless Chef::Config[:solo]
      break
    end
    ha_base = "#{ha_base}'"
  end
end

node.set['tinc']['ipv4_address'] = [
  node['tinc']['ipv4_subnet'],
  node['tinc']['hex_address'][0..1].to_i(16),
  node['tinc']['hex_address'][2..3].to_i(16)
].join('.')

node.set['tinc']['ipv6_address'] = [
  node['tinc']['ipv6_subnet'],
  node['tinc']['hex_address'],
  '0:0:0:1'].join(':')

directory "/etc/tinc/#{node['tinc']['net']}/hosts" do
  recursive true
end

directory "/etc/tinc/#{node['tinc']['net']}/conf.d"

directory '/var/run/tinc'

file "/etc/tinc/#{node['tinc']['net']}/tinc.conf" do
  content <<EOF
Name = #{node['tinc']['name']}
GraphDumpFile = /var/run/tinc.dot
Interface = #{node['tinc']['interface']}
EOF
  notifies :restart, 'service[tinc]'
end

file "/etc/tinc/#{node['tinc']['net']}/hosts/#{node['tinc']['name']}" do
  content <<EOF
Address = #{node['tinc']['address']}
Subnet = #{node['tinc']['ipv4_address']}
Subnet = #{node['tinc']['ipv6_address']}
EOF
  action :create_if_missing
end

file "/etc/tinc/#{node['tinc']['net']}/tinc-up" do
  content <<EOF
#!/bin/sh
ifconfig $INTERFACE up \\
    #{node['tinc']['ipv4_address']} netmask 255.255.0.0 \\
    add #{node['tinc']['ipv6_address']}/64
ip -6 route add #{node['tinc']['ipv6_subnet']}::/48 dev $INTERFACE
EOF
  mode 0755
  notifies :restart, 'service[tinc]'
end

file "/etc/tinc/#{node['tinc']['net']}/tinc-down" do
  content <<EOF
#!/bin/sh
ifconfig $INTERFACE down
EOF
  mode 0755
  notifies :restart, 'service[tinc]'
end

execute "tincd -n #{node['tinc']['net']} -K 4096 < /dev/null" do
  creates "/etc/tinc/#{node['tinc']['net']}/rsa_key.priv"
end

file '/etc/tinc/nets.boot' do
  content "#{node['tinc']['net']}\n"
end

ruby_block 'tinc::host' do
  block do
    node.set['tinc']['host_file'] = File.read("/etc/tinc/#{node['tinc']['net']}/hosts/#{node['tinc']['name']}")
    node.save unless Chef::Config[:solo]
  end
end

connect_to = []

if Chef::Config[:solo]
  Chef::Log.warn 'Running solo, cannot search for peers'
else
  search(:node, 'tinc_host_file:[* TO *]').each do |peer_node|
    next if peer_node.name == node.name
    file "/etc/tinc/#{node['tinc']['net']}/hosts/#{peer_node['tinc']['name']}" do
      content peer_node['tinc']['host_file']
      mode 0600
    end
    connect_to << peer_node['tinc']['name']
  end
end

file "/etc/tinc/#{node['tinc']['net']}/conf.d/connect_to.conf" do
  content connect_to
    .sort
    .map { |peer| "ConnectTo = #{peer}\n" }
    .join
  notifies :reload, 'service[tinc]'
end

service 'tinc' do
  action [:enable, :start]
end

sysctl_param 'net.ipv6.conf.all.forwarding' do
  value 1
end
