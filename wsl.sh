#!/bin/bash

### WHITESPACE ###
echo >> ~/.profile
echo >> ~/.bashrc

### UPDATES ###
sudo apt -y update
sudo apt -y upgrade
sudo apt -y clean
sudo apt -y autoremove

### INSTALL RUST ###
# unattended with "-s -- -y"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

### INSTALL UV ###
curl -LsSf https://astral.sh/uv/install.sh | sh
echo 'eval "$(uv generate-shell-completion bash)"' >> ~/.bashrc
echo 'eval "$(uvx --generate-shell-completion bash)"' >> ~/.bashrc

### INSTALL STARSHIP ###
# unattended with "-s -- -y"
curl -sS https://starship.rs/install.sh | sh -s -- -y
mkdir -p ~/.config
starship preset plain-text-symbols -o ~/.config/starship.toml
echo 'eval "$(starship init bash)"' >> ~/.bashrc

### INSTALL DOCKER ###
# add docker's official GPG key
sudo apt -y update
sudo apt -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
# add the docker repo as a source
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
# install docker packages
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# add the current user to docker group (for convenience)
sudo usermod -aG docker $USER
