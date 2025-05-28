#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Log file for Jenkins
LOGFILE="/tmp/install_monitoring_$(date +%Y%m%d_%H%M%S).log"
echo "Starting installation at $(date)" | tee -a "$LOGFILE"

# Install base packages
apt update | tee -a "$LOGFILE"
apt install -y wget curl gnupg software-properties-common apt-transport-https ca-certificates | tee -a "$LOGFILE"

# Create keyrings directory
mkdir -p /etc/apt/keyrings | tee -a "$LOGFILE"

# Add InfluxData (Telegraf) repo, forcing JAMMY for 24.04 compatibility
curl -s https://repos.influxdata.com/influxdata-archive_compat.key | gpg --dearmor -o /etc/apt/keyrings/influxdata-archive.gpg
echo "deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/ubuntu jammy stable" | tee /etc/apt/sources.list.d/influxdata.list | tee -a "$LOGFILE"

# Add Grafana repo
curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list | tee -a "$LOGFILE"

# Add Prometheus repo
curl -fsSL https://packagecloud.io/prometheus-rpm/release/gpgkey | gpg --dearmor -o /etc/apt/keyrings/prometheus.gpg
echo "deb [signed-by=/etc/apt/keyrings/prometheus.gpg] https://packagecloud.io/prometheus-rpm/release/ubuntu jammy main" | tee /etc/apt/sources.list.d/prometheus.list | tee -a "$LOGFILE"

# Install Telegraf, Grafana, and Prometheus
apt update | tee -a "$LOGFILE"
apt install -y telegraf grafana prometheus | tee -a "$LOGFILE"

# ---------- Install Alertmanager (manual) ----------
cd /tmp
ALERTMANAGER_VERSION="0.27.0"
wget https://github.com/prometheus/alertmanager/releases/download/v$ALERTMANAGER_VERSION/alertmanager-$ALERTMANAGER_VERSION.linux-amd64.tar.gz | tee -a "$LOGFILE"
tar -xvf alertmanager-$ALERTMANAGER_VERSION.linux-amd64.tar.gz | tee -a "$LOGFILE"
mkdir -p /opt/alertmanager
mv alertmanager-$ALERTMANAGER_VERSION.linux-amd64/* /opt/alertmanager/
rm -rf alertmanager-$ALERTMANAGER_VERSION.linux-amd64.tar.gz alertmanager-$ALERTMANAGER_VERSION.linux-amd64 | tee -a "$LOGFILE"

# Create Alertmanager systemd service
tee /etc/systemd/system/alertmanager.service > /dev/null <<EOF
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/opt/alertmanager/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/opt/alertmanager/data
Restart=always
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOF
echo "Created Alertmanager systemd service" | tee -a "$LOGFILE"

# ---------- Configurations ----------
# Create necessary directories
mkdir -p /etc/prometheus/rules /etc/alertmanager /opt/alertmanager/data
chown -R nobody:nogroup /opt/alertmanager/data

# Check and copy configuration files from Jenkins workspace
if [ -d "$WORKSPACE/prometheus" ]; then
    cp -r "$WORKSPACE/prometheus/"* /etc/prometheus/
    chown -R prometheus:prometheus /etc/prometheus
    echo "Copied Prometheus configuration" | tee -a "$LOGFILE"
else
    echo "Warning: $WORKSPACE/prometheus/ directory not found. Prometheus configuration not copied." | tee -a "$LOGFILE"
fi

if [ -f "$WORKSPACE/telegraf/telegraf.conf" ]; then
    cp "$WORKSPACE/telegraf/telegraf.conf" /etc/telegraf/telegraf.conf
    chown telegraf:telegraf /etc/telegraf/telegraf.conf
    echo "Copied Telegraf configuration" | tee -a "$LOGFILE"
else
    echo "Warning: $WORKSPACE/telegraf/telegraf.conf not found. Using default Telegraf configuration." | tee -a "$LOGFILE"
fi

if [ -f "$WORKSPACE/alertmanager/alertmanager.yml" ]; then
    cp "$WORKSPACE/alertmanager/alertmanager.yml" /etc/alertmanager/alertmanager.yml
    chown nobody:nogroup /etc/alertmanager/alertmanager.yml
    echo "Copied Alertmanager configuration" | tee -a "$LOGFILE"
else
    echo "Warning: $WORKSPACE/alertmanager/alertmanager.yml not found. Creating basic Alertmanager config." | tee -a "$LOGFILE"
    tee /etc/alertmanager/alertmanager.yml > /dev/null <<EOF
global:
  resolve_timeout: 5m
route:
  receiver: 'default'
receivers:
  - name: 'default'
EOF
    chown nobody:nogroup /etc/alertmanager/alertmanager.yml
fi

if [ -f "$WORKSPACE/scripts/check_old_files.sh" ]; then
    mkdir -p /opt/monitoring/scripts
    cp "$WORKSPACE/scripts/check_old_files.sh" /opt/monitoring/scripts/
    chmod +x /opt/monitoring/scripts/check_old_files.sh
    echo "Copied monitoring script" | tee -a "$LOGFILE"
else
    echo "Warning: $WORKSPACE/scripts/check_old_files.sh not found. Skipping." | tee -a "$LOGFILE"
fi

# ---------- Enable and start services ----------
systemctl daemon-reload | tee -a "$LOGFILE"
for service in telegraf grafana-server prometheus alertmanager; do
    systemctl enable $service | tee -a "$LOGFILE"
    systemctl restart $service | tee -a "$LOGFILE"
    echo "Service $service restarted" | tee -a "$LOGFILE"
done

echo "✅ Installation completed: Telegraf, Grafana, Prometheus, and Alertmanager configured. Log: $LOGFILE" | tee -a "$LOGFILE"
