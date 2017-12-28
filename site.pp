node default {

  package { ["docker-ce","docker-ce-selinux"]:
    ensure       => absent,
  } ~>

  exec { 'flush_iptables':
    command      => '/sbin/iptables -F && /sbin/iptables -F -t nat; /sbin/iptables --delete-chain DOCKER-ISOLATION; /sbin/iptables --delete-chain DOCKER-USER; /sbin/iptables --delete-chain DOCKER; /sbin/iptables --policy FORWARD ACCEPT && /sbin/iptables --delete-chain DOCKER -t nat && /sbin/iptables-save && /sbin/iptables-save -t nat',
    refreshonly  => true,
  } ->

  sysctl { 'net.ipv4.ip_forward': value => '1' } ->

  exec { 'dnat_rule':
    command      => '/sbin/iptables -t nat -A POSTROUTING -s 10.174.64.0/19 -o eth0 -j MASQUERADE && /sbin/iptables-save -t nat',
    refreshonly  => false,
  } ->

  openvpn::server { 'openvpn':
    country      => 'NA',
    province     => 'NA',
    city         => 'NA',
    organization => 'NA',
    email        => 'admin@na.local',
    server       => '10.174.64.0 255.255.224.0',
    status_log   => "/var/log/openvpn-status.log",
    tcp_nodelay  => true,
    port         => 8443,
    proto        => tcp,
    push         => ["route ENDPOINT 255.255.255.255 GW 1", "redirect-gateway def1","dhcp-option DNS 10.174.64.1"],
  } ->

  dnsmasq::conf { 'bind-interfaces':
    ensure  => present,
    content => 'bind-interfaces'
  } ~>

  dnsmasq::conf { 'interface':
    ensure  => present,
    content => 'interface=eth0'
  } ~>

  dnsmasq::conf { 'interface_lo':
    ensure  => present,
    content => 'interface=lo'
  } ~>

  dnsmasq::conf { 'server':
    ensure  => present,
    content => "server=8.8.8.8"
  } ~>

  dnsmasq::conf { 'interface_tun0':
    ensure  => present,
    content => 'interface=tun0'
  } ->

  openvpn::client { 'admin':
    server => 'openvpn',
    remote_host => "localhost",
    port => 2200,
    proto => tcp, 
  } ~>

  exec { 'start_stunnel':
    command  => "/usr/bin/stunnel /etc/stunnel/stunnel.conf",
    refreshonly => true,
  } ~>

  exec { 'start_nc_listener':
    refreshonly  => true,
    command      => "/bin/nc -l 8188 < /etc/openvpn/openvpn/download-configs/admin.ovpn"
  }

  service { 'haveged':
    ensure    => running,
  }

  file { '/var/log/openvpn-status.log':
    mode             => '0644',
  }
}

