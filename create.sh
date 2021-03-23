#!/bin/bash 

echo "Checking local system for prerequisites..."
terraform -v > /dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "Downloading Terraform..."
  wget https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_darwin_amd64.zip
  unzip terraform_0.11.1_darwin_amd64.zip
  sudo mv terraform /usr/local/bin/
  rm terraform_0.11.1_darwin_amd64.zip
fi

brew install gsed jq > /dev/null 2>&1
echo "Prerequisites installed"
if [ -z "${DO_TOKEN}" ]
then
  echo "Input DigitalOcean API token: "
  read DO_TOKEN
fi
echo "Getting public IP..."
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Public IP is $PUBLIC_IP"
echo "Creating SSH key..."
rm -f id_rsa*
ssh-keygen -f id_rsa -t rsa -N "" > /dev/null 2>&1
chmod 400 id_rsa

echo "Provisioning proxy..."

terraform init
terraform apply -auto-approve -var do_token=$DO_TOKEN -var public_ip="$PUBLIC_IP" -var gateway="$(netstat -anr | grep default | head -n1 | awk '{print $2}')"
echo "Proxy instance provisioned"
echo "Your config is saved to client.ovpn"
cat /tmp/proxy.ovpn > client.ovpn
echo "import your config to tunnelblick or any openvpn-compliant client to connect"
