default['tinc']['iptables'] = run_context.loaded_recipe?('iptables')
default['tinc']['address'] =
  ( node['cloud'] && node['cloud']['public_ipv4']) || node['ipaddress']
default['tinc']['network'] = 'vine'
default['tinc']['ipv4_subnet'] = '172.23'
default['tinc']['ipv6_subnet'] = 'fc00:c0d1:1337'
