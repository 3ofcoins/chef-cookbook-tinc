fail 'This recipe currently works only with Chef server' if Chef::Config[:solo]

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
      node.save
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
  ':1'].join(':')

conf_dir = "/etc/tinc/#{node['tinc']['network']}"

directory "#{conf_dir}/hosts" do
  recursive true
end

directory "#{conf_dir}/conf.d"

directory '/var/run/tinc'

file "#{conf_dir}/tinc.conf" do
  content <<EOF
Name = $HOST
GraphDumpFile = /var/run/tinc/#{node['tinc']['network']}.dot
Interface = tinc0
EOF
  notifies :restart, 'service[tinc]'
end

tinc_name = node.name.gsub(/[^a-z0-9]/, '_')

file "#{conf_dir}/hosts/#{tinc_name}" do
  content <<EOF
Address = #{node['tinc']['address']}
Subnet = #{node['tinc']['ipv4_address']}
Subnet = #{node['tinc']['ipv6_address']}
EOF
  action :create_if_missing
end

file "#{conf_dir}/tinc-up" do
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

file "#{conf_dir}/tinc-down" do
  content <<EOF
#!/bin/sh
ifconfig $INTERFACE down
EOF
  mode 0755
  notifies :restart, 'service[tinc]'
end

execute "tincd -n #{node['tinc']['network']} -K 4096 < /dev/null" do
  creates "#{conf_dir}/rsa_key.priv"
end

ruby_block 'tinc::host' do
  block do
    node.set['tinc']['host_file'] = File.read("#{conf_dir}/hosts/#{tinc_name}")
    node.save
  end
end

file '/etc/tinc/nets.boot' do
  content "#{node['tinc']['network']}\n"
  notifies :restart, 'service[tinc]'
end

%w(ipv4_address ipv6_address).each do |attr|
  hostsfile_entry node['tinc'][attr] do
    hostname "#{node.name}.#{node['tinc']['network']}"
  end
end

connect_to = []

search(:node, 'tinc_host_file:[* TO *]').each do |peer_node|
  next if peer_node.name == node.name
  peer_name = peer_node.name.gsub(/[^a-z0-9]/, '_')
  file "#{conf_dir}/hosts/#{peer_name}" do
    content peer_node['tinc']['host_file']
    mode 0600
  end
  connect_to << peer_name

  %w(ipv4_address ipv6_address).each do |attr|
    next unless peer_node['tinc'][attr]
    hostsfile_entry peer_node['tinc'][attr] do
      hostname "#{peer_node.name}.#{node['tinc']['network']}"
    end
  end
end

file "#{conf_dir}/conf.d/connect_to.conf" do
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
