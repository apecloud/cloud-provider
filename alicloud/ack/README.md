# Provision an ACK Cluster

If it is the first time to use Alibaba Cloud container service for Kubernetes (ACK), you need
to [activate the service](https://cs.console.aliyun.com/) and grant sufficient permissions.

Refer
the [Use Terraform to create an ACK managed cluster](https://www.alibabacloud.com/help/en/container-service-for-kubernetes/latest/use-terraform-to-create-a-managed-kubernetes-cluster).

## Before you start

Export environment variables for Alibaba Cloud secret id and secret key.

```shell
export ALICLOUD_ACCESS_KEY="************"
export ALICLOUD_SECRET_KEY="************"
```

## Usage

### init

Run the following command to initialize the environment for Terraform:

```bash
$ terraform init
```

### plan

Run the following command to create an execution plan:

```bash
$ terraform plan
```

### apply

Run the following command to create the cluster:

```bash
$ terraform apply
```

### destroy

Run the following command to destroy the cluster:

```bash
$ terraform destroy
```

**Note:** this example may create resources which cost money. Run `terraform destroy` if you don't need these resources.