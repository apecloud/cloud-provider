# Learn Terraform - Provision an EKS Cluster

This repo is a companion repo to the [Provision an EKS Cluster tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks), containing
Terraform configuration files to provision an EKS cluster on AWS.

# Prerequisites
* [AWS CLI](https://docs.amazonaws.cn/cli/latest/userguide/getting-started-install.html)
    * [Configure](https://docs.amazonaws.cn/cli/latest/userguide/cli-configure-quickstart.html) 
* [kubectl](https://kubernetes.io/zh-cn/docs/reference/kubectl/)
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

# Create && Delete All-In-One EKS Cluster on AWS
* Export Environment Variable
```
  # required, tested regions include ['cn-northwest-1', 'us-west-2']
  export TF_VAR_region='cn-northwest-1'
  
  # optional, no need to provide in most cases
  # export TF_VAR_available_zones='["cn-northwest-1a", "cn-northwest-1b"]'
```
* Create EKS Cluster
```
  terraform init
  #terraform validate
  terraform plan -out aws_eks
  terraform apply aws_eks
```
* Delete EKS Cluster
```
  terraform destroy
```
* Reference script run.sh.

# Caveat
* EKS will create failed when the number of Internet Gateway exceeds the limited number.
* EKS will create failed when the number of VPC exceeds the limited number.
![20230206-210235](https://user-images.githubusercontent.com/4612618/216978211-7d69f016-c2b9-406d-8736-cffe67762936.jpeg)

# Reference
* https://infracreate.feishu.cn/wiki/wikcnfSuZ20cByGf9zPBcdw0nhg
* https://infracreate.feishu.cn/docx/RAyUdION6otOAlxDQi1cb0dXnyd
