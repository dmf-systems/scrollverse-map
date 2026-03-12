#!/bin/bash

echo "===== SCROLLVERSE SERVICES ====="

echo ""
echo "PM2 SERVICES"
pm2 list

echo ""
echo "DOCKER SERVICES"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "API STATUS"
curl -s http://localhost:6061/status

echo ""
echo "================================"
