variable "do_token" {}
provider "digitalocean" {
  token = "${var.do_token}"
}

variable "public_ip" {}
variable "gateway" {}

resource "digitalocean_ssh_key" "default" {
  name       = "mykey"
  public_key = "${file("${path.module}/id_rsa.pub")}"
}

resource "digitalocean_droplet" "proxy" {
  image  = "centos-7-x64"
  name   = "proxy"
  region = "sfo1"
  size   = "512mb"
  ssh_keys = ["${digitalocean_ssh_key.default.id}"]
  user_data = "${file("${path.module}/userdata.sh")}"
}

resource "null_resource" "replace_endpoint" {
  depends_on = ["digitalocean_droplet.proxy"]

  #triggers {
  #  instances = "${digital.openvpn.instance_ids}"
  #}

  provisioner "local-exec" {
    command = "cp site.pp puppet/ ; gsed -i 's/ENDPOINT/${digitalocean_droplet.proxy.ipv4_address}/g' puppet/site.pp; gsed -i 's/GW/${var.gateway}/g' puppet/site.pp"
  }
}


data "template_file" "stunnel_conf" {
  depends_on = ["null_resource.replace_endpoint"]

  template = <<EOF
pid = ${path.module}/stunnel.pid
cert = ${path.module}/stunnel.pem
compression = deflate
client = yes
[openvpn]
accept = 0.0.0.0:2200
connect = ${digitalocean_droplet.proxy.ipv4_address}:443
retry = yes
sslVersion = TLSv1.2
EOF
}

resource "local_file" "stunnel_conf" {
  content = "${data.template_file.stunnel_conf.rendered}"
  filename = "${path.module}/stunnel.conf"
}

resource "digitalocean_firewall" "proxy" {
  name = "only-22"
  depends_on  = ["null_resource.replace_endpoint","local_file.stunnel_conf"]

  droplet_ids = ["${digitalocean_droplet.proxy.id}"]

  inbound_rule = [
    {
      protocol           = "tcp"
      port_range         = "1-65535"
      source_addresses   = ["${var.public_ip}/32"]
    },
    {
      protocol           = "udp"
      port_range         = "1-65535"
      source_addresses   = ["${var.public_ip}/32"]
    }
  ]
  outbound_rule = [
    {
      protocol                = "tcp"
      port_range              = "1-65535"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol                = "udp"
      port_range              = "1-65535"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    }
  ]

  provisioner "file" {
    source = "puppet/"
    destination = "/etc/"

    connection {
      type  = "ssh"
      user  = "root"
      private_key = "${file("${path.module}/id_rsa")}"
      host = "${digitalocean_droplet.proxy.ipv4_address}"
      timeout = "30s"
    }
  }
}

resource "null_resource" "start_stunnel" {
  depends_on = ["digitalocean_firewall.proxy"]
  provisioner "local-exec" {
    command = "stunnel ${path.module}/stunnel.conf"
  }
}

resource "null_resource" "import_ovpn" {
  depends_on = ["null_resource.start_stunnel"]

  #triggers {
  #  instances = "${digital.openvpn.instance_ids}"
  #}

  provisioner "local-exec" {
    command = "while true; do curl -s ${digitalocean_droplet.proxy.ipv4_address}:8188 > /tmp/_proxy.ovpn; if [ $? -eq 0 ] && [ $(cat /tmp/_proxy.ovpn | wc -l) -gt 1 ]; then break 3; fi; sleep 3; done; cat /tmp/_proxy.ovpn; cat /tmp/_proxy.ovpn > /tmp/proxy.ovpn; open /tmp/proxy.ovpn; sleep 10; osascript tunnelblick.scpt;"
  }
}


