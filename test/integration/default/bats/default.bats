# -*- shell-script -*-

@test "runs tincd" {
  ps aux | grep 'tincd -n default'
}

@test "Creates tinc0 interface" {
    ip link show tinc0
}

@test "Sets up IPv4 address for tinc0" {
    ip addr show tinc0 | grep 'inet 172\.23\.'
}

@test "Sets up IPv6 address for tinc0" {
    ip addr show tinc0 | grep 'inet6 fc00:5ca1:ab1e:'
}
