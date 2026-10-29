#!/bin/bash
# Install or update the HDD fan control service. Run with sudo.
set -e
cd "$(dirname "$0")"
install -m 755 imac-hddfan.sh /usr/local/sbin/imac-hddfan
install -m 644 imac-hddfan.service /etc/systemd/system/imac-hddfan.service
systemctl daemon-reload
systemctl enable imac-hddfan
systemctl restart imac-hddfan
echo "imac-hddfan installed and running."
