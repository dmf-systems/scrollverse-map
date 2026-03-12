#!/usr/bin/env bash
set -euo pipefail

echo "[DMF7] Creating control panel script at /usr/local/bin/dmf7-control"
cat >/usr/local/bin/dmf7-control <<'EOF'
#!/bin/bash

echo "=============================="
echo " DMF7 CONTROL PANEL "
echo "=============================="

echo "1) Status"
echo "2) Restart"
echo "3) Backup"
echo "4) Update"
echo "5) Logs"
echo "6) Health Check"
echo "7) Start Stack"
echo "8) Stop Stack"
echo "9) Live Monitor"
echo "10) System Report"
echo ""

read -p "Select option: " option

case $option in

1)
dmf7-status
;;

2)
dmf7-restart
;;

3)
dmf7-backup
;;

4)
dmf7-update
;;

5)
dmf7-logs
;;

6)
dmf7-check
;;

7)
dmf7-start
;;

8)
dmf7-stop
;;

9)
dmf7-live
;;

10)
dmf7-report
;;

*)
echo "Invalid option"
;;

esac
EOF
chmod +x /usr/local/bin/dmf7-control

echo "[DMF7] Creating safe reboot helper at /usr/local/bin/dmf7-safe-reboot"
cat >/usr/local/bin/dmf7-safe-reboot <<'EOF'
#!/bin/bash

echo "Creating backup before reboot..."

dmf7-backup

echo "Saving PM2 state..."
pm2 save

echo "Rebooting system..."

reboot
EOF
chmod +x /usr/local/bin/dmf7-safe-reboot

echo "[DMF7] Quick system verification (disk, memory, CPU)"
df -h
free -h
uptime

cat <<'EOF'
====================================================
 DMF7 AUTONOMOUS AI INFRASTRUCTURE FULLY DEPLOYED 
====================================================

Primary Interfaces:

Operator Console : http://72.61.114.167:4100
Gateway API      : http://72.61.114.167:4000
AI Interface     : http://72.61.114.167:3001

Databases:

Neo4j Graph DB   : http://72.61.114.167:7474
Qdrant Vector DB : http://72.61.114.167:6333

Monitoring:

Grafana          : http://72.61.114.167:3000
Netdata          : http://72.61.114.167:19999
Portainer        : http://72.61.114.167:9000

System Control:

dmf7-control
dmf7-status
dmf7-restart
dmf7-backup
dmf7-update

====================================================
 STATUS: PRODUCTION NODE ONLINE 
====================================================
EOF
