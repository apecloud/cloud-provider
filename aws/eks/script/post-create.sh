#!/usr/bin/env bash

home=$(cd $(dirname "$0") && pwd)

region=$1
cluster_name=$2
context_name=$3

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

# echo cluster into to file eks.info that will be used by destroy.sh
echo "${region} ${cluster_name} ${context_name}" >"${home}/eks.info"

export KUBECONFIG=~/.kube/config
aws eks update-kubeconfig --region "${region}" --name "${cluster_name}"
if [ $? -ne 0 ]; then
    echo "update-kubeconfig fail"
    exit 1
fi
