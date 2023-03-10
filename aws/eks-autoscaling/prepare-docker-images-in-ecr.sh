IMAGES=$(cat <<END | awk -v ORS=' ' 1
registry.k8s.io/autoscaling/cluster-autoscaler:v1.26.1
registry.k8s.io/metrics-server/metrics-server:v0.6.2
public.ecr.aws/karpenter/controller:v0.26.1
ghcr.io/kedacore/keda:2.9.3
ghcr.io/kedacore/keda-metrics-apiserver:2.9.3
docker.io/kubernetesui/dashboard:v2.7.0
END
)
AWS_DEFAULT_REGION=cn-northwest-1
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