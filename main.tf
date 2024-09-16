# Configure provider
provider "aws" {
  profile = "cliuser"
  region  = "eu-north-1"
}

#################################################################
# VPC for networking
resource "aws_vpc" "fargate_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Public subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.fargate_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.fargate_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
}

# Route table for public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.fargate_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fargate_igw.id
  }
}

# Associate the route table with public subnets
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Internet gateway for VPC
resource "aws_internet_gateway" "fargate_igw" {
  vpc_id = aws_vpc.fargate_vpc.id
}

# Security group for Fargate
resource "aws_security_group" "fargate_sg" {
  vpc_id = aws_vpc.fargate_vpc.id

  # You can remove the ingress rule for port 80 if not needed
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # This denies all inbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

#################################################################
# ECS cluster
resource "aws_ecs_cluster" "fargate_cluster" {
  name = "fargate-cluster-1"
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach required policies to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create a CloudWatch Log Group for ECS task logs
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/message-logger"
  retention_in_days = 7  # Specify the number of days to retain the logs
}

# ECR Repository for Docker Image
resource "aws_ecr_repository" "message_logger_repo" {
  name = "message-logger"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "fargate_task" {
  family                   = "message-logger"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = jsonencode([
    {
      name      = "message-logger-container",
      image     = aws_ecr_repository.message_logger_repo.repository_url,
      essential = true,
      # Add log configuration here
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name,
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

#################################################################
# EventBridge rule to trigger ECS task
resource "aws_cloudwatch_event_rule" "eventbridge_rule" {
  name        = "eventbridge-rule"
  description = "Rule to trigger ECS Fargate task"

  event_pattern = jsonencode({
    "source": ["custom.my-application"],  
    "detail-type": ["myDetailType"]
  })
}

/*# Target for EventBridge rule to trigger ECS task
resource "aws_cloudwatch_event_target" "ecs_target" {
  rule      = aws_cloudwatch_event_rule.eventbridge_rule.name
  arn       = aws_ecs_cluster.fargate_cluster.arn
  role_arn  = aws_iam_role.eventbridge_invoke_ecs_role.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.fargate_task.arn
    task_count          = 1
    launch_type         = "FARGATE"
    
    network_configuration {
      subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
      security_groups  = [aws_security_group.fargate_sg.id]
      assign_public_ip = true
    }
  }
}*/

# Target for EventBridge rule to trigger ECS task
resource "aws_cloudwatch_event_target" "ecs_target" {
  rule      = aws_cloudwatch_event_rule.eventbridge_rule.name
  arn       = aws_ecs_cluster.fargate_cluster.arn
  role_arn  = aws_iam_role.eventbridge_invoke_ecs_role.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.fargate_task.arn
    task_count          = 1
    launch_type         = "FARGATE"
    
    network_configuration {
      subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
      security_groups  = [aws_security_group.fargate_sg.id]
      assign_public_ip = true
    }
  }

  # Use input_transformer to pass only the "Detail" part of the event
  input_transformer {
    input_paths = {
      "detail" = "$.detail"  # Extract the "Detail" field of the event
    }
    input_template = "{\"detail\": <detail>}"  # Pass it as JSON to the task
  }
}

#################################################################
# IAM Role for EventBridge to invoke ECS
resource "aws_iam_role" "eventbridge_invoke_ecs_role" {
  name = "eventbridgeInvokeEcsRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy to allow EventBridge to invoke ECS tasks
resource "aws_iam_role_policy" "ecs_task_execution_from_eventbridge_policy" {
  role = aws_iam_role.eventbridge_invoke_ecs_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ecs:RunTask",
        Resource = aws_ecs_task_definition.fargate_task.arn
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = aws_iam_role.ecs_task_execution_role.arn
      }
    ]
  })
}