default['tinc']['iptables'] = run_context.loaded_recipe?('iptables')
default['tinc']['address'] =
  ( node['cloud'] && node['cloud']['public_ipv4']) || node['ipaddress']
default['tinc']['ipv4_subnet'] = '172.23'
default['tinc']['ipv6_subnet'] = 'fc00:5ca1:ab1e'
