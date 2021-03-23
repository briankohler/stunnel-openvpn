node default {

  exec { 'flush_iptables':
    command     => '/sbin/iptables -F && /sbin/iptables -F -t nat;/sbin/iptables-save && /sbin/iptables-save -t nat',
    refreshonly => true,
  }

  -> sysctl { 'net.ipv4.ip_forward': value => '1' }

  -> exec { 'dnat_rule':
    command     => '/sbin/iptables -t nat -A POSTROUTING -s 10.174.64.0/19 -o eth0 -j MASQUERADE && /sbin/iptables-save -t nat',
    refreshonly => false,
  }

  -> openvpn::server { 'openvpn':
    country      => 'NA',
    province     => 'NA',
    city         => 'NA',
    organization => 'NA',
    sndbuf       => 393216,
    rcvbuf       => 393216,
    email        => 'admin@na.local',
    server       => '10.174.64.0 255.255.224.0',
    status_log   => '/var/log/openvpn-status.log',
    tcp_nodelay  => true,
    port         => '443',
    proto        => tcp,
    push         => ['sndbuf 393216','rcvbuf 393216',
                      'route ENDPOINT 255.255.255.255 GW 1',
                      'redirect-gateway def1','dhcp-option DNS 10.174.64.1'],
  }

  -> dnsmasq::conf { 'bind-interfaces':
    ensure  => present,
    content => 'bind-interfaces'
  }

  ~> dnsmasq::conf { 'interface':
    ensure  => present,
    content => 'interface=eth0'
  }

  ~> dnsmasq::conf { 'interface_lo':
    ensure  => present,
    content => 'interface=lo'
  }

  ~> dnsmasq::conf { 'server':
    ensure  => present,
    content => 'server=1.1.1.1'
  }

  ~> dnsmasq::conf { 'interface_tun0':
    ensure  => present,
    content => 'interface=tun0'
  }

  -> openvpn::client { 'admin':
    server      => 'openvpn',
    remote_host => "${::ipaddress_eth0}",
    port        => '443',
    proto       => tcp,
  }

  ~> exec { 'start_nc_listener':
    refreshonly => true,
    command     => '/bin/nc -l 8188 < /etc/openvpn/openvpn/download-configs/admin.ovpn'
  }

  service { 'haveged':
    ensure    => running,
  }

  file { '/var/log/openvpn-status.log':
    mode             => '0644',
  }
}

