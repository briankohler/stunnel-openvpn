#!/bin/bash -x

echo 1 >/sys/kernel/mm/ksm/run
echo 1000 >/sys/kernel/mm/ksm/sleep_millisecs
cat /etc/systemd/system.conf | sed -e 's|^#Default\(.*\)Accounting=.*$|Default\1Accounting=yes|g' >/tmp/system.conf
mv /tmp/system.conf /etc/systemd/system.conf
systemctl daemon-reexec
yum install -y epel-release
yum install -y http://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm
yum install -y dnsmasq openvpn easy-rsa nmap-ncat net-tools haveged puppet ruby ruby-devel git
/opt/puppetlabs/puppet/bin/gem install librarian-puppet --no-ri --no-rdoc
while [ ! -f /etc/site.pp ]
do
  echo "Waiting"
  sleep 2
done
mv /etc/Puppetfile /etc/puppetlabs/puppet/
mv /etc/site.pp /etc/puppetlabs/puppet/
cd /etc/puppetlabs/puppet
HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/puppetlabs/bin:/root/bin /opt/puppetlabs/puppet/bin/librarian-puppet install
/opt/puppetlabs/puppet/bin/puppet apply site.pp --modulepath=/etc/puppetlabs/puppet/modules --debug --verbose
yum install -y /etc/*.rpm

cat > /etc/firehol/fireqos.conf << END
interface eth0 eth0 bidirectional ethernet rate 20000Mbit ceil 20000Mbit quantum 150000 burst 150000 cburst 150000 balanced

server_netdata_ports="tcp/19999"
server_http_ports="tcp/80"
client_http_ports="tcp/80"
server_https_ports="tcp/443"
client_https_ports="tcp/443"
server_openvpn_ports="tcp/443"
client_openvpn_ports="tcp/443"
server_dns_ports="tcp/53,udp/53"

       class arp
         match arp

       class icmp
         match icmp

       class dns
         server dns

       class ntp
	client ntp

       class ssh
        server ssh
        client ssh

       class rsync
        server rsync
        client rsync

       class http
        server http
	client http

       class https
        server https
	client https

       class openvpn
        server openvpn
	client openvpn

       class netdata
        server netdata

END

sed -i 's/User=netdata/User=root/g' /usr/lib/systemd/system/netdata.service
systemctl daemon-reload
echo "[global]" > /etc/netdata/netdata.conf
echo "run as user = root" >> /etc/netdata/netdata.conf
echo "web files owner = root" >> /etc/netdata/netdata.conf
echo "web files group = netdata" >> /etc/netdata/netdata.conf
service fireqos start
service netdata start

