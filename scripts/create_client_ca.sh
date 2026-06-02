#!/bin/bash

EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout client.key -out client.crt -addext 'subjectAltName=IP:'${EXTERNAL_IP}''

CERT_FILE_VALUE=$(cat client.crt | base64 -w 0)

# In case of MacOS
# CERT_FILE_VALUE=$(cat client.crt | base64)

# allowlist client certificate
kubectl get secret allocator-client-ca -o json -n agones-system | jq '.data["client_trial.crt"]="'${CERT_FILE_VALUE}'"' | kubectl apply -f -

