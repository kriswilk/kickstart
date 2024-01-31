#!/bin/bash

# PPAs, updates
sudo add-apt-repository -y ppa:git-core/ppa
sudo apt update && sudo apt upgrade -y

# starship
curl -sS https://starship.rs/install.sh | sh
mkdir ~/.config
starship preset plain-text-symbols -o ~/.config/starship.toml
#
echo '' >> ~/.bashrc
echo 'eval "$(starship init bash)"' >> ~/.bashrc

# direnv
curl -qfsSL https://github.com/direnv/direnv/releases/download/v2.33.0/direnv.linux-amd64 -o direnv
chmod +x direnv
sudo mv direnv /usr/local/bin
#
echo '' >> ~/.bashrc
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# pyenv (w/ build dependencies)
sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
curl https://pyenv.run | bash
# 
echo '' >> ~/.bashrc
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
