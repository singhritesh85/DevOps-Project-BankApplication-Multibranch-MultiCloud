#!/bin/bash
/usr/sbin/useradd -s /bin/bash -m ritesh;
mkdir /home/ritesh/.ssh;
chmod -R 700 /home/ritesh;
echo "ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ritesh@DESKTOP-0XXXXXX" >> /home/ritesh/.ssh/authorized_keys;
chmod 600 /home/ritesh/.ssh/authorized_keys;
chown ritesh:ritesh /home/ritesh/.ssh -R;
echo "ritesh  ALL=(ALL)  NOPASSWD:ALL" > /etc/sudoers.d/ritesh;
chmod 440 /etc/sudoers.d/ritesh;

########################## Install git, wget, zip, unzip and vim #############################

yum install -y git wget vim zip unzip

#################################### Loki ##############################################

#useradd --system loki
cd /opt && wget https://github.com/grafana/loki/releases/download/v3.2.1/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
rm -f loki-linux-amd64.zip
cd /opt && wget https://raw.githubusercontent.com/grafana/loki/v3.2.1/cmd/loki/loki-local-config.yaml

LOCAL_SERVER_PRIVATE_IP=`ip addr| grep "noprefixroute eth0" | cut -d ' ' -f 6 | sed s'/\/.*//g'`
sed -i "0,/instance_addr: 127.0.0.1/s//instance_addr: $LOCAL_SERVER_PRIVATE_IP/" /opt/loki-local-config.yaml
sed -i "0,/store: inmemory/s//store: memberlist/" /opt/loki-local-config.yaml
sed -i "0,/object_store: filesystem/s//object_store: azure/" /opt/loki-local-config.yaml
sed -i "0,/loki_address: localhost:3100/s//loki_address: $LOCAL_SERVER_PRIVATE_IP:3100/" /opt/loki-local-config.yaml
sed -i "s%alertmanager_url: http://localhost:9093%alertmanager_url: http://$LOCAL_SERVER_PRIVATE_IP:9093%" /opt/loki-local-config.yaml
#sed -i "0,/replication_factor: 1/s//replication_factor: 3/" /opt/loki-local-config.yaml
sed -i "0,/filesystem:/s//azure:/" /opt/loki-local-config.yaml

cat > /etc/systemd/system/loki.service <<EOF
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/loki-linux-amd64 -config.file=/opt/loki-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF

systemctl enable loki
systemctl start loki

#################################### Installing Promtail #####################################

#useradd --system promtail
cd /opt && wget https://github.com/grafana/loki/releases/download/v3.2.1/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
rm -f promtail-linux-amd64.zip
cd /opt && wget https://raw.githubusercontent.com/grafana/loki/main/clients/cmd/promtail/promtail-local-config.yaml

cat > /etc/systemd/system/promtail.service <<EOT
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/promtail-linux-amd64 -config.file=/opt/promtail-local-config.yaml

[Install]
WantedBy=multi-user.target
EOT

systemctl enable promtail
systemctl start promtail

#################################### Installing Node Exporter #####################################

useradd --system --no-create-home --shell /bin/false node_exporter
cd /opt/ && wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter*

cat > /etc/systemd/system/node_exporter.service <<END_FOR_SCRIPT
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
END_FOR_SCRIPT

systemctl enable node_exporter
systemctl start node_exporter

###############################################################################################

mkdir /mederma;
mkfs.xfs /dev/sdc;
echo "/dev/sdc  /mederma  xfs  defaults 0 0" >> /etc/fstab;
mount -a;
