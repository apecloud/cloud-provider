#!/usr/bin/env bash

set +e
set -o errexit
set -o nounset
set -o pipefail

DEFAULT_ENABLE_SPOT=true
DEFAULT_DISK_SIZE=100

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
    -ds, --disk-size                        Disk size (default: $DEFAULT_DISK_SIZE)
    -ak, --access-key                       Volcengine access key
    -sk, --secret-key                       Volcengine secret key
EOF
}

terraform_init() {
    echo "rm addons.tf"
    if [[ -f "addons.tf" ]]; then
        rm -rf addons.tf
    fi

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
            sed -i '' "s/^region.*/region = \"${CLUSTER_REGION}\"/" terraform.tfvars
            zone_tmp="a"
            if [[ $(( $RANDOM % 2 )) == 0 ]]; then
                zone_tmp="b"
            fi
            zone="${CLUSTER_REGION}-${zone_tmp}"
            if [[ "$CLUSTER_REGION" == "ap-southeast-"* ]]; then
                zone="${CLUSTER_REGION}${zone_tmp}"
            fi
            sed -i '' "s/^zone.*/zone = \"${zone}\"/" terraform.tfvars
        fi

        if [[ -n "$NODE_SIZE" ]]; then
            sed -i '' 's/^node_count.*/node_count = '$NODE_SIZE'/' terraform.tfvars
        fi

        if [[ -n "$NODE_TYPE" ]]; then
            sed -i '' 's/^machine_type.*/machine_type = "'$NODE_TYPE'"/' terraform.tfvars
        fi

        if [[ -n "$DISK_SIZE" ]]; then
            sed -i '' 's/^volume_size.*/volume_size = '$DISK_SIZE'/' terraform.tfvars
        fi

        if [[ -n "$ACCESS_KEY" ]]; then
            sed -i '' 's/^access_key.*/access_key = "'$ACCESS_KEY'"/' terraform.tfvars
        fi

        if [[ -n "$SECRET_KEY" ]]; then
            sed -i '' 's/^secret_key.*/secret_key = "'$SECRET_KEY'"/' terraform.tfvars
        fi
    else
        if [[ -n "$CLUSTER_VERSION" ]]; then
            sed -i 's/^cluster_version.*/cluster_version = "'$CLUSTER_VERSION'"/' terraform.tfvars
        fi

        if [[ -n "$CLUSTER_NAME" ]]; then
            sed -i 's/^cluster_name.*/cluster_name = "'$CLUSTER_NAME'"/' terraform.tfvars
        fi

        if [[ -n "$CLUSTER_REGION" ]]; then
            sed -i "s/^region.*/region = \"${CLUSTER_REGION}\"/" terraform.tfvars
            zone_tmp="a"
            if [[ $(( $RANDOM % 2 )) == 0 ]]; then
                zone_tmp="b"
            fi
            zone="${CLUSTER_REGION}-${zone_tmp}"
            if [[ "$CLUSTER_REGION" == "ap-southeast-"* ]]; then
                zone="${CLUSTER_REGION}${zone_tmp}"
            fi
            sed -i "s/^zone.*/zone = \"${zone}\"/" terraform.tfvars
        fi

        if [[ -n "$NODE_SIZE" ]]; then
            sed -i 's/^node_count.*/node_count = '$NODE_SIZE'/' terraform.tfvars
        fi

        if [[ -n "$NODE_TYPE" ]]; then
            sed -i 's/^machine_type.*/machine_type = "'$NODE_TYPE'"/' terraform.tfvars
        fi

        if [[ -n "$DISK_SIZE" ]]; then
            sed -i 's/^volume_size.*/volume_size = '$DISK_SIZE'/' terraform.tfvars
        fi

        if [[ -n "$ACCESS_KEY" ]]; then
            sed -i 's/^access_key.*/access_key = "'$ACCESS_KEY'"/' terraform.tfvars
        fi

        if [[ -n "$SECRET_KEY" ]]; then
            sed -i 's/^secret_key.*/secret_key = "'$SECRET_KEY'"/' terraform.tfvars
        fi
    fi

    echo "terraform plan -out volcengine_vke"
    terraform plan -out volcengine_vke

    echo "terraform apply volcengine_vke"
    terraform apply volcengine_vke

    touch addons.tf
    tee addons.tf << EOF
resource "volcengine_vke_addon" "vke-tf-addon-core-dns" {
  cluster_id       = volcengine_vke_cluster.vke-tf-cluster.id
  name             = "core-dns"
  version          = "1.10.1-vke.400"
  deploy_node_type = "Node"
  deploy_mode      = "Unmanaged"
}

resource "volcengine_vke_addon" "vke-tf-addon-csi-ebs" {
  cluster_id       = volcengine_vke_cluster.vke-tf-cluster.id
  name             = "csi-ebs"
  version          = "v1.2.4"
  deploy_node_type = "Node"
  deploy_mode      = "Unmanaged"
}
EOF

    echo "terraform plan -out volcengine_vke"
    terraform plan -out volcengine_vke

    echo "terraform apply volcengine_vke"
    terraform apply volcengine_vke

}

terraform_destroy() {
    echo "terraform state rm core-dns"
    echo "$(terraform state rm volcengine_vke_addon.vke-tf-addon-core-dns)"

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
    local ENABLE_SPOT=$DEFAULT_ENABLE_SPOT
    local DISK_SIZE=$DEFAULT_DISK_SIZE
    local ACCESS_KEY=""
    local SECRET_KEY=""

    parse_command_line "$@"

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
            -ds|--disk-size)
                DISK_SIZE="$2"
                shift
            ;;
            -ak|--access-key)
                ACCESS_KEY="$2"
                shift
            ;;
            -sk|--secret-key)
                SECRET_KEY="$2"
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
