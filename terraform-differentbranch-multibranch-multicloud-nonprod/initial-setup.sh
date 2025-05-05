#!/bin/bash

############# Install awscli ##############

sudo yum remove -y awscli  ### Remove the installed awscli and then install the latest awscli

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" --output ~/awscliv2.zip
unzip ~/awscliv2.zip -d ~/
sudo ~/aws/install

echo -e "\nPATH="$PATH:/usr/local/bin"" >> ~/.bashrc
source ~/.bashrc

############# Install kubectl #############

curl -LO https://dl.k8s.io/release/v1.29.2/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin

############# Install Helm ################

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 --output ~/get_helm.sh
chmod 700 ~/get_helm.sh
DESIRED_VERSION=v3.8.0 ~/get_helm.sh

#reboot

helm version
kubectl version
aws --version
