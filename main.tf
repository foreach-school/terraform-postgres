provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "tf_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "tf_sg" {
  name        = "tf_sg"
  description = "Security group for database"

  vpc_id = aws_vpc.tf_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_db_subnet_group" "subnet_group" {
  name       = "subnet-group-terraform"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

variable "db_password" {
  description = "Password for the database"
}

variable "db_username" {
  description = "Username for the database"
}

resource "aws_db_instance" "postgres_rds" {
  identifier            = "dbinstance"
  allocated_storage     = 20
  storage_type          = "gp2"
  engine                = "postgres"
  engine_version        = "14.6"
  instance_class        = "db.t3.small"
  username              = var.db_username
  password              = var.db_password
  parameter_group_name  = "postgres-parameters" #aws_db_parameter_group.postgres_parameters.name

  vpc_security_group_ids = [aws_security_group.tf_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name

  multi_az = false

}

variable "environment" {
  description = "Environment (e.g., dev, staging, prod)"
}

resource "aws_s3_bucket" "cdn_bucket" {
  bucket = "cdn-bucket-${aws_caller_identity.current.account_id}-${var.environment}"
  acl    = "private"
}

resource "aws_cloudfront_distribution" "cdn_distribution" {
  origin {
    domain_name = aws_s3_bucket.cdn_bucket.bucket_regional_domain_name
    origin_id   = "S3Origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
