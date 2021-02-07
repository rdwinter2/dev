#!/usr/bin/env bash

CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# cat <<-EOT >> ~/.bashrc
# export PATH=\$PATH:/home/linuxbrew/.linuxbrew/bin
# . <(flux completion bash)
# EOT
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> ~/.profile
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
brew install gcc fluxcd/tap/flux jq yq
