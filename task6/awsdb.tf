provider "aws" {
  region = "ap-south-1"
  profile = "nik"
}
resource "aws_db_instance" "default" {
  allocated_storage = 20
  engine            = "mysql"
  engine_version    = "5.7.30"
  instance_class    = "db.t2.micro"
  name     = "mydb"
  username = "mydb"
  password = "Your password"
  port     = "3306"
  publicly_accessible = true
  iam_database_authentication_enabled = true
  vpc_security_group_ids = ["sg-0ae001d1197310879"]
  tags = {
     Name = "mysql"
 }
}