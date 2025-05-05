############################################################### Jenkins-Master #####################################################################
# Security Group for Jenkins-Master
resource "aws_security_group" "jenkins_master" {
  name        = "Jenkins-master"
  description = "Security Group for Jenkins Master ALB"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups  = [aws_security_group.jenkins_master_alb.id]
  }

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-master-sg"
  }
}

# Security Group for Jenkins Slave
resource "aws_security_group" "jenkins_slave" {
  name        = "Jenkins-slave"
  description = "Security Group for Jenkins Slave ALB"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-slave-sg"
  }
}

resource "aws_instance" "jenkins_master" {
  ami           = var.provide_ami
  instance_type = var.instance_type[2]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.jenkins_master.id]      ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_jenkins_master.sh")

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="${var.name}-Master"
    Environment = var.env[0]
  }
  
  depends_on = [aws_instance.loki]

}

resource "aws_eip" "eip_associate_master" {
  domain = "vpc"     ###vpc = true
}
resource "aws_eip_association" "eip_association_master" {  ### I will use this EC2 behind the ALB.
  instance_id   = aws_instance.jenkins_master.id
  allocation_id = aws_eip.eip_associate_master.id
}

resource "null_resource" "jenkins_master" {
  provisioner "remote-exec" {
    inline = [
         "sleep 120",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "echo '- job_name: Jenkins-Master' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  static_configs:' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  - targets:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      - localhost'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '    labels:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      job: JenkinsBuild-logs'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      __path__: /var/lib/jenkins/jobs/*/builds/*/log*'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  - targets:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      - localhost'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '    labels:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null", 
         "echo '      job: JenkinsHealthChecker-logs'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      __path__: /var/lib/jenkins/logs/*log'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null", 
         "echo '      stream: stdout'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",  
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = aws_eip.eip_associate_master.public_ip
    user = "ritesh"
    private_key = file("mykey.pem")
  }

  depends_on = [aws_instance.jenkins_master, aws_eip_association.eip_association_master]

}

############################################################# Jenkins-Slave ###########################################################################

resource "aws_instance" "jenkins_slave" {
  ami           = var.provide_ami
  instance_type = var.instance_type[2]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.jenkins_slave.id]  ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_jenkins_slave.sh")
  iam_instance_profile = "Administrator_Access"  # IAM Role to be attached to EC2

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="${var.name}-Slave"
    Environment = var.env[0]
  }
}
resource "aws_eip" "eip_associate_slave" {
  domain = "vpc"     ###vpc = true
}
resource "aws_eip_association" "eip_association_slave" {  ### I will use this EC2 behind the ALB.
  instance_id   = aws_instance.jenkins_slave.id
  allocation_id = aws_eip.eip_associate_slave.id
}

resource "null_resource" "jenkins_slave" {
  provisioner "remote-exec" {
    inline = [
         "sleep 120",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "echo '- job_name: Jenkins-Slave' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  static_configs:' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  - targets:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      - localhost'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '    labels:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      job: JenkinsSlave-logs'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      __path__: /var/log/messages'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      stream: stdout'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = aws_eip.eip_associate_slave.public_ip
    user = "ritesh"
    private_key = file("mykey.pem")
  }

  depends_on = [aws_instance.jenkins_slave, aws_eip_association.eip_association_slave]

}

########################################################## SonarQube Security Group #######################################################

# Security Group for SonarQube Server
resource "aws_security_group" "sonarqube" {
  name        = "SonarQube"
  description = "Security Group for SonarQube Server"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9000
    to_port          = 9000
    protocol         = "tcp"
    security_groups  = [aws_security_group.sonarqube_alb.id]
  }

  ingress {
    from_port        = 9000
    to_port          = 9000
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SonarQube-Server-sg"
  }
}

############################################################# SonarQube Server ###########################################################################

resource "aws_instance" "sonarqube" {
  ami           = var.provide_ami
  instance_type = var.instance_type[2]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.sonarqube.id]  ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_sonarqube.sh")

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="SonarQube"
    Environment = var.env[0]
  }

  depends_on = [aws_db_instance.dbinstance1]

}
resource "aws_eip" "eip_associate_sonarqube" {
  domain = "vpc"     ###vpc = true
}
resource "aws_eip_association" "eip_association_sonarqube" {  ### I will use this EC2 behind the ALB.
  instance_id   = aws_instance.sonarqube.id
  allocation_id = aws_eip.eip_associate_sonarqube.id
}

resource "null_resource" "sonarqube" {

  connection {
    type        = "ssh"
    user        = "ritesh"
    private_key = file("mykey.pem")
    host        = "${aws_eip.eip_associate_sonarqube.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 130",
      "sudo psql postgresql://postgres:Admin123@dbinstance-1.c2sgzmqemgvw.us-east-2.rds.amazonaws.com -f /opt/sonarqube.sql",      
      "sudo sed -i '/#sonar.jdbc.username=/s//sonar.jdbc.username=sonarqube/' /opt/sonarqube/conf/sonar.properties",
      "sudo sed -i '/#sonar.jdbc.password=/s//sonar.jdbc.password=Cloud#436/' /opt/sonarqube/conf/sonar.properties",
      "sudo sed -i 's%#sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube?currentSchema=my_schema%sonar.jdbc.url=jdbc:postgresql://${aws_db_instance.dbinstance1.endpoint}/sonarqubedb%g' /opt/sonarqube/conf/sonar.properties",
      "sudo systemctl restart sonarqube",
      "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
      "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
      "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
      "echo '- job_name: SonarQube' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "echo '  static_configs:' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "echo '  - targets:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "echo '      - localhost'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "echo '    labels:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "echo '      job: SonarQube-logs'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "echo '      __path__: /opt/sonarqube/logs/*log'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "echo '      stream: stdout'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
      "sudo systemctl restart promtail", 
    ]
  }

  depends_on = [aws_instance.sonarqube, aws_eip_association.eip_association_sonarqube]

}

################################################# Nexus-Server Security Group #########################################################

# Security Group for Nexus-Server
resource "aws_security_group" "nexus" {
  name        = "Nexus"
  description = "Security Group for Nexus Server"
  vpc_id      = aws_vpc.test_vpc.id           ###var.vpc_id

  ingress {
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    security_groups  = [aws_security_group.nexus_alb.id]
  }

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nexus-server-sg"
  }
}

########################################################## Nexus Server ##################################################################

resource "aws_instance" "nexus" {
  ami           = var.provide_ami
  instance_type = var.instance_type[2]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.nexus.id]      ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id      ###var.subnet_id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_nexus.sh")

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="Nexus-Server"
    Environment = var.env[0]
  }
}

#resource "aws_eip" "eip_associate_nexus" {
#  domain = "vpc"     ###vpc = true
#}
#resource "aws_eip_association" "eip_association_nexus" {  ### I will use this EC2 behind the ALB.
#  instance_id   = aws_instance.nexus.id
#  allocation_id = aws_eip.eip_associate_nexus.id
#}

resource "null_resource" "nexus" {
  provisioner "remote-exec" {
    inline = [
         "sleep 90",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "echo '- job_name: Nexus-Server-log' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  static_configs:' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  - targets:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      - localhost'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '    labels:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      job: NexusServer-logs'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      __path__: /opt/sonatype-work/nexus3/log/*log'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      stream: stdout'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = aws_instance.nexus.public_ip
    user = "ritesh"
    private_key = file("mykey.pem")
  }

  depends_on = [aws_instance.nexus]

}

##################################################### Loki and Grafana Security Group ##########################################################

# Security Group for Loki
resource "aws_security_group" "loki" {
  name        = "Loki-SecurityGroup"
  description = "Security Group for Loki Server"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 3100
    to_port          = 3100
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    from_port        = 9096
    to_port          = 9096
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }
  
  ingress {
    from_port        = 9093
    to_port          = 9093
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }
  
  ingress {
    from_port        = 7946
    to_port          = 7946
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "loki-server-sg"
  }
}

# Security Group for Grafana Server
resource "aws_security_group" "grafana" {
  name        = "Grafana-SecurityGroup"
  description = "Security Group for Grafana Server"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    security_groups  = [aws_security_group.grafana_alb.id]
  } 

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "grafana-server-sg"
  }
}

########################################################## Loki #################################################################

resource "aws_instance" "loki" {
  count         = 3
  ami           = var.provide_ami
  instance_type = var.instance_type[2]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.loki.id]      ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_loki.sh")
  iam_instance_profile = "AmazonS3FullAccess"     ### Provide RBAC Access to EC2 Instances to send Loki logs to S3 Bucket

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="Loki-Server-${count.index + 1}"
    Environment = var.env[0]
  }
}

#resource "aws_eip" "eip_associate_loki" {
#  count  = 3
#  domain = "vpc"     ###vpc = true
#}
#resource "aws_eip_association" "eip_association_loki" {  ### I will use this EC2 behind the ALB.
#  count         = 3
#  instance_id   = aws_instance.loki[count.index].id
#  allocation_id = aws_eip.eip_associate_loki[count.index].id
#}

resource "null_resource" "awsec2_loki" {
  count = 3
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "echo 'memberlist:' | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "echo -e '  join_members:' | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "echo -e \"  - http://${aws_instance.loki[0].private_ip}:7946\" | sudo tee -a /opt/loki-local-config.yaml > /dev/null",                                                                                                                                                   
         "echo -e \"  - http://${aws_instance.loki[1].private_ip}:7946\" | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "echo -e \"  - http://${aws_instance.loki[2].private_ip}:7946\" | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "sudo sed -i 's%chunks_directory: /tmp/loki/chunks%bucketnames: ${aws_s3_bucket.s3_bucket[0].id}%' /opt/loki-local-config.yaml",
         "sudo sed -i 's%rules_directory: /tmp/loki/rules%region: ${data.aws_region.reg.name}%' /opt/loki-local-config.yaml",
         "sudo systemctl restart loki",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = aws_instance.loki[count.index].public_ip
    user = "ritesh"
    private_key = file("mykey.pem")
  }

  depends_on = [aws_instance.loki[0], aws_instance.loki[1], aws_instance.loki[2], aws_s3_bucket.s3_bucket]

}

############################################################# Grafana ###########################################################################

resource "aws_instance" "grafana" {
  ami           = var.provide_ami
  instance_type = var.instance_type[2]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.grafana.id]  ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_grafana.sh")
  iam_instance_profile = "Administrator_Access"  # IAM Role to be attached to EC2

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="Grafana-Server"
    Environment = var.env[0]
  }
}
#resource "aws_eip" "eip_associate_grafana" {
#  domain = "vpc"     ###vpc = true
#}
#resource "aws_eip_association" "eip_association_grafana" {  ### I will use this EC2 behind the ALB.
#  instance_id   = aws_instance.grafana.id
#  allocation_id = aws_eip.eip_associate_grafana.id
#}

resource "null_resource" "grafana" {
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "echo '- job_name: Grafana' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  static_configs:' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '  - targets:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      - localhost'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '    labels:'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      job: Grafana-logs' | sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      __path__: /var/log/grafana/grafana.log'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "echo '      stream: stdout'|sudo tee -a /opt/promtail-local-config.yaml > /dev/null",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = aws_instance.grafana.public_ip
    user = "ritesh"
    private_key = file("mykey.pem")
  }

  depends_on = [aws_instance.grafana]

}

#S3 Bucket to capture Logs from Loki
resource "aws_s3_bucket" "s3_bucket" {
  count = var.s3_bucket_exists == false ? 1 : 0        ### create only one bucket 
  bucket = "s3bucketforlokilogs-${var.env[0]}"

  force_destroy = true

  tags = {
    Environment = var.env[0]
  }
}

#S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "s3bucket_encryption" {
  count = var.s3_bucket_exists == false ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

############################################################# Prometheus Server #############################################################

# Security Group for Prometheus Server
resource "aws_security_group" "prometheus" {
  name        = "Prometeheus-SecurityGroup"
  description = "Security Group for Prometheus Server"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 9090
    to_port          = 9090
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prometheus-server-sg"
  }
}

# Security Group for Blackbox Exporter Server
resource "aws_security_group" "blackbox_exporter" {
  name        = "BlackboxExporter-SecurityGroup"
  description = "Security Group for Blackbox Exporter Server"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port        = 9115
    to_port          = 9115
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 9080
    to_port          = 9080
    protocol         = "tcp"
    cidr_blocks      = ["10.10.0.0/16"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BlackboxExporter-server-sg"
  }
}

resource "aws_instance" "prometheus" {
  ami           = var.provide_ami
  instance_type = var.instance_type[2]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.prometheus.id]      ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_prometheus.sh")

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="Prometheus-Server"
    Environment = var.env[0]
  }
}

#resource "aws_eip" "eip_associate_prometheus" {
#  domain = "vpc"     ###vpc = true
#}
#resource "aws_eip_association" "eip_association_prometheus" {  ### I will use this EC2 behind the ALB.
#  instance_id   = aws_instance.prometheus.id
#  allocation_id = aws_eip.eip_associate_prometheus.id
#}

resource "null_resource" "prometheus" {
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
         "echo '  - job_name: \"Prometheus-Server\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"localhost:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '  - job_name: \"sonarqube\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    metrics_path: '/api/prometheus/metrics'' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.sonarqube.private_ip}:9000\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    basic_auth:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      username: 'admin'' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      password: 'Admin123'' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '  - job_name: \"Jenkins-Master\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.jenkins_master.private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '  - job_name: \"Jenkins-Slave\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.jenkins_slave.private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '  - job_name: \"SonarQube-Server\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.sonarqube.private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null", 
         "echo '  - job_name: \"Nexus-Server\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.nexus.private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null", 
         "echo '  - job_name: \"BlacboxExporter-Server\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.blackbox_exporter.private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null", 
         "echo '  - job_name: \"Grafana-Server\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.grafana.private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null", 
         "echo '  - job_name: \"Loki-Server-1\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.loki[0].private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null", 
         "echo '  - job_name: \"Loki-Server-2\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.loki[1].private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '  - job_name: \"Loki-Server-3\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.loki[2].private_ip}:9100\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '  - job_name: \"blackbox\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    metrics_path: /probe' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    params:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      module: [http_2xx_example]  # Look for a HTTP 200 response.' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '        - https://bankapp-dev.singhritesh85.com' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '        - https://bankapp-stage.singhritesh85.com' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    relabel_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - source_labels: [__address__]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '        target_label: __param_target' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - source_labels: [__param_target]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '        target_label: instance' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - target_label: __address__' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '        replacement: ${aws_instance.blackbox_exporter.private_ip}:9115' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '  - job_name: \"Jenkins-Job\"' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    metrics_path: '/prometheus'' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '    static_configs:' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null",
         "echo '      - targets: [\"${aws_instance.jenkins_master.private_ip}:8080\"]' | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null", 
         "sudo systemctl restart prometheus",
    ]
  }
  connection {
    type = "ssh"
    host = aws_instance.prometheus.public_ip
    user = "ritesh"
    private_key = file("mykey.pem")
  }

  depends_on = [aws_instance.prometheus]

}

############################################################# Blackbox Exporter #################################################################

resource "aws_instance" "blackbox_exporter" {
  ami           = var.provide_ami
  instance_type = var.instance_type[0]
  monitoring = true
  vpc_security_group_ids = [aws_security_group.blackbox_exporter.id]      ### var.vpc_security_group_ids       ###[aws_security_group.all_traffic.id]
  subnet_id = aws_subnet.public_subnet[0].id                                 ###aws_subnet.public_subnet[0].id
  root_block_device{
    volume_type="gp2"
    volume_size="20"
    encrypted=true
    kms_key_id = var.kms_key_id
    delete_on_termination=true
  }
  user_data = file("user_data_blackbox_exporter.sh")

  lifecycle{
    prevent_destroy=false
    ignore_changes=[ ami ]
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }

  metadata_options { #Enabling IMDSv2
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  tags={
    Name="BlackBoxExporter-Server"
    Environment = var.env[0]
  }
}

#resource "aws_eip" "eip_associate_blackbox_exporter" {
#  domain = "vpc"     ###vpc = true
#}
#resource "aws_eip_association" "eip_association_blackbox_exporter" {  ### I will use this EC2 behind the ALB.
#  instance_id   = aws_instance.blackbox_exporter.id
#  allocation_id = aws_eip.eip_associate_blackbox_exporter.id
#}

resource "null_resource" "blackbox_exporter" {
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${aws_instance.loki[0].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[1].private_ip}:3100/loki/api/v1/push\" \\n\"- url: http://${aws_instance.loki[2].private_ip}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = aws_instance.blackbox_exporter.public_ip
    user = "ritesh"
    private_key = file("mykey.pem")
  }
  depends_on = [aws_instance.blackbox_exporter]
}
