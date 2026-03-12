#!/bin/bash

echo "Installing Node stack..."

export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

nvm install 20
nvm use 20

npm install -g pnpm
npm install -g turbo
npm install -g typescript ts-node

echo "Node stack installed."
