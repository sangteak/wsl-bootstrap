#!/usr/bin/env bash
#kubectl config use-context arn:aws:eks:ap-northeast-2:REDACTED_ACCOUNT:cluster/redacted-cluster
#kubectl config get-contexts

aws eks update-kubeconfig --region ap-northeast-2 --name redacted-cluster --profile sangtakeg
