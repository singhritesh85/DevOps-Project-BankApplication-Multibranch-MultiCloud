output "registry_id" {
  description = "Registry ID of repository"
  value = aws_ecr_repository.ecr.registry_id
}
output "repository_url" {
  description = "The URL of Repository"
  value = aws_ecr_repository.ecr.repository_url
}
output "EC2_Instance_Blaxbox_Exporter_Server_Private_IP_Address" {
  description = "Private IP Address of Balckbox Exporter Server EC2 Instance"
  value = aws_instance.blackbox_exporter.private_ip 
}
output "EC2_Instance_Prometheus_Server_Private_IP_Address" {
  description = "Private IP Address of Prometheus Server EC2 Instance"
  value = aws_instance.prometheus.private_ip
}
output "EC2_Instance_Grafana_Server_Private_IP_Address" {
  description = "Private IP Address of Grafana Server EC2 Instance"
  value = aws_instance.grafana.private_ip
}
output "EC2_Instance_Loki_Servers_Private_IP_Addresses" {
  description = "Private IP Address of Loki Servers EC2 Instances"
  value = aws_instance.loki.*.private_ip
}
output "EC2_Instance_SonarQube_Server_Private_IP_Address" {
  description = "Private IP Address of SonarQube Server EC2 Instance"
  value = aws_instance.sonarqube.private_ip
}
output "EC2_Instance_Jenkins_Slave_Server_Private_IP_Address" {
  description = "Private IP Address of Jenkins Slave Server EC2 Instance"
  value = aws_instance.jenkins_slave.private_ip
}
output "EC2_Instance_Jenkins_Master_Server_Private_IP_Address" {
  description = "Private IP Address of Jenkins Master Server EC2 Instance"
  value = aws_instance.jenkins_master.private_ip
}
output "Jenkins_ALB_DNS_Name" {
  description = "The DNS name of the Jenkins Application Load Balancer"
  value = aws_lb.test-application-loadbalancer-jenkins.dns_name
}
output "SonarQube_ALB_DNS_Name" {
  description = "The DNS name of the SonarQube Application Load Balancer"
  value = aws_lb.sonarqube-application-loadbalancer.dns_name
}
output "Grafana_ALB_DNS_Name" {
  description = "The DNS name of the Grafana Application Load Balancer"
  value = aws_lb.test-application-loadbalancer_grafana.dns_name
}
output "Loki_ALB_DNS_Name" {
  description = "The DNS name of the Loki Application Load Balancer"
  value = aws_lb.test-application-loadbalancer_loki.dns_name
}
