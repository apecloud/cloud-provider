#!/usr/bin/env bash

home=$(cd $(dirname $0) && pwd)
read -r region cluster_name context_name <"$home/eks.info"

# echo cluster info
echo "region: $region"
echo "cluster_name: $cluster_name"
echo "context_name: $context_name"

if [ "x${region}" = "x" ]; then
    echo "region is empty"
    exit 1
fi

if [ "x${cluster_name}" = "x" ]; then
    echo "cluster_name is empty"
    exit 1
fi

if [ "x${context_name}" = "x" ]; then
    echo "context_name is empty"
    exit 1
fi


# update kubeconfig and switch to current cluster context
aws eks update-kubeconfig --region "${region}" --name "${cluster_name}"
if [ $? -ne 0 ]; then
    echo "update-kubeconfig fail"
    exit 1
fi

# Before destroy eks cluster, remove resources that not controlled by terraform,
# such as PVC, PV etc.

# remove cluster info from kubeconfig
kubectl config delete-context "${context_name}"
kubectl config delete-cluster "${context_name}"
kubectl config delete-user "${context_name}"
