terraform {

  backend "s3" {
    bucket = "card-projecttt"
    key    = "path/terraform.tfstate"
    region = "ca-central-1"

  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "central_vpc" {
  cidr_block = "10.10.0.0/16"
 
 tags = {
    Name = "Central_vpc"
  }
}  

#subnet

resource "aws_subnet" "central_subnet_1a_public" {
  vpc_id     = aws_vpc.central_vpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "ca-central-1a"
  map_public_ip_on_launch = "true"
  
  tags = {
    Name = "cental_subnet_1a_public"
  }
} 

resource "aws_subnet" "central_subnet_1a_private" {
  vpc_id     = aws_vpc.central_vpc.id  
  cidr_block = "10.10.2.0/24"
  availability_zone = "ca-central-1a"


  tags = {
    Name = "cental_subnet_1a_private"
  }
} 

resource "aws_subnet" "central_subnet_1b_public" {
  vpc_id     = aws_vpc.central_vpc.id  
  cidr_block = "10.10.3.0/24"
  availability_zone = "ca-central-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "cental_subnet_1b_public"
  }
} 

resource "aws_subnet" "central_subnet_1b_private" {
  vpc_id     = aws_vpc.central_vpc.id  
  cidr_block = "10.10.4.0/24"
  availability_zone = "ca-central-1b"

  tags = {
    Name = "cental_subnet_1b_private"
  }
} 

#Creating EC2 in subnets

resource "aws_instance" "web-1" {
  ami           = "ami-0ea18256de20ecdfc"
  instance_type = "t2.micro"
  key_name = "key-pair"
  subnet_id     = aws_subnet.central_subnet_1a_public.id
  vpc_security_group_ids = [aws_security_group.ssh_http.id]
  
  tags = {
    Name = "Helloworld-1"
  }
}

resource "aws_instance" "web-2" {
  ami           = "ami-0ea18256de20ecdfc"
  instance_type = "t2.micro"
  key_name = "key-pair"
  subnet_id     = aws_subnet.central_subnet_1b_public.id
  vpc_security_group_ids = [ aws_security_group.ssh_http.id ]
  
  tags = {
    Name = "Helloworld-2"
  }
}

#security group

resource "aws_security_group" "ssh_http" {
  name        = "ssh_http"
  description = "Allow ssh and http inbound traffic"
  vpc_id      = aws_vpc.central_vpc.id

  ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"] 
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ssh_http"
  }
} 

#Internet Gateway

resource "aws_internet_gateway" "central-IG" {
  vpc_id = aws_vpc.central_vpc.id

  tags = {
    Name = "central-IG"
  }
}

#RT

resource "aws_route_table" "central_RT_Public" {
  vpc_id = aws_vpc.central_vpc.id 

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.central-IG.id
  }

  tags = {
    Name = "central-RT-Public"
  }
}

resource "aws_route_table" "central_RT_Private" {
  vpc_id = aws_vpc.central_vpc.id 

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.central-IG.id
  }

  tags = {
    Name = "central-RT-Private"
  }
}

#Attaching RT with subnets 

resource "aws_route_table_association" "RT-asso-1a-pub" {
  subnet_id      = aws_subnet.central_subnet_1a_public.id
  route_table_id = aws_route_table.central_RT_Public.id 
}

resource "aws_route_table_association" "RT-asso-1a-pvt" {
  subnet_id      = aws_subnet.central_subnet_1a_private.id
  route_table_id = aws_route_table.central_RT_Private.id 
}

resource "aws_route_table_association" "RT-asso-1b-pub" {
  subnet_id      = aws_subnet.central_subnet_1b_public.id
  route_table_id = aws_route_table.central_RT_Public.id  
}

resource "aws_route_table_association" "RT-asso-1b-pvt" {
  subnet_id      = aws_subnet.central_subnet_1b_private.id
  route_table_id = aws_route_table.central_RT_Private.id 
} 


#creating the instances via ASG and we will attach the LB to it  

resource "aws_launch_template" "LT-card-terraform" {
  name = "LT-card-terraform"
  image_id = "ami-0ea18256de20ecdfc"
  instance_type = "t2.micro"
  key_name = "key-pair"
  vpc_security_group_ids = [aws_security_group.ssh_http.id]
  user_data = filebase64("example.sh")

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "card-instance by terra"
    } 
  }
}
  
# asg 

resource "aws_autoscaling_group" "card-asg" {
  name = "card-asg-terraform"
  vpc_zone_identifier = [aws_subnet.central_subnet_1a_public.id, aws_subnet.central_subnet_1b_public.id]
  desired_capacity   = 2
  max_size           = 5
  min_size           = 2
  health_check_grace_period = 30
  target_group_arns = [aws_lb_target_group.card-web-TG-TF.arn]

  launch_template {
    id      = aws_launch_template.LT-card-terraform.id
    version = "$Latest"
  }
}

#LB with ASG

resource "aws_lb_target_group" "card-web-TG-TF" {
  name     = "card-web-TG-TF"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.central_vpc.id
}

resource "aws_lb_listener" "card-web-listener" {
  load_balancer_arn = aws_lb.card-web-LB-terraform.arn 
  port              = "80"
  protocol          = "HTTP"

default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.card-web-TG-TF.arn
  }
}

resource "aws_lb" "card-web-LB-terraform" {
  name               = "card-web-LB-terraform"
  internal           = false 
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ssh_http.id]
  subnets            = [aws_subnet.central_subnet_1a_public.id, aws_subnet.central_subnet_1b_public.id]

  tags = {
    Environment = "production"
  }
}
