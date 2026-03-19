The purpose of this piece of work is to automate the deployment of a small, containerized web application in a production like AWS environment, whilst using best practices for security and observability.

Objectives:
- can an build and store a containerised application using docker
- deploys it to AWS using infrastructure as code
- implements monitoring and logging
- supports zero downtime updates
- is version controlled and collaborative

Stretch goals:
- add a health check endpoint and configure ALB to use it
- introduce auto-scaling on CPU usage

What this repository does?

Builds Docker image from local Dockerfile
Pushes to Elastic Container Registry
Updates ECS task definition with new image
Deploys to ECS cluster with health checks
Monitors rollout and alerts on failures


