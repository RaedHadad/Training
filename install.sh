#!/bin/bash

set -e

sudo apt update && sudo apt install -y prometheus telegraf grafana alertmanager

# Copy Prometheus configs
sudo mkdir -p /etc/prometheus/rules
sudo cp prometheus/prometheus.yml /etc/prometheus/
sudo cp prometheus/rules/alerts.yml /etc/prometheus/rules/

# Copy Telegraf config
sudo cp telegraf/telegraf.conf /etc/telegraf/telegraf.conf

# Copy Alertmanager config
sudo cp alertmanager/config.yml /etc/alertmanager/config.yml

# Setup custom script
sudo mkdir -p /opt/monitoring/scripts
sudo cp scripts/check_old_files.sh /opt/monitoring/scripts/
sudo chmod +x /opt/monitoring/scripts/check_old_files.sh

# Restart services
sudo systemctl restart prometheus
sudo systemctl enable prometheus
sudo systemctl restart telegraf
sudo systemctl enable telegraf
sudo systemctl restart grafana-server
sudo systemctl enable grafana-server
sudo systemctl restart alertmanager
sudo systemctl enable alertmanager
