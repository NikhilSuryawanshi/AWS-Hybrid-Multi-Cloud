provider "aws" {
  region = "ap-south-1"
   profile	= "nik"
}

resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "My-VPC"
  }
}
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "publicsubnet"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "privatesubnet"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "VPC_ig"
  }
}

resource "aws_route_table" "igroute" {
  vpc_id = aws_vpc.main.id

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
   tags = {
    Name = "routetableforig"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.igroute.id
}
resource "aws_eip" "elasticip" {
  vpc      = true
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.elasticip.id
  subnet_id     = aws_subnet.subnet1.id
  tags = {
    Name = "mynatgateway"
  }
}
resource "aws_route_table" "ngroute" {
  vpc_id = aws_vpc.main.id

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }
   tags = {
    Name = "routetableforng"
  }
}
resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.ngroute.id
}
resource "aws_security_group" "bastion" {
  name        = "Bastionsg"
  description = "bastion host do ssh in mysql"
  vpc_id      = aws_vpc.main.id
 ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastionsg"
  }
}

resource "aws_security_group" "mysql" {
  name        = "mysqlsg"
  description = "private subnet instance Mysql"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "SQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups  = [aws_security_group.wordpress.id]
  }
 ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MYSQL"
  }
}
resource "aws_security_group" "wordpress" {
  name        = "wp"
  description = "Public subnet instance wordpress"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WORDPRESS"
  }
}
resource "aws_instance" "wp" {
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  key_name = "myoskey"
  associate_public_ip_address = true
  subnet_id = aws_subnet.subnet1.id
  availability_zone = "ap-south-1a"
  vpc_security_group_ids = [aws_security_group.wordpress.id]
 
  tags = {
    Name = "wordpress"
  }
}


resource "aws_instance" "Mysql" {
  ami           = "ami-0b5bff6d9495eff69"
  instance_type = "t2.micro"
  key_name = "myoskey"
  associate_public_ip_address = false
  subnet_id = aws_subnet.subnet2.id
  availability_zone = "ap-south-1b"
  vpc_security_group_ids = [aws_security_group.mysql.id]
  tags = {
    Name = "mysql"
  }
}

resource "aws_instance" "Bastion" {
  ami = "ami-0ebc1ac48dfd14136"
  instance_type = "t2.micro"
  key_name = "myoskey"
  associate_public_ip_address = true
  subnet_id = aws_subnet.subnet1.id
  availability_zone = "ap-south-1a"
  vpc_security_group_ids = [aws_security_group.bastion.id]
 
  tags = {
    Name = "bastion"
  }
}
