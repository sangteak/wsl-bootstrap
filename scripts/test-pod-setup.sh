#!/bin/bash

# pprof 클라이언트 Pod 및 Service 생성 스크립트
# mm101-tutorial 네임스페이스에서 pprof 웹 UI 테스트용

set -e

NAMESPACE="mm101-tutorial"

echo "Creating pprof-client Pod and Service in ${NAMESPACE}..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pprof-client
  namespace: ${NAMESPACE}
  labels:
    app: pprof-client
spec:
  containers:
  - name: pprof
    image: golang:1.21
    command: ["sleep", "infinity"]
    ports:
    - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: pprof-client-svc
  namespace: ${NAMESPACE}
spec:
  type: NodePort
  selector:
    app: pprof-client
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
EOF

echo "Waiting for Pod to be ready..."
kubectl wait --for=condition=Ready pod/pprof-client -n ${NAMESPACE} --timeout=120s

echo ""
echo "=== Setup Complete ==="
echo ""
echo "1. Pod 접속:"
echo "   kubectl exec -it pprof-client -n ${NAMESPACE} -- bash"
echo ""
echo "2. Pod 내부에서 graphviz 설치 및 pprof 실행:"
echo "   apt-get update && apt-get install -y graphviz"
echo "   go tool pprof -http=0.0.0.0:8080 http://mm101-tutorial-director:6060/debug/pprof/heap"
echo ""
echo "3. 브라우저 접속:"
echo "   minikube service pprof-client-svc -n ${NAMESPACE}"
echo ""
echo "4. 정리:"
echo "   kubectl delete pod pprof-client -n ${NAMESPACE}"
echo "   kubectl delete svc pprof-client-svc -n ${NAMESPACE}"
