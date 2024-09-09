#!/usr/bin/env bash

set +e
set -o errexit
set -o nounset
set -o pipefail

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help                              Display help
    -t, --type                              Run type
                                              1) terraform init
                                              2) terraform destroy
    -cv, --cluster-version                  EKS cluster version (e.g. 1.25)
    -it, --instance-type                    Node instance type (amd64/arm64)
    -cn, --cluster-name                     EKS cluster name
    -ns, --node-size                        Node size
    -nt, --node-type                        Node type
    -cr, --cluster-region                   EKS cluster region
EOF
}

terraform_init() {
    echo "terraform init"
    terraform init

    if [[ "$INSTANCE_TYPE" == "arm64" ]]; then
        cp terraform.tfvars.arm64 terraform.tfvars
    else
        cp terraform.tfvars.amd64 terraform.tfvars
    fi

    if [[ "$UNAME" == "Darwin" ]]; then
        if [[ -n "$CLUSTER_VERSION" ]]; then
            sed -i '' 's/^cluster_version.*/cluster_version = "'$CLUSTER_VERSION'"/' terraform.tfvars
        fi

        if [[ -n "$CLUSTER_NAME" ]]; then
            sed -i '' 's/^cluster_name.*/cluster_name = "'$CLUSTER_NAME'"/' terraform.tfvars
        fi

        if [[ -n "$CLUSTER_REGION" ]]; then
            sed -i '' 's/^region.*/region = "'$CLUSTER_REGION'"/' terraform.tfvars
        fi

        if [[ -n "$NODE_SIZE" ]]; then
            sed -i '' 's/^min_size.*/min_size = '$NODE_SIZE'/' terraform.tfvars
            sed -i '' 's/^max_size.*/max_size = '$NODE_SIZE'/' terraform.tfvars
            sed -i '' 's/^desired_size.*/desired_size = '$NODE_SIZE'/' terraform.tfvars
        fi

        if [[ -n "$NODE_TYPE" ]]; then
            sed -i '' 's/^instance_types.*/instance_types = ["'$NODE_TYPE'"]/' terraform.tfvars
        fi
    else
        if [[ -n "$CLUSTER_VERSION" ]]; then
            sed -i 's/^cluster_version.*/cluster_version = "'$CLUSTER_VERSION'"/' terraform.tfvars
        fi

        if [[ -n "$CLUSTER_NAME" ]]; then
            sed -i 's/^cluster_name.*/cluster_name = "'$CLUSTER_NAME'"/' terraform.tfvars
        fi

        if [[ -n "$CLUSTER_REGION" ]]; then
            sed -i 's/^region.*/region = "'$CLUSTER_REGION'"/' terraform.tfvars
        fi

        if [[ -n "$NODE_SIZE" ]]; then
            sed -i 's/^min_size.*/min_size = '$NODE_SIZE'/' terraform.tfvars
            sed -i 's/^max_size.*/max_size = '$NODE_SIZE'/' terraform.tfvars
            sed -i 's/^desired_size.*/desired_size = '$NODE_SIZE'/' terraform.tfvars
        fi

        if [[ -n "$NODE_TYPE" ]]; then
            sed -i 's/^instance_types.*/instance_types = ["'$NODE_TYPE'"]/' terraform.tfvars
        fi
    fi

    echo "terraform plan -out aws_eks"
    terraform plan -out aws_eks

    echo "terraform apply aws_eks"
    terraform apply aws_eks
}

terraform_destroy() {
    echo "terraform init"
    terraform init

    chmod -R u+x .terraform

    echo "terraform destroy"
    terraform destroy -auto-approve
}

main() {
    local CLUSTER_VERSION=""
    local INSTANCE_TYPE=""
    local CLUSTER_NAME=""
    local NODE_SIZE=""
    local NODE_TYPE=""
    local UNAME=`uname -s`
    local CLUSTER_REGION=""

    parse_command_line "$@"

    if [[ -z "$CLUSTER_REGION" ]]; then
        CLUSTER_REGION="cn-northwest-1"
    fi

    export TF_VAR_region=$CLUSTER_REGION

    case $TYPE in
        1)
            terraform_init
        ;;
        2)
            terraform_destroy
        ;;
        *)
            show_help
            break
        ;;
    esac
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
            ;;
            -t|--type)
                TYPE="$2"
                shift
            ;;
            -cv|--cluster-version)
                CLUSTER_VERSION="$2"
                shift
            ;;
            -it|--instance-type)
                INSTANCE_TYPE="$2"
                shift
            ;;
            -cn|--cluster-name)
                CLUSTER_NAME="$2"
                shift
            ;;
            -ns|--node-size)
                NODE_SIZE="$2"
                shift
            ;;
            -nt|--node-type)
                NODE_TYPE="$2"
                shift
            ;;
            -cr|--cluster-region)
                CLUSTER_REGION="$2"
                shift
            ;;
            *)
                break
            ;;
        esac
        shift
    done
}

main "$@"
