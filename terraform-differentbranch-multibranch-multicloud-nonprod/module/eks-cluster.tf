# EKS CLuster Definition
#-----------------------

resource "aws_eks_cluster" "eksdemo" {
  name     = "${var.eks_cluster}-${var.env[0]}"
  role_arn = aws_iam_role.eksdemorole.arn
  version = var.kubernetes_version[8] 

  vpc_config {
    subnet_ids = concat("${aws_subnet.public_subnet.*.id}", "${aws_subnet.private_subnet.*.id}")
#    subnet_ids = ["subnet-05dd16bc3a73a55ad", "subnet-0ff097df94318f90d", "subnet-06fb9c70358c599e2", "subnet-0a8f252083967e8ba", "subnet-075a21d1c5d03c63d", "subnet-0c6da32ab01e5a2f2" ]                ##### Private and Public Subnet List for Private EKS    
  }

  kubernetes_network_config {
    service_ipv4_cidr = "10.0.0.0/16"
    ip_family         = "ipv4"
  }

  tags = {
    Environment = var.env[0]     ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
    EKS         = "true"
  } 

  depends_on = [
    aws_iam_role_policy_attachment.eksdemorole-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eksdemorole-AmazonEKSVPCResourceController,
    aws_route_table_association.public_route_table_association,
    aws_route_table_association.private_route_table_association_1,
    aws_route_table_association.private_route_table_association_2,
    aws_route_table_association.private_route_table_association_3,
    aws_nat_gateway.nat_gateway, 
    aws_internet_gateway.testIGW, 
  ]
}


#-------------------------
# IAM Role for EKS Cluster
#-------------------------

resource "aws_iam_role" "eksdemorole" {
  name = "${var.eks_iam_role_name}-${var.env[0]}"

  assume_role_policy = file("trust-relationship.json")
  
  tags = {
    Environment = var.env[0]     ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
}

resource "aws_iam_role_policy_attachment" "eksdemorole-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eksdemorole.name
}

resource "aws_iam_role_policy_attachment" "eksdemorole-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eksdemorole.name
}

#--------------------------------------
# Enabling IAM Role for Service Account
#--------------------------------------

data "tls_certificate" "ekstls" {
  url = aws_eks_cluster.eksdemo.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eksopidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.ekstls.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eksdemo.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "eksdoc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eksopidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eksopidc.arn]
      type        = "Federated"
    }
  }
}

#------------------------------------------
#Create Launch Template for EKS Worker Node
#------------------------------------------

resource "aws_launch_template" "eks_launch_template" {
#  image_id               = var.eks_ami_id[1]          ## You can use https://github.com/awslabs/amazon-eks-ami/releases 
  instance_type          = var.instance_type[2]
  name                   = "${var.launch_template_name}-${var.env[0]}"
#  update_default_version = true

  key_name = "eks-test"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.disk_size
      encrypted = true
      kms_key_id = "arn:aws:kms:us-east-2:027330342406:key/d387bfc3-9214-4414-b2eb-8786965c2619"     ### Provide the kms_key_id for your AWS Account.
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Environment = var.env[0]        ##"Dev"
      Owner       = "Ops"
      Billing     = "MyProject"
      "kubernetes.io/cluster/${var.eks_cluster}-${var.env[0]}" = "owned"
    }
  }
  
  tag_specifications {
     resource_type = "volume"
     tags = {
       Environment = var.env[0]       ##"Dev"
       Owner       = "Ops"
       Billing     = "MyProject"
       "kubernetes.io/cluster/${var.eks_cluster}-${var.env[0]}" = "owned"
    }
  } 

#  user_data = filebase64("user_data.sh")

#  user_data = base64encode(templatefile("userdata.tpl", { CLUSTER_NAME = aws_eks_cluster.cluster.name, B64_CLUSTER_CA = aws_eks_cluster.cluster.certificate_authority[0].data, API_SERVER_URL = aws_eks_cluster.cluster.endpoint }))
  
  depends_on = [ aws_eks_cluster.eksdemo ]

}


#-------------------------
# Creating the Worker Node
#-------------------------

resource "aws_eks_node_group" "eksnode" {
  cluster_name    = "${var.eks_cluster}-${var.env[0]}"
  node_group_name = "${var.node_group_name}-${var.env[0]}"
  node_role_arn   = aws_iam_role.eksnoderole.arn
  subnet_ids      = aws_subnet.private_subnet.*.id   ###[element(aws_subnet.private_subnet[*].id,count.index)]    #var.subnet_ids
  
#  subnet_ids = ["subnet-05dd16bc3a73a55ad", "subnet-0ff097df94318f90d", "subnet-06fb9c70358c599e2"]    #### Private Subnet List for Private EKS NodeGroup  
  
#  instance_types  = [ var.instance_types[1] ]
#  disk_size       = var.disk_size
  ami_type        = var.ami_type[0]
  capacity_type   = var.capacity_type[0]
  release_version = var.release_version[8] 

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
  
  launch_template {
    id      = aws_launch_template.eks_launch_template.id
    version = "$Latest"                  ##aws_launch_template.eks_launch_template.version
#    name    = var.launch_template_name
  } 

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  update_config {
    max_unavailable_percentage = 50       ### Maximum percentage of unavailable worker nodes while performing node group update.
  }

  depends_on = [
    aws_launch_template.eks_launch_template,
    aws_iam_role.eksnoderole,
    aws_eks_cluster.eksdemo,
    aws_iam_role_policy_attachment.eksnode-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksnode-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksnode-AmazonEC2ContainerRegistryReadOnly,
  ]
}

#----------------------------
# IAM Role for EKS Node Group
#----------------------------

resource "aws_iam_role_policy" "eksnode_policy" {
  name = "eksnode-policy-${var.env[0]}"
  role = aws_iam_role.eksnoderole.id

  policy = file("autoscalepolicy.json")

}

resource "aws_iam_role" "eksnoderole" {
  name = "${var.eks_nodegrouprole_name}-${var.env[0]}"

  assume_role_policy = file("trust-relationship-nodegroup.json")              ## This is the trust relationship for IAM Role.

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
}

resource "aws_iam_role_policy_attachment" "eksnode-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eksnoderole.name
}

resource "aws_iam_role_policy_attachment" "eksnode-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eksnoderole.name
}

resource "aws_iam_role_policy_attachment" "eksnode-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eksnoderole.name
}


#---------------------------------------
# create EKS EBS CSI Driver Add ons
#---------------------------------------

data "aws_iam_policy_document" "csi" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eksopidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eksopidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_ebs_csi_driver" {
  assume_role_policy = data.aws_iam_policy_document.csi.json
  name               = "eks-ebs-csi-driver-${var.env[0]}"
  
  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }

}

resource "aws_iam_role_policy_attachment" "amazon_ebs_csi_driver" {
  role       = aws_iam_role.eks_ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_policy" "eks_ebs_csi_driver_kms" {
  name        = "KMS_Key_For_Encryption_On_EBS_Policy-${var.env[0]}"
  description = "Policy to encrypt ebs volume created using ebs csi driver"
  policy = file("kms-key-for-encryption-on-ebs.json")   

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
}

resource "aws_iam_role_policy_attachment" "amazon_ebs_csi_driver_kms" {
   role       = aws_iam_role.eks_ebs_csi_driver.name
   policy_arn = aws_iam_policy.eks_ebs_csi_driver_kms.arn
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name      = aws_eks_cluster.eksdemo.id
  addon_name        = var.ebs_csi_name
  addon_version     = var.ebs_csi_version
  service_account_role_arn = aws_iam_role.eks_ebs_csi_driver.arn
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "OVERWRITE"     # use resolve_conflicts_on_update for updating a kubernetes cluster  #resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.eksdemo,
    aws_eks_node_group.eksnode
  ]
  
  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
}

resource "aws_eks_addon" "csi_snapshot_controller" {
  cluster_name      = aws_eks_cluster.eksdemo.id
  addon_name        = "snapshot-controller"
  addon_version     = var.csi_snapshot_controller_version
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "OVERWRITE"     # use resolve_conflicts_on_update for updating a kubernetes cluster  #resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.eksdemo,
    aws_eks_node_group.eksnode
  ]

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
}

resource "aws_eks_addon" "core_dns" {
  cluster_name                = aws_eks_cluster.eksdemo.name
  addon_name                  = "coredns"
  addon_version               = var.addon_version_coredns      ###  "v1.10.1-eksbuild.4"
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "OVERWRITE"    # use resolve_conflicts_on_update for updating a kubernetes cluster 

  ### configuration_values =   ### Configuration value can be provided as per the requirement if needed.

  depends_on = [
    aws_eks_cluster.eksdemo,
    aws_eks_node_group.eksnode
  ]

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
}

#---------------------------------------
# create EKS VPC CNI Add ons
#---------------------------------------

data "aws_iam_policy_document" "vpc_cni" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eksopidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eksopidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "vpc_cni_role" {
  assume_role_policy = data.aws_iam_policy_document.vpc_cni.json
  name               = "vpc-cni-role-${var.env[0]}"
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni_role.name
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eksdemo.name
  addon_name                  = "vpc-cni"
  addon_version               = var.addon_version_vpc_cni    ### "v1.15.1-eksbuild.1"                ### "v1.16.2-eksbuild.1"
  service_account_role_arn    = aws_iam_role.vpc_cni_role.arn
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "OVERWRITE"      # use resolve_conflicts_on_update for updating a kubernetes cluster
  
  depends_on = [
    aws_eks_cluster.eksdemo,
#    aws_eks_node_group.eksnode
  ]

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.eksdemo.name
  addon_name                  = "kube-proxy"
  addon_version               = var.addon_version_kubeproxy   ### "v1.27.6-eksbuild.2"         ### "v1.28.6-eksbuild.2"  
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "OVERWRITE"      # use resolve_conflicts_on_update for updating a kubernetes cluster

  depends_on = [
    aws_eks_cluster.eksdemo,
#    aws_eks_node_group.eksnode
  ]

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }

}

########################################## EKS VPC Endpoint and Guard Duty ###############################################

data "aws_vpc_endpoint_service" "guardduty" {
  service_type = "Interface"
  filter {
    name   = "service-name"
    values = ["${data.aws_partition.amazonwebservices.reverse_dns_prefix}.${data.aws_region.reg.name}.guardduty-data"]
  }
}

data "aws_iam_policy_document" "eks_vpc_guardduty" {
  statement {
    actions = ["*"]

    effect = "Allow"

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }

  statement {
    actions = ["*"]

    effect = "Deny"

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalAccount"

      values = [data.aws_caller_identity.G_Duty.account_id]
    }
  }
}

resource "aws_vpc_endpoint" "eks_vpc_guardduty" {
  vpc_id            = aws_vpc.test_vpc.id
  service_name      = data.aws_vpc_endpoint_service.guardduty.service_name
  vpc_endpoint_type = "Interface"

  policy = data.aws_iam_policy_document.eks_vpc_guardduty.json

  security_group_ids  = [aws_security_group.eks_vpc_endpoint_guardduty.id]
  subnet_ids          = aws_subnet.public_subnet[*].id         # VPC endpoint should be run in the public subnet.
  private_dns_enabled = true      # Private DNS names should be enabled as the agent is looking for guardduty-data.eu-west-2.amazonaws.com endpoint

  tags = {
    Name = "GuarDduty-data-${var.env[0]}"
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }

  depends_on = [
    aws_eks_cluster.eksdemo,
  ]

}

resource "aws_security_group" "eks_vpc_endpoint_guardduty" {
  name_prefix = "vpc-endpoint-guardduty-sg-${var.env[0]}"
  description = "Security Group used by VPC Endpoints."
  vpc_id      = aws_vpc.test_vpc.id

  tags = {
    Name = "vpc-endpoint-guardduty-sg-${var.env[0]}"
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }

  depends_on = [
    aws_eks_cluster.eksdemo,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_vpc_guardduty" {
  security_group_id = aws_security_group.eks_vpc_endpoint_guardduty.id
  description       = "Ingress for port 443."

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_eks_addon" "guard_duty" {
  cluster_name      = aws_eks_cluster.eksdemo.name
  addon_name        = "aws-guardduty-agent"
  addon_version     = var.addon_version_guardduty       ### "v1.4.1-eksbuild.2"
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "OVERWRITE"      # use resolve_conflicts_on_update for updating a kubernetes cluster

  depends_on = [
    aws_eks_cluster.eksdemo,
#    aws_eks_node_group.eksnode
  ]

  tags = {
    Environment = var.env[0]        ##"Dev"
    Owner       = "Ops"
    Billing     = "MyProject"
  }

}

#######################################################################################################
# Create Kubeconfig file 
#######################################################################################################

resource "null_resource" "kubectl" {
    provisioner "local-exec" {
        command = "aws eks --region ${data.aws_region.reg.name} update-kubeconfig --name ${aws_eks_cluster.eksdemo.name} && chmod 600 ~/.kube/config"
    }

    depends_on = [aws_eks_cluster.eksdemo, aws_eks_node_group.eksnode]
}
