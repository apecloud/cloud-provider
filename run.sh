#!/usr/bin/env bash

# specified region and must correspond to the aws cli configure
# below regions has been tested pass
export TF_VAR_region='cn-north-1'
#export TF_VAR_region='us-west-2'

# specified available zones if needed, omit in most cases
#export TF_VAR_available_zones='["cn-north-1a", "cn-north-1b"]'

# create eks cluster
terraform init
#terraform validate
terraform plan -out aws_eks
terraform apply aws_eks

# destroy eks cluster
# terraform destroy

