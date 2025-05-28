#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Install base packages
sudo apt update
sudo apt install -y wget curl gnupg software-properties-common apt-transport-https ca-certificates

# Create keyrings directory
sudo mkdir -p /etc/apt/keyrings

# Add InfluxData (Telegraf) repo using JAMMY for 24.04 compatibility
curl -s https://repos.influxdata.com/influxdata-archive_compat.key | sudo gpg --dearmor -o /etc/apt/keyrings/influxdata-archive.gpg
echo "deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/influxdata.list

# Add Grafana repo
sudo curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Install Telegraf and Grafana
sudo apt update
sudo apt install -y telegraf grafana

# ---------- Install Alertmanager (manual) ----------
cd /tmp
ALERTMANAGER_VERSION="0.27.0"
wget https://github.com/prometheus/alertmanager/releases/download/v$ALERTMANAGER_VERSION/alertmanager-$ALERTMANAGER_VERSION.linux-amd64.tar.gz
tar -xvf alertmanager-$ALERTMANAGER_VERSION.linux-amd64.tar.gz
sudo mv alertmanager-$ALERTMANAGER_VERSION.linux-amd64 /opt/alertmanager

# Create systemd service
sudo tee /etc/systemd/system/alertmanager.service > /dev/null <<EOF
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/opt/alertmanager/alertmanager --config.file=/etc/alertmanager/config.yml --storage.path=/opt/alertmanager/data
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ---------- Configurations ----------
# Create necessary folders
sudo mkdir -p /etc/prometheus/rules
sudo mkdir -p /etc/alertmanager

# Copy configs
sudo cp -r prometheus/* /etc/prometheus/
sudo cp telegraf/telegraf.conf /etc/telegraf/telegraf.conf
sudo cp alertmanager/config.yml /etc/alertmanager/config.yml

# Optional script
sudo mkdir -p /opt/monitoring/scripts
sudo cp scripts/check_old_files.sh /opt/monitoring/scripts/
sudo chmod +x /opt/monitoring/scripts/check_old_files.sh

# ---------- Enable services ----------
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart telegraf
sudo systemctl enable telegraf
sudo systemctl restart grafana-server
sudo systemctl enable grafana-server
sudo systemctl restart alertmanager
sudo systemctl enable alertmanager

echo "✅ Installation completed: Telegraf, Grafana, Alertmanager configured."
