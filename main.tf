#Task

#Built a Docker container (Covered by Liam).
#Deployed to AWS using IAC. Line 49
#Monitoring (line 315), logging (line 338)
#zero downtime updates
#version controlled. git, github, gitignore file

#Stretch goals
#Add TLS using ACM and HTTPS on the ALB (line 221)
#Add a health check endpoint and configure ALB to use it (line 200)
#Introduce auto-scaling on CPU usage (line 274)

#Stretch, STRETCH goal
#S3 bucket

#Other things
#tags


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.45.0"
    }
    
  }
  backend "s3" {
    bucket         = "gus-is-the-best"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
  }
 
}

provider "aws" {
  region     = "eu-west-2" 
  profile = "default"
  
}

resource "aws_ecr_repository" "app_ecr_repo" {
  name = "app-repo"

    tags = {
    name = "ECR_CreatedBy_Team1"
    environment = "Gurmel_bellydancing_in_duty-free"
    }
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "app-cluster"
  
    tags = {
    name = "ECS_CreatedBy_Team1"
    }

}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-first-task"

  container_definitions = <<DEFINITION
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
      "cpu": 256,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/app-first-task",
          "awslogs-region": "eu-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn

  tags = {
    name = "ECS_TaskDefinition_CreatedBy_Team1"
  }
}
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"

     tags = {
    name = "IAM_Role_CreatedBy_Team1"

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
}


resource "aws_default_vpc" "default_vpc" {

    lifecycle {
    create_before_destroy = true
  }
  tags = {
    name = "VPC_CreatedBy_Team1"
    environment = "gurmel_moonlighting_as_hungarian_translator"

    }
  
}

# Provide references to your default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "eu-west-2a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "eu-west-2b"
}


resource "aws_alb" "application_load_balancer" {
  name               = "load-balancer-dev"
  load_balancer_type = "application"
  subnets = [ 
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}


resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_lb_target_group" "target_group" {
name = "target-group"
port = 5000
protocol = "HTTP"
target_type = "ip"
vpc_id = "${aws_default_vpc.default_vpc.id}"

lifecycle {
create_before_destroy = true
}

health_check {
path="/health"
port = 5000
healthy_threshold = 6
unhealthy_threshold = 2
timeout = 2
interval = 5
matcher = "200"
}
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }

}

resource "aws_lb_listener" "https" {
load_balancer_arn = "${aws_alb.application_load_balancer.arn}"
port = 443
protocol = "HTTPS"
certificate_arn = aws_acm_certificate.my-certificate.arn

default_action {
type = "forward"
target_group_arn = aws_lb_target_group.target_group.arn
}
}

#openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
#-subj "/CN=local.example.com"

resource "aws_acm_certificate" "my-certificate" { 
private_key = file("key.pem")
certificate_body = file("cert.pem")
tags = {
Name = "group-1 TLS certificate"

}

lifecycle {
    create_before_destroy = true
  }
  
}

resource "aws_ecs_service" "app_service" {
  name            = "app-first-service" 
  cluster         = "${aws_ecs_cluster.my_cluster.id}" 
  task_definition = "${aws_ecs_task_definition.app_task.arn}" # Reference the task that the service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # At least 3 instances always running

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
    container_name   = "app-first-task"
    container_port   = 5000
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true    
    security_groups  = ["${aws_security_group.ecs_service_security_group.id}"]
  }

  deployment_controller {
  type = "ECS"
}

deployment_minimum_healthy_percent = 100
deployment_maximum_percent         = 200

   lifecycle {
    create_before_destroy = true
  }
  
  }

resource "aws_appautoscaling_target" "ecs_target" {
max_capacity = 4 #maximum amount of tasks that will run
min_capacity = 1 #minimum amount of tasks that will run
resource_id = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.app_service.name}"
scalable_dimension = "ecs:service:DesiredCount"
service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scaling_policy" {
  name               = "cpu-scaling-policy"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = 60.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 100
    scale_out_cooldown = 100
  }
}


resource "aws_security_group" "ecs_service_security_group" {
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
    tags = {
    name = "ECS_Security_Group_CreatedBy_Team1"
    environment ="gurmel_horseback_riding"

    }
}

#Load balancer app URL
output "app_url" {
  value = aws_alb.application_load_balancer.dns_name
}

resource "aws_cloudwatch_metric_alarm" "group1-monitoring" {
  alarm_name                = "group1-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors ECS CPU utilization"
  insufficient_data_actions = []

    lifecycle {
    create_before_destroy = true
  }
  tags = {
    name = "Alarm_CreatedBy_Team1"
    environment ="gurmel_canoeing_without_lifejacket"

    }
  
}

resource "aws_cloudwatch_log_group" "log_group" {
  name              = var.log_group_name
  retention_in_days = var.retention_days

  lifecycle {
    create_before_destroy = true
  }
    tags = {
    name = "Log_Group_CreatedBy_Team1"
    environment ="gurmel_annoying_locals"

    }
}

resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "group1-log-stream"
  log_group_name = aws_cloudwatch_log_group.log_group.name

    lifecycle {
    create_before_destroy = true
  }
  
}

resource "aws_s3_bucket" "team_one_s3" {
  bucket = "gus-is-the-best"
 
  tags = {
    Name       = "Bucket_CreatedBy_Team1"
    environment = "gurmel_at_karoke"
  }
}






