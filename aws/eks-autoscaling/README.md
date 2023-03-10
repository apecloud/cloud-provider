# Provision an Autoscaling EKS Cluster

## Prerequisites

- AWS CLI
- Docker
- Terraform >= 1.3.0
- Kubectl

## Step 0: Prepare Docker images in ECR

> Please ensure that your computer has stable Internet access to [K8S Registry (registry.k8s.io)](https://kubernetes.io/blog/2022/11/28/registry-k8s-io-faster-cheaper-ga/), GitHub Container Registry (ghcr.io), and AWS ECR Public (public.ecr.aws).

> You can skip this step if you have done it before.

prepare-docker-images-in-ecr.sh
```sh
IMAGES=$(cat <<END | awk -v ORS=' ' 1
registry.k8s.io/autoscaling/cluster-autoscaler:v1.26.1
registry.k8s.io/metrics-server/metrics-server:v0.6.2
public.ecr.aws/karpenter/controller:v0.26.1
ghcr.io/kedacore/keda:2.9.3
ghcr.io/kedacore/keda-metrics-apiserver:2.9.3
docker.io/kubernetesui/dashboard:v2.7.0
END
)

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_DNS_SUFFIX=$(echo $AWS_DEFAULT_REGION | grep -q ^cn- && echo ".cn")
ECR="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com$AWS_DNS_SUFFIX"

aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login \
    --username AWS --password-stdin $ECR

echo $IMAGES | while read -r -d ' ' IMAGE ; do
    IMAGE_WITHOUT_REGISTRY=${IMAGE#*/}
    REPO=${IMAGE_WITHOUT_REGISTRY%:*}

    aws ecr describe-repositories --repository-names $REPO 2>&1 \
        | grep -q RepositoryNotFoundException && \
            aws ecr create-repository --repository-name $REPO --region $AWS_DEFAULT_REGION | cat        

    docker pull --platform linux/arm64 $IMAGE
    docker tag  $IMAGE $ECR/${IMAGE#*/}
    docker push $ECR/${IMAGE#*/}
done
```

## Step 1: Provision the cluster

```sh
EKS_CLUSTER_NAME=<your cluster name here>

terraform init
terraform apply -var="cluster_name=$EKS_CLUSTER_NAME"
```

Alternatively, you can override other default settings in `variables.tf` by using [Variables on the Command Line](https://www.terraform.io/language/values/variables#variables-on-the-command-line) or a [`terraform.tfvars` file](https://developer.hashicorp.com/terraform/language/values/variables#variable-definitions-tfvars-files). See the [Variable Definition Precedence](https://www.terraform.io/language/values/variables#variable-definition-precedence).

> Typically, it will take **~20 minutes** to complete.

> `terraform apply` may fail due to timeout on waiting for the readiness of deployed resources. Please repeat this operation until success.

## Step 1.5 (Optional): Set a shorter cooldown period on EC2 Auto Scaling Groups

This will make the cluster autoscaler more responsive.

```sh
terraform output -json eks_managed_node_groups_autoscaling_group_names \
    | tr -d '[]"' | tr ',' '\n' \
    | xargs -I% aws autoscaling update-auto-scaling-group --auto-scaling-group-name % --default-cooldown 30
```

## Step 2: Update your `kubectl` configuration

```sh
aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name $(terraform output --raw cluster_name)

kubectl get nodes
```

If other IAM users under your AWS account want to access this cluster, they should run the following command instead:

```sh
EKS_CLUSTER_NAME=<the cluster name>

aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name $EKS_CLUSTER_NAME \
    --role-arn $(aws iam get-role --role-name $EKS_CLUSTER_NAME-admin-role --query 'Role.Arn' --output text)
```

## Step 3: Run some workload

### Try Cluster Autoscaler

You can tolerate the `autoscaler=ClusterAutoscaler:NoSchedule` [taint](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) to let the cluster autoscaler schedule your workload.

```sh
CAS_JSON_PATCH=$(cat <<END | awk '{$1=$1;print}' | tr -d '\n'
{
    "spec": {
        "containers": [{
            "name": "busybox",
            "resources": {
                "limits": {
                    "cpu": "100m",
                    "memory": "4096Mi"
                }
            }
        }],
        "tolerations": [{
            "key": "spot",
            "operator": "Equal",
            "value": "true"
        }, {
            "key": "autoscaler",
            "operator": "Equal",
            "value": "ClusterAutoscaler"
        }]
    }
}
END
)

kubectl run busybox --image=busybox:latest --rm -it \
    --override-type strategic \
    --overrides="$CAS_JSON_PATCH"
```

> `kubectl run` may fail due to timeout. Just repeat it until success.

### Try Karpenter

You can tolerate the `autoscaler=Karpenter:NoSchedule` [taint](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) to let Karpenter schedule your workload.

```sh
KARPENTER_JSON_PATCH=$(cat <<END | awk '{$1=$1;print}' | tr -d '\n'
{
    "spec": {
        "containers": [{
            "name": "busybox",
            "resources": {
                "limits": {
                    "cpu": "100m",
                    "memory": "8192Mi"
                }
            }
        }],
        "tolerations": [{
            "key": "spot",
            "operator": "Equal",
            "value": "true"
        }, {
            "key": "autoscaler",
            "operator": "Equal",
            "value": "Karpenter"
        }]
    }
}
END
)

kubectl run busybox --image=busybox:latest --rm -it \
    --override-type strategic \
    --overrides="$KARPENTER_JSON_PATCH"
```

## Access the Kubernetes Dashboard

```sh
kubectl -n kubernetes-dashboard create token admin-user
kubectl proxy
```

Visit [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:https/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:https/proxy/) and login with the token printed by the above command.

