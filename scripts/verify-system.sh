#!/bin/bash

echo "===== SYSTEM VERIFY ====="

echo ""
echo "Node:"
node -v

echo ""
echo "PNPM:"
pnpm -v

echo ""
echo "Docker:"
docker -v

echo ""
echo "PM2:"
pm2 -v

echo ""
echo "Git:"
git --version

echo ""
echo "==== VERIFY COMPLETE ===="
