#Built a Docker container
#Implemented lifecycle block on resources to satisfy zero downtime criteria



terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.45.0"
    }
  }


   #Storing tfstate remotely. Explain benefit & hurdles if done incorrectly
   #S3 bucket must be created locally before implementing
   backend "s3" {
    bucket = "gus-is-the-best"
    key    = "terraform.tfstate"
    region = "eu-west-2"
    profile= "default"
  }

 
}

provider "aws" {
  region     = "eu-west-2" 
  profile = "default" #uses aws credentials from home directory, explain benefit.
}

#ECR repository. Explain relation to Docker
resource "aws_ecr_repository" "app_ecr_repo" {
  name = "app-repo"

    tags = {
    name = "ECR_CreatedBy_Team1"

    }
}


resource "aws_ecs_cluster" "my_cluster" {
  name = "app-cluster"
  
    tags = {
    name = "ECS_CreatedBy_Team1"
    }

}


#Task Definition, explain use
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


#VPC
# Provide a reference to your default VPC
resource "aws_default_vpc" "default_vpc" {

    lifecycle {
    create_before_destroy = true
  }
  tags = {
    name = "VPC_CreatedBy_Team1"

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

}





#Configure the load balancer with the VPC networking
resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" # default VPC

}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" #  load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # target group
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
   
  }

resource "aws_appautoscaling_target" "ecs_target" {
max_capacity = 4
min_capacity = 1
resource_id = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.app_service.name}"
scalable_dimension = "ecs:service:DesiredCount"
service_namespace = "ecs"
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
  namespace                 = "AWS/ECS"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors ECR cpu utilization"
  insufficient_data_actions = []

  
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

# Create an S3 bucket
resource "aws_s3_bucket" "team_one_s3" {
  bucket = "gus-is-the-best"
 
  tags = {
    Name       = "Our_bucket"
  }
}


