# terraform-bankapp-multicloud
```
1. First of all clone this repository and change the directory to "terraform-differentbranch-multibranch-multicloud-nonprod".
2. Run the shell script initial-setup.sh only once on your k8s-management-node or terraform-server. As this script will install the kubectl, helm and uninstall awscli version 1.x then install awscli version 2.x. After running this shell script just logout from the logged-in user and then login again.
3. Provide SSH Private Key in the file user_data_blackbox_exporter.sh, user_data_grafana.sh, user_data_jenkins_master.sh, user_data_jenkins_slave.sh, user_data_loki.sh, user_data_nexus.sh, user_data_prometheus.sh and user_data_sonarqube.sh
4. Provide SSH Private Key in the file mykey.pem and assign 600 permission on this file using the command chmod 600 mykey.pem.
5. An IAM Role with the Name "AmazonS3FullAccess" should be existed in the AWS Account(with IAM Policy AmazonS3FullAccess should be attached). The Aim is to provide RBAC Access to EC2 Instances to send Loki logs to S3 Bucket.
6. Provide Certificate ARN, KMS Key ID for RDS, KMS Key ID for EBS and RDS Monitoring Role ARN in the file terraform.tfvars.
7. Use your own .pfx extension file for your certificate in main directory and provide it's password in file module/azure-domain-service.tf.
8. Provide subscription_id and tenant_id for your Azure account in the file provider.tf and subscription_id in the file backend.tf.
```

# Install and configure EKS Container Insight 
```
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/cluster-name/;s/{{region_name}}/cluster-region/" | kubectl apply -f -
```

In this command, cluster-name is the name of your Amazon EKS or Kubernetes cluster, and cluster-region is the name of the Region where the logs are published. We recommend that you use the same Region where your cluster is deployed to reduce the AWS outbound data transfer costs.

```
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/eks-demo-cluster-dev/;s/{{region_name}}/us-east-2/" | kubectl apply -f -
```

Then go to EC2 Instance created as a part of NodeGroup of this EKS Cluster and open it's IAM Role and attach the policy CloudWatchLogsFullAccess . Finally go to Cloudwatch Console, Open Insights > Container Insights. 



Reference:- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-quickstart.html
