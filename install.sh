#!/bin/bash
set -e

# Install Prometheus manually (optional: use binary or Docker)
sudo apt update
sudo apt install -y wget curl gnupg software-properties-common apt-transport-https ca-certificates

# Add Telegraf repo
curl -s https://repos.influxdata.com/influxdata-archive_compat.key | sudo gpg --dearmor -o /etc/apt/keyrings/influxdata-archive.gpg
echo "deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/influxdata.list

# Add Grafana repo
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt update
sudo apt install -y telegraf grafana

# Optional: Prometheus and Alertmanager manual install here, or via scripts

# Copy configs
sudo mkdir -p /etc/prometheus/rules
sudo cp -r prometheus/* /etc/prometheus/
sudo cp telegraf/telegraf.conf /etc/telegraf/telegraf.conf
sudo cp alertmanager/config.yml /etc/alertmanager/config.yml

# Custom script
sudo mkdir -p /opt/monitoring/scripts
sudo cp scripts/check_old_files.sh /opt/monitoring/scripts/
sudo chmod +x /opt/monitoring/scripts/check_old_files.sh

# Enable services
sudo systemctl restart telegraf
sudo systemctl enable telegraf
sudo systemctl restart grafana-server
sudo systemctl enable grafana-server
