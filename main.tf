# Define required providers.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.45.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region     = "eu-west-2"  # Specify your desired AWS region
  profile = "default"
}

# Create an ECR repository
resource "aws_ecr_repository" "app_ecr_repo" {
  name = "app-repo"

    tags = {
    name = "CreatedByTeam1"

    }
      lifecycle {
    create_before_destroy = true
  }
}


resource "aws_ecs_cluster" "my_cluster" {
  name = "app-cluster"
    lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket" "team_one_s3" {
  bucket = "test59y7h6zf"
 
  tags = {
    Name       = "Our_bucket"
  }
  
}




#Creating Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-first-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "app-first-task",
      "image": "${aws_ecr_repository.app_ecr_repo.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # use Fargate as the launch type
  network_mode             = "awsvpc"    # add the AWS VPN network mode as this is required for Fargate
  memory                   = 512         # Specify the memory the container requires
  cpu                      = 256         # Specify the CPU the container requires
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"

    lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"

    lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

    lifecycle {
    create_before_destroy = true
  }
}





#VPC
# Provide a reference to your default VPC
resource "aws_default_vpc" "default_vpc" {

    lifecycle {
    create_before_destroy = true
  }
}

# Provide references to your default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "eu-west-2a"

    lifecycle {
    create_before_destroy = true
  }
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "eu-west-2b"

    lifecycle {
    create_before_destroy = true
  }
}





#Creating Load Balancer
resource "aws_alb" "application_load_balancer" {
  name               = "load-balancer-dev" #load balancer name
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]

    lifecycle {
    create_before_destroy = true
  }
}





#Adding Security Group 
# Create a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

    lifecycle {
    create_before_destroy = true
  }
}





#Configure the load balancer with the VPC networking
resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" # default VPC

    lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" #  load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # target group
  }
    lifecycle {
    create_before_destroy = true
  }
}




#Create an ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "app-first-service" 
  cluster         = "${aws_ecs_cluster.my_cluster.id}"   # Reference the created Cluster
  task_definition = "${aws_ecs_task_definition.app_task.arn}" # Reference the task that the service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Set up the number of containers to 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Reference the target group
    container_name   = "app-first-task"
    container_port   = 5000 # Specify the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true     # Provide the containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Set up the security group
  }

      lifecycle {
    create_before_destroy = true
  }
   
  }



#Only allow the traffic from the created load balancer
resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
    lifecycle {
    create_before_destroy = true
  }
}




#Log the load balancer app URL
output "app_url" {
  value = aws_alb.application_load_balancer.dns_name
}

resource "aws_cloudwatch_metric_alarm" "group1-monitoring" {
  alarm_name                = "group1-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECR"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors ECR cpu utilization"
  insufficient_data_actions = []

    lifecycle {
    create_before_destroy = true
  }
}


resource "aws_cloudwatch_log_group" "log_group" {
  name              = var.log_group_name
  retention_in_days = var.retention_days

    lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "group1-log-stream"
  log_group_name = aws_cloudwatch_log_group.log_group.name

    lifecycle {
    create_before_destroy = true
  }
}