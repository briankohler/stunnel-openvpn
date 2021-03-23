#!/bin/bash  

PUBLIC_IP=$(curl -s ifconfig.me)
echo "Stopping OpenVPN..."
pkill OpenVPNConnect
if [ -z "${DO_TOKEN}" ]
then
  echo "Input DigitalOcean API token: "
  read DO_TOKEN
fi
echo "Destroying remote servers..."
./terraform destroy -force -var do_token=$DO_TOKEN -var public_ip="$PUBLIC_IP" -var gateway="$(netstat -anr | grep default | head -n1 | awk '{print $2}')"
echo "Cleaning up..."
rm -rf stunnel.pid terraform stunnel.pem puppet/stunnel.pem puppet/site.pp id_rsa* terraform.tfstate* .terraform *.ovpn
