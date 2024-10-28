#!/bin/bash

# whitespace
echo >> ~/.profile
echo >> ~/.bashrc

# updates
sudo apt -y update
sudo apt -y upgrade
sudo apt -y clean
sudo apt -y autoremove

# rust (unattended with "-s -- -y")
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh
echo 'eval "$(uv generate-shell-completion bash)"' >> ~/.bashrc
echo 'eval "$(uvx --generate-shell-completion bash)"' >> ~/.bashrc

# starship (unattended with "-s -- -y")
curl -sS https://starship.rs/install.sh | sh -s -- -y
mkdir -p ~/.config
starship preset plain-text-symbols -o ~/.config/starship.toml
echo 'eval "$(starship init bash)"' >> ~/.bashrc
