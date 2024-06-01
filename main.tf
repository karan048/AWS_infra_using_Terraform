resource "aws_vpc" "KaranVPC" {
  cidr_block = var.cidr
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.KaranVPC.id
  cidr_block              = var.subnet1Cidr
  availability_zone       = var.az
  map_public_ip_on_launch = true
  tags = {
    name = "public_Subnet"
  }

}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.KaranVPC.id
  cidr_block              = var.subnet2Cidr
  availability_zone       = var.az1
  map_public_ip_on_launch = true
  tags = {
    name = "private_Subnet"
  }
}

resource "aws_internet_gateway" "igateway" {
  vpc_id = aws_vpc.KaranVPC.id
  tags = {
    name = "internetG"
  }
}

# resource "aws_internet_gateway_attachment" "igwa" {

#     vpc_id = aws_vpc.KaranVPC.id
#     internet_gateway_id = aws_internet_gateway.igateway.id
#   }


resource "aws_route_table" "myRT" {
  vpc_id = aws_vpc.KaranVPC.id
  tags = {
    name = "my_custom_rt"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igateway.id
  }

}

resource "aws_route_table_association" "RTassociate1" {
  route_table_id = aws_route_table.myRT.id
  subnet_id      = aws_subnet.subnet1.id

}

resource "aws_route_table_association" "RTassociate2" {
  route_table_id = aws_route_table.myRT.id
  subnet_id      = aws_subnet.subnet2.id

}

resource "aws_security_group" "lbSG" {
  name   = "loadbalancerSG"
  vpc_id = aws_vpc.KaranVPC.id
  ingress {
    description = "HTTP "
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
    description = "ALL traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "lbSG"
  }
}



resource "aws_s3_bucket" "KaranS3Bucket" {
  bucket = "karansterraform1063536"
}

# resource "aws_s3_bucket_public_access_block" "KaranS3Bucket1" {
#   bucket = "aws_s3_bucket.KaranS3Bucket.id"

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_acl" "KaranS3Bucket2" {

#   bucket = aws_s3_bucket.KaranS3Bucket.id
#   acl    = "public-read"
# }

resource "aws_instance" "web" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = "t2.micro"
  key_name               = "Project2"
  vpc_security_group_ids = [aws_security_group.lbSG.id]
  subnet_id              = aws_subnet.subnet1.id
  user_data              = base64encode(file("userdata.sh"))
  availability_zone      = var.az
  tags = {
    Name = "WebServer1"
  }
}

resource "aws_instance" "DB" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = "t2.micro"
  key_name               = "Project2"
  vpc_security_group_ids = [aws_security_group.lbSG.id]
  subnet_id              = aws_subnet.subnet2.id
  user_data              = base64encode(file("userdata1.sh"))
  availability_zone      = var.az1
  tags = {
    Name = "WebServer2"
  }
}


resource "aws_alb" "myalb" {

  name               = "myALB"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.lbSG.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    name = "web"
  }
}

resource "aws_lb_target_group" "mylbtg" {
  name        = "myALBTG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.KaranVPC.id
  target_type = "instance"
  health_check {
    path = "/"
    port = "traffic-port"
  }

}

resource "aws_lb_target_group_attachment" "TGattach" {

  target_group_arn = aws_lb_target_group.mylbtg.arn
  target_id        = aws_instance.web.id
  port             = 80

}

resource "aws_lb_target_group_attachment" "TGattach1" {

  target_group_arn = aws_lb_target_group.mylbtg.arn
  target_id        = aws_instance.DB.id
  port             = 80

}

resource "aws_lb_listener" "ALBlistener" {
  load_balancer_arn = aws_alb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mylbtg.arn
    type             = "forward"
  }
}


output "load_balancer_ARN" {

  value = aws_alb.myalb.dns_name

}
