####################################################### Jenkins Master ALB ########################################################

# Security Group for Jenkins ALB
resource "aws_security_group" "jenkins_master_alb" {
  name        = "Jenkins_master-ALB"
  description = "Security Group for Jenkins Master ALB"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = var.cidr_blocks
    from_port  = 80
    to_port    = 80
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jenkins-Master-ALB-sg"
  }
}

#S3 Bucket to capture ALB access logs
resource "aws_s3_bucket" "s3_bucket_jenkins" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = var.access_log_bucket

  force_destroy = true

  tags = {
    Environment = var.env[0]
  }
}

#S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "s3bucket_encryption_jenkins" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_jenkins[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

#Apply Bucket Policy to S3 Bucket
resource "aws_s3_bucket_policy" "s3bucket_policy_jenkins" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_jenkins[0].id
  policy = <<EOF
    {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Principal": {
             "AWS": "arn:aws:iam::033677994240:root"
         },
         "Action": "s3:PutObject",
         "Resource": "arn:aws:s3:::s3bucketcapturealblogjenkins/application_loadbalancer_log_folder/AWSLogs/${data.aws_caller_identity.G_Duty.account_id}/*"
         }
       ]
    }     
  EOF

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.s3bucket_encryption_jenkins]
}

#Application Loadbalancer Jenkins
resource "aws_lb" "test-application-loadbalancer-jenkins" {
  name               = var.application_loadbalancer_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.jenkins_master_alb.id]           ###var.security_groups
  subnets            = aws_subnet.public_subnet.*.id

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout = var.idle_timeout
  access_logs {
    bucket  = var.access_log_bucket
    prefix  = var.prefix
    enabled = var.enabled
  }

  tags = {
    Environment = var.env[0]
  }

  depends_on = [aws_s3_bucket_policy.s3bucket_policy_jenkins]
}

#Target Group of Application Loadbalancer Jenkins
resource "aws_lb_target_group" "target_group_jenkins" {
  name     = var.target_group_name
  port     = var.instance_port      ##### Don't use protocol when target type is lambda
  protocol = var.instance_protocol  ##### Don't use protocol when target type is lambda
  vpc_id   = aws_vpc.test_vpc.id
  target_type = var.target_type_alb
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  health_check {
    enabled = true ## Indicates whether health checks are enabled. Defaults to true.
    path = var.healthcheck_path     ###"/index.html"
    port = "traffic-port"
    protocol = "HTTP"
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.timeout
    interval            = var.interval
  }
}

##Jenkins Application Loadbalancer listener for HTTP
resource "aws_lb_listener" "alb_listener_front_end_HTTP_Jenkins" {
  load_balancer_arn = aws_lb.test-application-loadbalancer-jenkins.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = var.type[1]
    target_group_arn = aws_lb_target_group.target_group_jenkins.arn
     redirect {    ### Redirect HTTP to HTTPS
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

##Jenkins Application Loadbalancer listener for HTTPS
resource "aws_lb_listener" "alb_listener_front_end_HTTPS" {
  load_balancer_arn = aws_lb.test-application-loadbalancer-jenkins.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = var.type[0]
    target_group_arn = aws_lb_target_group.target_group_jenkins.arn
  }
}

## EC2 Instance1 attachment to Jenkins Target Group
resource "aws_lb_target_group_attachment" "ec2_instance1_attachment_to_tg_jenkins" {
  target_group_arn = aws_lb_target_group.target_group_jenkins.arn
  target_id        = aws_instance.jenkins_master.id               #var.ec2_instance_id[0]
  port             = var.instance_port
}

## EC2 Instance2 attachment to Target Group
#resource "aws_lb_target_group_attachment" "ec2_instance2_attachment_to_tg" {
#  target_group_arn = aws_lb_target_group.target_group.arn
#  target_id        = var.ec2_instance_id[1]
#  port             = var.instance_port
#}

####################################################### SonarQube ALB ##############################################################

#S3 Bucket to capture SonarQube ALB access logs
resource "aws_s3_bucket" "s3_bucket_sonarqube" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = "s3bucketcapturealblogsonarqube"    ###var.access_log_bucket

  force_destroy = true

  tags = {
    Environment = var.env[0]
  }
}

#S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "s3bucket_encryption_sonarqube" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_sonarqube[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

#Apply Bucket Policy to S3 Bucket
resource "aws_s3_bucket_policy" "s3bucket_policy_sonarqube" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_sonarqube[0].id
  policy = <<EOT
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::033677994240:root"
          },
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::s3bucketcapturealblogsonarqube/application_loadbalancer_log_folder/AWSLogs/${data.aws_caller_identity.G_Duty.account_id}/*"
        }
      ]
    } 
  EOT

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.s3bucket_encryption_sonarqube]
}

# Security Group for SonarQube ALB
resource "aws_security_group" "sonarqube_alb" {
  name        = "SonarQube-ALB-SecurityGroup"
  description = "Security Group for SonarQube ALB"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = var.cidr_blocks
    from_port  = 80
    to_port    = 80
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SonarQube-ALB-sg"
  }
}

#SonarQube Application Loadbalancer
resource "aws_lb" "sonarqube-application-loadbalancer" {
  name               = "SonarQube"          ###var.application_loadbalancer_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.sonarqube_alb.id]           ###var.security_groups
  subnets            = aws_subnet.public_subnet.*.id

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout = var.idle_timeout
  access_logs {
    bucket  = "s3bucketcapturealblogsonarqube"       ###var.access_log_bucket
    prefix  = var.prefix
    enabled = var.enabled
  }

  tags = {
    Environment = var.env[0]
  }

  depends_on = [aws_s3_bucket_policy.s3bucket_policy_sonarqube]
}

#Target Group of SonarQube Application Loadbalancer
resource "aws_lb_target_group" "sonarqube_target_group" {
  name     = "SonarQube"          ###var.target_group_name
  port     = "9000"      ##### Don't use protocol when target type is lambda
  protocol = var.instance_protocol  ##### Don't use protocol when target type is lambda
  vpc_id   = aws_vpc.test_vpc.id
  target_type = var.target_type_alb
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  health_check {
    enabled = true ## Indicates whether health checks are enabled. Defaults to true.
    path = "/"   #var.healthcheck_path     ###"/index.html"
    port = "traffic-port"
    protocol = "HTTP"
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.timeout
    interval            = var.interval
  }
}

##SonarQube Application Loadbalancer listener for HTTP
resource "aws_lb_listener" "sonarqube_alb_listener_front_end_HTTP" {
  load_balancer_arn = aws_lb.sonarqube-application-loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = var.type[1]
    target_group_arn = aws_lb_target_group.sonarqube_target_group.arn
     redirect {    ### Redirect HTTP to HTTPS
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

##SonarQube Application Loadbalancer listener for HTTPS
resource "aws_lb_listener" "sonarqube_alb_listener_front_end_HTTPS" {
  load_balancer_arn = aws_lb.sonarqube-application-loadbalancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = var.type[0]
    target_group_arn = aws_lb_target_group.sonarqube_target_group.arn
  }
}

## EC2 Instance1 attachment to SonarQube Target Group
resource "aws_lb_target_group_attachment" "sonarqube_ec2_instance1_attachment_to_tg" {
  target_group_arn = aws_lb_target_group.sonarqube_target_group.arn
  target_id        = aws_instance.sonarqube.id               #var.ec2_instance_id[0]
  port             = "9000"                                  ###var.instance_port
}

## EC2 Instance2 attachment to Target Group
#resource "aws_lb_target_group_attachment" "ec2_instance2_attachment_to_tg" {
#  target_group_arn = aws_lb_target_group.target_group.arn
#  target_id        = var.ec2_instance_id[1]
#  port             = var.instance_port
#}

########################################################## Nexus Application LoadBalancer ################################################################

# Security Group for Nexus ALB
resource "aws_security_group" "nexus_alb" {
  name        = "Nexus-ALB"
  description = "Security Group for Nexus ALB"
  vpc_id      = aws_vpc.test_vpc.id           ###var.vpc_id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = var.cidr_blocks
    from_port  = 80
    to_port    = 80
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nexus-ALB-sg"
  }
}

#Nexus Application Loadbalancer
resource "aws_lb" "nexus-application-loadbalancer" {
  name               = "Nexus-ALB"      ### var.application_loadbalancer_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.nexus_alb.id]           ###var.security_groups
  subnets            = aws_subnet.public_subnet.*.id               ###var.subnets

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout = var.idle_timeout
  access_logs {
    bucket  = "s3bucketcapturealblogsonarqube"       ### var.access_log_bucket
    prefix  = var.prefix
    enabled = var.enabled
  }

  tags = {
    Environment = var.env[0]
  }

  depends_on = [aws_s3_bucket_policy.s3bucket_policy_sonarqube]
}

#Target Group of Nexus Application Loadbalancer
resource "aws_lb_target_group" "nexus_target_group" {
  name     = "Nexus"                  ###var.target_group_name
  port     = "8081"    ###var.instance_port      ##### Don't use protocol when target type is lambda
  protocol = var.instance_protocol  ##### Don't use protocol when target type is lambda
  vpc_id   = aws_vpc.test_vpc.id          ###var.vpc_id
  target_type = var.target_type_alb
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  health_check {
    enabled = true ## Indicates whether health checks are enabled. Defaults to true.
    path = var.healthcheck_path     ###"/index.html"
    port = "traffic-port"
    protocol = "HTTP"
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.timeout
    interval            = var.interval
  }
}

##Nexus Application Loadbalancer listener for HTTP
resource "aws_lb_listener" "nexus_alb_listener_front_end_HTTP" {
  load_balancer_arn = aws_lb.nexus-application-loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = var.type[1]
    target_group_arn = aws_lb_target_group.nexus_target_group.arn
     redirect {    ### Redirect HTTP to HTTPS
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

##Nexus Application Loadbalancer listener for HTTPS
resource "aws_lb_listener" "nexus_alb_listener_front_end_HTTPS" {
  load_balancer_arn = aws_lb.nexus-application-loadbalancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = var.type[0]
    target_group_arn = aws_lb_target_group.nexus_target_group.arn
  }
}

## EC2 Instance1 attachment to Nexus Target Group
resource "aws_lb_target_group_attachment" "nexus_ec2_instance1_attachment_to_tg" {
  target_group_arn = aws_lb_target_group.nexus_target_group.arn
  target_id        = aws_instance.nexus.id               #var.ec2_instance_id[0]
  port             = "8081"    ###var.instance_port
}

## EC2 Instance2 attachment to Target Group
#resource "aws_lb_target_group_attachment" "ec2_instance2_attachment_to_tg" {
#  target_group_arn = aws_lb_target_group.target_group.arn
#  target_id        = var.ec2_instance_id[1]
#  port             = var.instance_port
#}

########################################################## Grafana Application LoadBalancer ##############################################################

# Security Group for ALB
resource "aws_security_group" "grafana_alb" {
  name        = "Grafana-ALB"
  description = "Security Group for Grafana ALB"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = var.cidr_blocks
    from_port  = 80
    to_port    = 80
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Grafana-ALB-sg"
  }
}

#S3 Bucket to capture Grafana ALB access logs
resource "aws_s3_bucket" "s3_bucket_grafana" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = "s3bucketcapturealbloggrafana"         ###var.access_log_bucket_grafana

  force_destroy = true

  tags = {
    Environment = var.env[0]
  }
}

#S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "s3bucket_encryption_grafana" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_grafana[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

#Apply Bucket Policy to S3 Bucket
resource "aws_s3_bucket_policy" "s3bucket_policy_grafana" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_grafana[0].id
  policy = <<EOFD
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::033677994240:root"
          },
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::s3bucketcapturealbloggrafana/application_loadbalancer_log_folder/AWSLogs/${data.aws_caller_identity.G_Duty.account_id}/*"
        }
      ]
    } 
  EOFD

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.s3bucket_encryption_grafana]
}

#Application Loadbalancer
resource "aws_lb" "test-application-loadbalancer_grafana" {
  name               = "Grafana"         ###var.application_loadbalancer_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.grafana_alb.id]           ###var.security_groups
  subnets            = aws_subnet.public_subnet.*.id

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout = var.idle_timeout
  access_logs {
    bucket  = "s3bucketcapturealbloggrafana"         ###var.access_log_bucket_grafana
    prefix  = var.prefix
    enabled = var.enabled
  }

  tags = {
    Environment = var.env[0]
  }

  depends_on = [aws_s3_bucket_policy.s3bucket_policy_grafana]
}

#Target Group of Application Loadbalancer Grafana
resource "aws_lb_target_group" "target_group_grafana" {
  name     = "Grafana"          ###var.target_group_name
  port     = "3000"   ###var.instance_port      ##### Don't use protocol when target type is lambda
  protocol = var.instance_protocol  ##### Don't use protocol when target type is lambda
  vpc_id   = aws_vpc.test_vpc.id
  target_type = var.target_type_alb
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  health_check {
    enabled = true ## Indicates whether health checks are enabled. Defaults to true.
    path = "/"        ###var.healthcheck_path     ###"/index.html"
    port = "traffic-port"
    protocol = "HTTP"
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.timeout
    interval            = var.interval
  }
}

##Grafana Application Loadbalancer listener for HTTP
resource "aws_lb_listener" "alb_listener_front_end_HTTP_grafana" {
  load_balancer_arn = aws_lb.test-application-loadbalancer_grafana.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = var.type[1]
    target_group_arn = aws_lb_target_group.target_group_grafana.arn
     redirect {    ### Redirect HTTP to HTTPS
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

##Grafana Application Loadbalancer listener for HTTPS
resource "aws_lb_listener" "alb_listener_front_end_HTTPS_grafana" {
  load_balancer_arn = aws_lb.test-application-loadbalancer_grafana.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = var.type[0]
    target_group_arn = aws_lb_target_group.target_group_grafana.arn
  }
}

## EC2 Instance1 attachment to Grafana Target Group
resource "aws_lb_target_group_attachment" "ec2_instance1_attachment_to_tg_grafana" {
  target_group_arn = aws_lb_target_group.target_group_grafana.arn
  target_id        = aws_instance.grafana.id               #var.ec2_instance_id[0]
  port             = "3000"                                ###var.instance_port
}

## EC2 Instance2 attachment to Target Group
#resource "aws_lb_target_group_attachment" "ec2_instance2_attachment_to_tg" {
#  target_group_arn = aws_lb_target_group.target_group.arn
#  target_id        = var.ec2_instance_id[1]
#  port             = var.instance_port
#}

###################################################### Loki Application LoadBalancer #############################################################

# Security Group for Loki ALB
resource "aws_security_group" "loki_alb" {
  name        = "Loki-ALB"
  description = "Security Group for Loki ALB"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = var.cidr_blocks
    from_port  = 80
    to_port    = 80
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Loki-ALB-sg"
  }
}

#S3 Bucket to capture Loki ALB access logs
resource "aws_s3_bucket" "s3_bucket_loki" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = "s3bucketcapturealblogloki"        ###var.access_log_bucket_loki

  force_destroy = true

  tags = {
    Environment = var.env[0]
  }
}

#S3 Bucket Loki Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "s3bucket_encryption_loki" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_loki[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

#Apply Bucket Policy to Loki S3 Bucket
resource "aws_s3_bucket_policy" "s3bucket_policy_loki" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_loki[0].id
  policy = <<BUCKETPOLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
             "AWS": "arn:aws:iam::033677994240:root"
          },
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::s3bucketcapturealblogloki/application_loadbalancer_log_folder/AWSLogs/${data.aws_caller_identity.G_Duty.account_id}/*"
        }
      ]
    }
  BUCKETPOLICY

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.s3bucket_encryption_loki]
}

#Loki Application Loadbalancer
resource "aws_lb" "test-application-loadbalancer_loki" {
  name               = "Loki"
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.loki_alb.id]           ###var.security_groups
  subnets            = aws_subnet.public_subnet.*.id

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout = var.idle_timeout
  access_logs {
    bucket  = "s3bucketcapturealblogloki"     ###var.access_log_bucket_loki
    prefix  = var.prefix
    enabled = var.enabled
  }

  tags = {
    Environment = var.env[0]
  }

  depends_on = [aws_s3_bucket_policy.s3bucket_policy_loki]
}

#Target Group of Loki Application Loadbalancer
resource "aws_lb_target_group" "target_group_loki" {
  name     = "Loki"
  port     = "3100"    ###var.instance_port      ##### Don't use protocol when target type is lambda
  protocol = var.instance_protocol  ##### Don't use protocol when target type is lambda
  vpc_id   = aws_vpc.test_vpc.id
  target_type = var.target_type_alb
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  health_check {
    enabled = true ## Indicates whether health checks are enabled. Defaults to true.
    path = "/ready"    ###var.healthcheck_path     ###"/index.html"
    port = "traffic-port"
    protocol = "HTTP"
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.timeout
    interval            = var.interval
  }
}

##Application Loadbalancer listener for HTTP
resource "aws_lb_listener" "alb_listener_front_end_HTTP_loki" {
  load_balancer_arn = aws_lb.test-application-loadbalancer_loki.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = var.type[0]
    target_group_arn = aws_lb_target_group.target_group_loki.arn
  }
}

#  default_action {
#    type             = var.type[1]
#    target_group_arn = aws_lb_target_group.target_group_loki.arn
#     redirect {    ### Redirect HTTP to HTTPS
#      port        = "443"
#      protocol    = "HTTPS"
#      status_code = "HTTP_301"
#    }
#  }
#}

##Application Loadbalancer listener for HTTPS
resource "aws_lb_listener" "alb_listener_front_end_HTTPS_loki" {
  load_balancer_arn = aws_lb.test-application-loadbalancer_loki.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = var.type[0]
    target_group_arn = aws_lb_target_group.target_group_loki.arn
  }
}

## EC2 Instance1 attachment to Target Group
resource "aws_lb_target_group_attachment" "ec2_instance1_attachment_to_tg_loki" {
  target_group_arn = aws_lb_target_group.target_group_loki.arn
  target_id        = aws_instance.loki[0].id               #var.ec2_instance_id[0]
  port             = "3100"    ###var.instance_port
}

## EC2 Instance2 attachment to Target Group
resource "aws_lb_target_group_attachment" "ec2_instance2_attachment_to_tg_loki" {
  target_group_arn = aws_lb_target_group.target_group_loki.arn
  target_id        = aws_instance.loki[1].id               #var.ec2_instance_id[1]
  port             = "3100"    ###var.instance_port
}

## EC2 Instance3 attachment to Target Group
resource "aws_lb_target_group_attachment" "ec2_instance3_attachment_to_tg_loki" {
  target_group_arn = aws_lb_target_group.target_group_loki.arn
  target_id        = aws_instance.loki[2].id               #var.ec2_instance_id[2]
  port             = "3100"    ###var.instance_port
}
