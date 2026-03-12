#!/bin/bash

echo "==== SCROLLVERSE DEV ENV SETUP ===="

# verify node
if ! command -v node &> /dev/null
then
  echo "Node not found — installing Node 20"

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  nvm install 20
  nvm use 20
  nvm alias default 20
fi

echo "Node version:"
node -v

# install pnpm
if ! command -v pnpm &> /dev/null
then
  npm install -g pnpm
fi

echo "PNPM version:"
pnpm -v

# install turbo
if ! command -v turbo &> /dev/null
then
  npm install -g turbo
fi

echo "Turbo version:"
turbo --version

echo "Environment ready."
