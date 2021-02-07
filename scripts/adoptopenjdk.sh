#!/usr/bin/env bash

sudo apt-get install wget apt-transport-https gnupg
wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
cat /etc/os-release | grep UBUNTU_CODENAME | cut -d = -f 2
echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb $(cat /etc/os-release | grep VERSION_CODENAME | cut -d = -f 2) main" | sudo tee /etc/apt/sources.list.d/adoptopenjdk.list
sudo apt-get update
sudo apt-cache search adoptopenjdk
sudo apt-get install adoptopenjdk-15-openj9