#!/bin/bash

# directories
mkdir ~/.config

# updates
sudo apt update && sudo apt upgrade -y

# starship
curl -sS https://starship.rs/install.sh | sh
starship preset plain-text-symbols -o ~/.config/starship.toml
echo 'eval "$(starship init bash)"' >> ~/.bashrc

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh
echo 'eval "$(uv generate-shell-completion bash)"' >> ~/.bashrc
echo 'eval "$(uvx --generate-shell-completion bash)"' >> ~/.bashrc
