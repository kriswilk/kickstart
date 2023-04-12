#!/bin/bash

# local bin directory
mkdir -p ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

# PPAs, updates
sudo add-apt-repository -y ppa:git-core/ppa
sudo apt update && sudo apt upgrade -y

# zsh, oh-my-zsh, p10k
sudo apt install -y zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# git
sudo apt install -y git

# neovim (stable + personal config)
sudo apt install -y libfuse2
curl -fsSL https://github.com/neovim/neovim/releases/download/stable/nvim.appimage --create-dirs -o ~/.local/bin/nvim
chmod u+x ~/.local/bin/nvim
git clone https://github.com/kriswilk/config-nvim.git ~/.config/nvim/

# direnv
curl -sfL https://direnv.net/install.sh | bash

# pip, venv, pipx
sudo apt install -y python3-pip python3-venv
python3 -m pip install --user pipx
python3 -m pipx ensurepath

# pyenv (w/ build dependencies)
curl https://pyenv.run | bash
sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev llvm
