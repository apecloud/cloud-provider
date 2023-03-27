# Provision an TKE Cluster

## Before you start

https://cloud.tencent.com/document/product/1653/82868

Export environment variables for TencentCloud secret id and secret key.

```shell
export TENCENTCLOUD_SECRET_ID=xxx
export TENCENTCLOUD_SECRET_KEY=xxx
```

## Usage

### init

```bash
$ terraform init
```

### plan

```bash
$ terraform plan
```

### apply 

```bash
$ terraform apply
```

### destroy

```bash
$ terraform destroy
```
**Note:** this example may create resources which cost money. Run `terraform destroy` if you don't need these resources.