#!/bin/bash

echo "HI FROM AWS"
cd ~

# find existing release and stop it 
bin/first_deploy stop
# find and remove all files and folders besides release and current direcotry dotfiles
find .  -maxdepth 1 \( ! -iname "first_deploy-0.1.0.tar.gz" ! -iname ".*" \) -exec rm -rf {} \;

# find current release and untar it
tar -xvf first_deploy-0.1.0.tar.gz
rm first_deploy-0.1.0.tar.gz

# start it
HOST_URL=18.191.228.147 bin/first_deploy daemon_iex
