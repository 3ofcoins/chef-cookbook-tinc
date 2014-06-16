default['tinc']['name'] = name.gsub(/[^a-z0-9]/, '_')
default['tinc']['net'] = 'default'
default['tinc']['interface'] = 'tinc0'
default['tinc']['iptables'] =
  run_context.cookbook_collection.include?('iptables')
default['tinc']['iptables_allow_internal_traffic'] = true
default['tinc']['address'] =
  ( node['cloud'] && node['cloud']['public_ipv4']) || node['ipaddress']
default['tinc']['ipv4_subnet'] = '172.23'
default['tinc']['ipv6_subnet'] = 'fc00:5ca1:ab1e'
