#!/bin/bash
docker restart redis-ai
docker restart qdrant
docker restart neo4j
docker restart ollama
pm2 restart all
systemctl restart nginx
echo "DMF7 stack restarted"
