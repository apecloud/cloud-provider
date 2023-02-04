#!/bin/env bash

#export TF_VAR_region='cn-north-1' 
#export TF_CLOUD_ORGANIZATION=apecloud

terraform init

terraform validate

terraform plan -out aws_eks

terraform apply aws_eks

# 配置kubeconfig:
aws eks update-kubeconfig --region $(terraform output -raw region) --name $(terraform output -raw cluster_name)

terraform destroy

