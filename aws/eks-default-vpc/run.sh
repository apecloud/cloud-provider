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

    if [[ ! -z "$CLUSTER_VERSION" ]]; then
        sed -i '/cluster_version/s/*/cluster_version = '$CLUSTER_VERSION'/' terraform.tfvars
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

    parse_command_line "$@"

    export TF_VAR_region='cn-northwest-1'

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
            -it,|--instance-type)
                INSTANCE_TYPE="$2"
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
