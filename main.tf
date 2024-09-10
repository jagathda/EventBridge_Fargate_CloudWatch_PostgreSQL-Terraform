#Configure provider
provider "aws" {
    region = "eu-north-1"
}

#VPC for networking
resource "aws_vpc" "fargate_vpc" {
  cidr_block = "10.0.0.0/16"
}

#Public networks
resource "aws_subnet" "public_subnet_1" {
  vpc_id = aws_vpc.fargate_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id = aws_vpc.fargate_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
}

resource "aws_internet_gateway" "fargate_igw" {
  vpc_id = aws_vpc.fargate_vpc.id
}

resource "aws_security_group" "fargate_sg" {
  vpc_id = aws_vpc.fargate_vpc.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

################################################3

#Create ECS cluster
resource "aws_ecs_cluster" "fargate_cluster" {
  name = "fargate-cluster"
}

#ECS task excution role
resource "aws_iam_role" "ecs_task_excution_role" {
  name = "ecs_task_excution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Effect = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com"},
        Action = "sts:AssumeRole"
    }]
  })
}