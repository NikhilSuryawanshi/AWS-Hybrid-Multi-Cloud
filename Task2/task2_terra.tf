#aws profile

provider "aws" {
  profile = "yash"
  region = "ap-south-1"
}

# creating instance

resource "aws_instance" "task2os" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name = "oskey"
  security_groups = ["${aws_security_group.os_sg_port.name}"]
 
connection {
    type     = "ssh"
    user     = "ec2-user"
   private_key = file("C:/Users/Nihal/Downloads/oskey.pem")
    host     = aws_instance.task2os.public_ip
  }

   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "webos"
  }
}

# Bucket creation
resource "aws_s3_bucket" "task2osbucket" {
  bucket = "task2osbucket"
  acl    = "private"
  region = "ap-south-1"

  tags = {
    Name   = "task2osbucket"
    
  }
}

locals {
  s3_origin_id = "myS3_bucket_Origin"

}

# change permission

resource "aws_s3_bucket_public_access_block" "s3permission" {
  bucket = "task2osbucket"

  block_public_acls   = false
  block_public_policy = false
}



# EFS Network File system creation

resource "aws_efs_file_system" "osefs" {
  creation_token = "osefs"           

  tags = {
    Name = "efs_storage"
  }
}


# Creating Security Group for EFS server
resource "aws_security_group" "efs_sg" {
  name        = "efs_sg"
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# mount target for EFS

resource "aws_efs_mount_target" "efs_storage" {
depends_on = [
    aws_efs_file_system.osefs,
    aws_security_group.efs_sg,
    aws_instance.task2os,
  ]
  file_system_id  = aws_efs_file_system.osefs.id
  subnet_id       = aws_instance.task2os.subnet_id
  security_groups = [aws_security_group.efs_sg.id]
}







#creating  security group for instance

resource "aws_security_group" "os_sg_port" {
  name        = "os_sg_port"
  description = "Allow  inbound traffic"
 
 # Here we are Creating Security Group for WEB server
 
  ingress {
    description = "tcp from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Here we are Creating Security Group for SSH server
  
ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Here we are Creating Security Group for NFS server

  ingress {
    from_port   = 2049
    to_port     = 2049
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
    Name = "os_sg_port"
  }
}

#creating cloud fornt

resource "aws_cloudfront_distribution" "cloud_front_os" {
  origin {
    domain_name = aws_s3_bucket.task2osbucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
  origin_access_identity ="${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
  }

  }

  enabled             = true
  default_root_object = "index.html"


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
     
    }
  }
 depends_on = [ aws_s3_bucket_policy.bucket_policy ]
 
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


output "cloudfront_domain_name" {
       value = aws_cloudfront_distribution.cloud_front_os.domain_name
}

# CloudFront Origin access Identity

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
  depends_on = [ aws_s3_bucket.task2osbucket ]
}


#Updating IAM policies in bucket

data "aws_iam_policy_document" "iam_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.task2osbucket.arn}/*"]


    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }


  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.task2osbucket.arn}"]


    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
  depends_on = [ aws_cloudfront_origin_access_identity.origin_access_identity ]
}


#Updating Bucket Policies

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = "${aws_s3_bucket.task2osbucket.id}"
  policy = "${data.aws_iam_policy_document.iam_policy.json}"
  depends_on = [ aws_cloudfront_origin_access_identity.origin_access_identity ]

}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_efs_mount_target.efs_storage,aws_cloudfront_distribution.cloud_front_os,
  ]


 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Nihal/Downloads/oskey.pem")
    host     = aws_instance.task2os.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install amazon-efs-utils nfs-utils -y",
      "sudo chmod -R ugo+rw /etc/fstab",
      "sudo echo '${aws_efs_file_system.osefs.id}:/ /var/www/html efs tls,_netdev 0 0' >> /etc/fstab",
      "sudo mount -a -t efs,nfs4 defaults",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/yash147/task2_terraform.git /var/www/html/",
      "sudo su << EOF",
      "echo 'http://${aws_cloudfront_distribution.cloud_front_os.domain_name}/${aws_s3_bucket_object.task2osbucket.key}' > /var/www/html/url.txt",
      "EOF",
      
    ]
  }
}



# upload image

resource "aws_s3_bucket_object" "task2osbucket" {
depends_on = [
    aws_s3_bucket.task2osbucket,
  ]
  bucket = "task2osbucket"
  key    = "image.jpg"
  source = "C:/Users/Nihal/Downloads/cloudimage.jpg"
  etag = filemd5("C:/Users/Nihal/Downloads/cloudimage.jpg")
  acl = "public-read"
  content_type = "image/jpg"

}

resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
  ]


provisioner "local-exec" {
        command = "firefox  ${aws_instance.task2os.public_ip}"
      }
}





