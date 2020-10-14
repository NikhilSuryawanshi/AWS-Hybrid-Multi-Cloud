provider "aws" {
  profile = "yash"
  region = "ap-south-1"
}

#create key
resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCml88NDD4RiOOs4YBQ9grzvYG/eZB55IapQuIkYJkAGbGoQ7m3sPGl+KKFVnOIciJkyeAJ/YaUoF7bljadWFTWYtc5fG4fVNScmzCoCfntQGijX3PO227zc5t1cXkTeyCIu+/66jD1GSoTxr58IHFv6iZ5JCpvzozonjowS6HWjkpNpP1A+ziXk/XF8hHkdEd57S8kE/NNPF/0kwTJJ6lEvo0LQuop44yIRyYEQPnvEpk6zPL76BQSrP8LnCjYTxuF3PJxyS2QPcxpakkFe5fF8sm3JDR0Dqi4PaMXvd07JRfB5oiEni4dLPIqjLEeaZbNjEf+NZ1ipRnFtReK1tLr nikhilsurya29@gmail.com"
}






resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames=true
  enable_dns_support =true
 tags = {
    Name = "my-vpc"
  }
}


## Create two subnets ##

## 1-Public Subnet ##

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public-subnet-1a"
  }
}

## 2-private subnet ##

resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = false
  availability_zone ="ap-south-1b"
  tags = {
    Name = "private-subnet-1b"
  }
}

## Create Internet Gateway ##

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id


  tags = {
    Name = "My-internet-gateway"
  }
}

## Create route table ##

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "my-routing-table"
  }
}

## route table connect to public subnet ##

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.r.id
}

## Launch mysql instance ##

## First create wordpress security group ##

resource "aws_security_group" "web" {
  name        = "wordpress-SG"
  description = "Allow HTTP and SSH inbound traffic"
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
    Name = "wordpress-SG"
  }
}

## Second create mysql security group ##

resource "aws_security_group" "db" {
  name        = "mysql-SG"
  description = "Allow webserver-SG inbound traffic"
  vpc_id      = aws_vpc.main.id


  ingress {
    description = "MYSQL"
    security_groups = [aws_security_group.web.id]
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "mysql-SG"
  }
}

## Launch mysql instance in private subnet ##

resource "aws_instance" "mysql" {
 ami = "ami-08706cb5f68222d09"
 instance_type = "t2.micro"
 associate_public_ip_address = false
 subnet_id = aws_subnet.private-subnet.id
 vpc_security_group_ids = [aws_security_group.db.id]


 tags ={
   Name = "mysql"
 }
}

## Launch wordpress instance ##

resource "aws_instance" "wordpress" {
 ami = "ami-000cbce3e1b899ebd"
 instance_type = "t2.micro"
 associate_public_ip_address = true
 subnet_id = aws_subnet.public-subnet.id
 vpc_security_group_ids = [aws_security_group.web.id]
 key_name = "mykey"


 tags ={
   Name = "wordpress"
  }

 }
