# Terraform Kubernetes example based on TencentCloud Tke Module

Provides example to show how to use kubernetes provider to create a simple Kubernetes application based on TencentCloud
TKE module.

## Usage

Export environment variables for TencentCloud secret id and secret key.

```shell
export TENCENTCLOUD_SECRET_ID=xxx
export TENCENTCLOUD_SECRET_KEY=xxx
```

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Note, this example may create resources which cost money. Run `terraform destroy` if you don't need these resources.