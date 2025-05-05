output "acr_ec2_private_ip_alb_dns" {
  description = "Details of the Elastic Container Registry Created, EC2 Instances Private IPs and ALB DNS Name"
  value       = "${module.eks_cluster}"
}
