resource "aws_vpc" "test_vpc" {
  cidr_block       = "${var.vpc_cidr}"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vpc_name}-${var.env[0]}"                     ##"test-vpc"
    Environment = var.env[0]            ##"${terraform.workspace}"
  }
}

############################### Public Subnet ##########################################

resource "aws_subnet" "public_subnet" {
  count = "${length(data.aws_availability_zones.azs.names)}"
  vpc_id     = "${aws_vpc.test_vpc.id}"
  availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block = "${element(var.public_subnet_cidr,count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-${var.env[0]}-${count.index+1}"
    Environment = var.env[0]            ##"${terraform.workspace}"
  }
}

############################### Private Subnet #########################################

resource "aws_subnet" "private_subnet" {
  count = "${length(data.aws_availability_zones.azs.names)}"                  ##"${length(slice(data.aws_availability_zones.azs.names, 0, 2))}"
  vpc_id     = "${aws_vpc.test_vpc.id}"
  availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block = "${element(var.private_subnet_cidr,count.index)}"

  tags = {
    Name = "PrivateSubnet-${var.env[0]}-${count.index+1}"
    Environment = var.env[0]                ##"${terraform.workspace}"
  }
}

############################### Public Route Table ####################################

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.testIGW.id
  }

  tags = {
    Name = "public-route-table-${var.env[0]}"
    Environment = var.env[0]              ##"${terraform.workspace}"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  count = "${length(data.aws_availability_zones.azs.names)}"
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

############################### Private Route Table ###################################

resource "aws_default_route_table" "default_route_table" {
  default_route_table_id = aws_vpc.test_vpc.default_route_table_id

   tags = {
    Name = "default-route-table-${var.env[0]}"
    Environment = var.env[0]               ##"${terraform.workspace}"
  }

}

resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
}

  tags = {
    Name = "Private-route-table-1-${var.env[0]}"
   Environment = var.env[0]                  ##"${terraform.workspace}"
  }
}

resource "aws_route_table_association" "private_route_table_association_1" {
#  count = "${length(slice(data.aws_availability_zones.azs.names, 0, 2))}"           ##"${length(data.aws_availability_zones.azs.names)}"
  subnet_id      = aws_subnet.private_subnet[0].id                                   ##aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table_1.id
}

resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
}

  tags = {
    Name = "Private-route-table-2-${var.env[0]}"
    Environment = var.env[0]                  ##"${terraform.workspace}"
  }
}

resource "aws_route_table_association" "private_route_table_association_2" {
#  count = "${length(slice(data.aws_availability_zones.azs.names, 0, 2))}"        ## "${length(data.aws_availability_zones.azs.names)}"
  subnet_id      = aws_subnet.private_subnet[1].id                             ## aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table_2.id
}

resource "aws_route_table" "private_route_table_3" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
}

  tags = {
    Name = "Private-route-table-3-${var.env[0]}"
    Environment = var.env[0]                  ##"${terraform.workspace}"
  }
}

resource "aws_route_table_association" "private_route_table_association_3" {
#  count = "${length(data.aws_availability_zones.azs.names)}"       ##"${length(slice(data.aws_availability_zones.azs.names, 0, 2))}"
  subnet_id      = aws_subnet.private_subnet[2].id         ## aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table_3.id
}

############################################## NAT Gateway #######################################################

resource "aws_eip" "nat" {
  domain   = "vpc"
  # vpc      = true
}
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet[0].id
  depends_on    = [aws_internet_gateway.testIGW]

  tags = {
    Name = "${var.natgateway_name}-${var.env[0]}"            ##"NAT_Gateway"
    Environment = var.env[0]          ##"${terraform.workspace}"
  }
}

############################################# Internet Gateway ####################################################

resource "aws_internet_gateway" "testIGW" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "${var.igw_name}-${var.env[0]}"        #"test-IGW"
    Environment = var.env[0]               ##"${terraform.workspace}"
  }
}
 
############################################ Security Group to Allow All Traffic #############################

resource "aws_security_group" "all_traffic" {
 name        = "AllTraffic-Security-Group-${var.env[0]}"
 description = "Allow All Traffic"
 vpc_id      = aws_vpc.test_vpc.id

ingress {
   description = "Allow All Traffic"
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }

egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}
