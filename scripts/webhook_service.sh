#!/usr/bin/env bash
kubectl delete deployment autoscaler-webhook

kubectl delete service autoscaler-webhook-service

kubectl apply -f ~/agones2/examples/autoscaler-webhook/autoscaler-service.yaml
