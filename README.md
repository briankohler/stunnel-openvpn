# STunnel-OpenVPN

This repo creates a remote OpenVPN server on a cloud provider and automatically connects your computer to it.  Features include:
- New SSH keys and SSL certs generated on every run
- STunnel wrapping so it appears as a normal HTTPS connection
- Terraform provisioning

Requirements:
- Mac OSX only
- Tunnelblick installed
- Homebrew installed
- A DigitalOcean API Key

Create: Run ./create.sh (you will be prompted for elavated rights from time to time)
Destroy: Run ./destroy.sh

