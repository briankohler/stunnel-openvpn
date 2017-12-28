#!/bin/bash  

PUBLIC_IP=$(curl -s ifconfig.me)
echo "Stopping Tunnelblick..."
pkill Tunnelblick
if [ -z "${DO_TOKEN}" ]
then
  echo "Input DigitalOcean API token: "
  read DO_TOKEN
fi
echo "Destroying remote servers..."
terraform destroy -force -var do_token=$DO_TOKEN -var public_ip="$PUBLIC_IP" -var gateway="$(netstat -anr | grep default | head -n1 | awk '{print $2}')"
echo "Killing stunnel...."
kill $(cat stunnel.pid)
echo "Cleaning up..."
rm -f stunnel.pid stunnel.pem puppet/stunnel.pem puppet/site.pp id_rsa*
