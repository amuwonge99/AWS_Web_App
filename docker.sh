#!/bin/bash

#script to execute docker commands

aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 108302758118.dkr.ecr.eu-west-2.amazonaws.com
docker build -t app-repo .
docker tag app-repo:latest <account_id>.dkr.ecr.eu-west-2.amazonaws.com/app-repo:latest
docker push 108302758118.dkr.ecr.eu-west-2.amazonaws.com/app-repo:latest
docker run -it 108302758118.dkr.ecr.eu-west-2.amazonaws.com/app-repo:latest