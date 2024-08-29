#!/bin/bash

# make sure you have created an Ec2 key pair and downloaded key and replace Parameter key and value accordingly

# Create EC2 instance

aws cloudformation create-stack --stack-name eks-admin-instance --template-body file://ec2-admin-instance.yaml --parameters ParameterKey=KeyName,ParameterValue=ec2-dev --capabilities CAPABILITY_IAM

aws cloudformation wait stack-create-complete --stack-name eks-admin-instance

aws cloudformation describe-stacks --stack-name eks-admin-instance --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' --output text

