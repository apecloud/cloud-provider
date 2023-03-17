#!/usr/bin/env bash

# specified region and must correspond to the aws cli configure
# below regions has been tested pass
export TF_VAR_region='cn-northwest-1'
#export TF_VAR_region='us-west-2'

# specified available zones if needed, limit only 1 zone here for save cost
export TF_VAR_available_zones='["cn-northwest-1b"]'

# initializes a working directory containing Terraform configuration files
terraform init -upgrade

# creates an execution plan
terraform plan -out kb_aws_eks

# executes the actions proposed in a Terraform plan
terraform apply kb_aws_eks

# destroy eks cluster
# terraform destroy

