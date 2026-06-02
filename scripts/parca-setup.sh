#!/bin/bash

# Parca 설치 스크립트
# mm101-tutorial 네임스페이스의 pprof 엔드포인트를 스크래핑

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/../k8s"
PARCA_VERSION="v0.25.0"

echo "=== Parca 설치 시작 ==="
echo ""

# Step 1: 네임스페이스 생성
echo "[1/5] parca 네임스페이스 생성..."
kubectl create namespace parca --dry-run=client -o yaml | kubectl apply -f -

# Step 2: ConfigMap 적용 (커스텀 scrape config)
echo "[2/5] Parca ConfigMap 적용..."
kubectl apply -f "${K8S_DIR}/parca-config.yaml"

# Step 3: Parca 매니페스트 다운로드 및 적용
echo "[3/5] Parca Server 배포..."
MANIFEST_URL="https://github.com/parca-dev/parca/releases/download/${PARCA_VERSION}/kubernetes-manifest.yaml"
curl -sL "${MANIFEST_URL}" | kubectl apply -f -

# Step 4: Pod 준비 대기
echo "[4/5] Parca Pod 준비 대기..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=parca -n parca --timeout=120s

# Step 5: Service를 LoadBalancer로 변경
echo "[5/5] Service를 LoadBalancer로 변경..."
kubectl patch svc parca -n parca -p '{"spec":{"type":"LoadBalancer"}}' 2>/dev/null || true

echo ""
echo "=== Parca 설치 완료 ==="
echo ""
echo "접속 방법:"
echo ""
echo "  Option A: port-forward"
echo "    kubectl port-forward svc/parca -n parca 7070:7070"
echo "    브라우저: http://localhost:7070"
echo ""
echo "  Option B: minikube tunnel (LoadBalancer)"
echo "    minikube tunnel"
echo "    kubectl get svc parca -n parca  # EXTERNAL-IP 확인"
echo ""
echo "상태 확인:"
echo "  kubectl get pods -n parca"
echo "  kubectl logs -f deployment/parca -n parca"
echo ""
echo "삭제:"
echo "  kubectl delete namespace parca"
