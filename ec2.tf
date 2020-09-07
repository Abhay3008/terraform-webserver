provider "aws" {
  region = "ap-south-1"
  profile = "abhay"
  access_key = "**********"
  secret_key = "****************"
}
resource "aws_security_group" "My_VPC_Security_Group" {

  vpc_id       = "vpc-517e6139"
  name         = "My-VPC-Security-Group"
  description  = "My VPC Security Group"
  
  # allow ingress of port 22
  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]  
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  
  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
   Name = "My-VPC-Security-Group"
   Description = "My VPC Security Group"
}
}
resource "aws_instance" "web" {
depends_on = [
    aws_security_group.My_VPC_Security_Group,
  ]

  ami           = "ami-0b44050b2d893d5f7"
  instance_type = "t2.micro"
  key_name = "terraform_ec2_key"
  security_groups = [ "My-VPC-Security-Group" ]

connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("/tera/terraform_ec2_key")
    host     = aws_instance.web.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install apache2 php git -y",
      "sudo systemctl restart apache2",
    ]
  }
  tags = {
    Name = "os1"
  }
}

resource "aws_key_pair" "terraform_ec2_key" {
  key_name = "terraform_ec2_key"
  public_key = "${file("terraform_ec2_key.pub")}"
}

resource "aws_ebs_volume" "ebs" {
  availability_zone = aws_instance.web.availability_zone
  size = 1
  tags = {
    Name = "ebs1"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}



resource "null_resource" "nulllocal2"  {
        provisioner "local-exec" {
            command = "git clone https://github.com/Abhay3008/facebook-data.git"
        }
}

variable "mime_types" {
  default = {
    htm = "text/html"
    html = "text/html"
    css = "text/css"
    js = "application/javascript"
    map = "application/javascript"
    json = "application/json"
    png = "image/png"
  }
}

resource "aws_s3_bucket" "terra-bucket" {
 depends_on = [ null_resource.nulllocal2
]
bucket = "git-code-for-terra67"
  acl    = "public-read"
}
resource "aws_s3_bucket_object" "push_bucket" {
depends_on = [ aws_s3_bucket.terra-bucket
]
   for_each = fileset("/tera/facebook-data/data", "**/*.*")
   bucket = aws_s3_bucket.terra-bucket.bucket
   key = replace(each.value, "/tera/facebook-data/data", "")
   source = "/tera/facebook-data/data/${each.value}"
   acl = "public-read"
   etag = filemd5("/tera/facebook-data/data/${each.value}")
   content_type = lookup(var.mime_types, split(".", each.value)[1])
}

resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = "git-code-for-terra67.s3.amazonaws.com"
    origin_id   = aws_s3_bucket.terra-bucket.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.terra-bucket.id


    forwarded_values {
      query_string = false


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
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }


  tags = {
    Name        = "Terra-CF-Distribution"
    Environment = "Production"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  depends_on = [
    aws_s3_bucket.terra-bucket
  ]
}


resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("/tera/terraform_ec2_key")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Abhay3008/facebook-data.git /var/www/html/",
      "sudo bash -c 'echo export url=${aws_s3_bucket.terra-bucket.bucket_domain_name} >> /etc/apache2/envvars'"
    ]
  }
}
