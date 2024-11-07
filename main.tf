provider "aws" {
  region = "eu-north-1"  # Update to your desired region
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"  # Ensure using different AZs
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-north-1b"  # Ensure using different AZs
  map_public_ip_on_launch = true
}

# Create Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-north-1a"  # Ensure using different AZs
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-north-1b"  # Ensure using different AZs
}

# Create a Security Group for the RDS
resource "aws_security_group" "db_security_group" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a Secrets Manager Secret for DB Password
resource "aws_secretsmanager_secret" "db_password" {
  name = "mydatabase_password"
}

# Create a Secrets Manager Secret Version for DB Password
resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    password = "temporaryPassword123!"  # Update to your desired password
  })
}

# Create a DB Subnet Group for RDS
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

# Create an RDS DB Instance
resource "aws_db_instance" "postgres_instance" {
  allocated_storage      = 20
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.micro"  # Use t3.micro for compatibility
  db_name              = "mydatabase"    # Use db_name instead of name
  username             = "dbadmin"
  password             = jsondecode(aws_secretsmanager_secret_version.db_password_version.secret_string)["password"]
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
}

# Create ECS Cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

# Define IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

# Create Security Group for Fargate tasks
resource "aws_security_group" "fargate_security_group" {
  vpc_id = aws_vpc.my_vpc.id
}

# ECS Task Definition
resource "aws_ecs_task_definition" "task_definition" {
  family                   = "my-task-def"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # Task CPU
  memory                   = "512"  # Task memory

  container_definitions = jsonencode([{
    name      = "my-container"
    image     = "YOUR_ECR_REPOSITORY_URI"  # Update to your ECR repository URI
    essential = true

    environment = [
      {
        name  = "PG_HOST"
        value = aws_db_instance.postgres_instance.endpoint
      },
      {
        name  = "PG_USER"
        value = "dbadmin"
      },
      {
        name  = "PG_DB"
        value = "mydatabase"
      },
      {
        name  = "PG_PORT"
        value = "5432"
      },
      {
        name  = "PG_PASSWORD"
        value = jsondecode(aws_secretsmanager_secret_version.db_password_version.secret_string)["password"]
      }
    ]

    log_configuration = {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/MyAppLogs"
        "awslogs-region"       = "eu-north-1"  # Update to your region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# Output the RDS endpoint
output "rds_endpoint" {
  value = aws_db_instance.postgres_instance.endpoint
}
