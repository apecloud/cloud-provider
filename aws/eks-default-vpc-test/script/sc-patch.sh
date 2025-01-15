#!/usr/bin/env bash

home=$(cd `dirname $0` && pwd)

region=$1
cluster_name=$2

if [ "x${region}" = "x" ];then
    echo "region is empty"
    exit 1
fi

if [ "x${cluster_name}" = "x" ];then
    echo "cluster_name is empty"
    exit 1
fi

echo "storage class patch: region=${region}, cluster_name=${cluster_name}"

aws eks update-kubeconfig --region ${region} --name ${cluster_name}
if [ $? -ne 0 ];then
    echo "update-kubeconfig fail"
    exit 1
fi

kubectl annotate sc gp2 storageclass.kubernetes.io/is-default-class-
if [ $? -ne 0 ];then
    echo "remove default annotation from storage class gp2 fail, ignore"
fi

kubectl apply -f ${home}/gp3.yaml
if [ $? -ne 0 ];then
    echo "apply storage class gp3 fail"
    exit 1
fi
