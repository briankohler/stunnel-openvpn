variable "do_token" {}
provider "digitalocean" {
  version = "1.21.0"
  token = "${var.do_token}"
}

variable "public_ip" {}
variable "gateway" {}

resource "digitalocean_ssh_key" "default" {
  name       = "mykey"
  public_key = "${file("${path.module}/id_rsa.pub")}"
}

data "digitalocean_image" "available" {
  slug = "centos-7-x64"
}

resource "digitalocean_droplet" "proxy" {
  image  = "${data.digitalocean_image.available.id}"
  name   = "ovpn-${replace(var.public_ip, ".", "-")}"
  region = "nyc3"
  size  = "s-1vcpu-1gb"
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


resource "digitalocean_firewall" "proxy" {
  name = "proxy-ipacl-${digitalocean_droplet.proxy.ipv4_address}"
  depends_on  = ["null_resource.replace_endpoint"]

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


resource "null_resource" "import_ovpn" {
  depends_on = ["digitalocean_firewall.proxy"]

  #triggers {
  #  instances = "${digital.openvpn.instance_ids}"
  #}

  provisioner "local-exec" {
    command = "while true; do curl -s ${digitalocean_droplet.proxy.ipv4_address}:8188 > /tmp/_proxy.ovpn; if [ $? -eq 0 ] && [ $(cat /tmp/_proxy.ovpn | wc -l) -gt 1 ]; then break 3; fi; sleep 3; done; cat /tmp/_proxy.ovpn; cat /tmp/_proxy.ovpn > /tmp/proxy.ovpn;"
  }
}


