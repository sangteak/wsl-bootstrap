# peach ops Makefile — zsh 함수 'mk <target>' 으로 어디서나 실행한다.
# 머신 종속 식별자는 ~/.peach.local.mk 에 둔다(저장소 커밋 금지). 아래 -include 가 로드.
#   cp ~/.peach/peach.local.mk.example ~/.peach.local.mk
SHELL := bash
.SHELLFLAGS := -e -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := help

-include $(HOME)/.peach.local.mk

AWS_PROFILE ?= default
AWS_REGION  ?= ap-northeast-2
EKS_CLUSTER ?= CHANGE_ME
DOCKER_NS   ?= CHANGE_ME
MM_NS       ?= mm101-tutorial
WEBHOOK     ?= autoscaler-webhook
AGONES_DIR  ?= $(HOME)/agones2

.PHONY: help switch-aws switch-local login-elk logs-webhook webhook-redeploy docker-rmi delete-gs delete-mm101 gs-ready client-ca etcd-pf change-shell

help: ## 이 명령 목록 출력
	@grep -hE '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN{FS=":.*##"}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

switch-aws: ## AWS EKS kubeconfig 갱신(운영 클러스터)
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(EKS_CLUSTER) --profile $(AWS_PROFILE)

switch-local: ## kubectl 컨텍스트를 minikube로 전환
	kubectl config use-context minikube
	kubectl config get-contexts

login-elk: ## AWS EKS 클러스터 목록 조회
	aws eks list-clusters --region $(AWS_REGION) --profile $(AWS_PROFILE)

logs-webhook: ## autoscaler-webhook 로그(deployment 기준)
	kubectl logs deploy/$(WEBHOOK)

webhook-redeploy: ## autoscaler-webhook 삭제 후 재배포
	kubectl delete deployment $(WEBHOOK) --ignore-not-found
	kubectl delete service $(WEBHOOK)-service --ignore-not-found
	kubectl apply -f $(AGONES_DIR)/examples/autoscaler-webhook/autoscaler-service.yaml

docker-rmi: ## mm101-tutorial 로컬 이미지 삭제(best-effort)
	for img in matchfunction director frontend; do docker rmi $(DOCKER_NS)/mm101-tutorial-$$img:latest || true; done

delete-gs: ## simple-game-server fleet/autoscaler 삭제
	kubectl delete fleetautoscaler simple-game-server-autoscaler-kr --ignore-not-found
	kubectl delete fleet simple-game-server-kr --ignore-not-found

delete-mm101: ## mm101-tutorial pod 삭제
	for c in matchfunction director frontend; do kubectl delete -n $(MM_NS) pod/mm101-tutorial-$$c --ignore-not-found; done

gs-ready: ## Allocated 게임서버에 EXIT 패킷 전송
	kubectl get gs --no-headers 2>/dev/null | awk '/Allocated/ {print $$3, $$4}' | while read -r ip port; do [ -n "$$ip" ] && echo "EXIT" | timeout 1 nc -u "$$ip" "$$port" || true; done

client-ca: ## agones-allocator 클라이언트 CA 인증서 생성/등록
	EXTERNAL_IP=$$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout client.key -out client.crt -addext "subjectAltName=IP:$${EXTERNAL_IP}"
	CERT_FILE_VALUE=$$(base64 -w 0 client.crt)
	kubectl get secret allocator-client-ca -o json -n agones-system | jq ".data[\"client_trial.crt\"]=\"$${CERT_FILE_VALUE}\"" | kubectl apply -f -

etcd-pf: ## etcd 포트포워드(2379)
	kubectl port-forward service/etcd 2379:2379

change-shell: ## 기본 셸을 zsh로 변경
	sudo chsh -s "$$(which zsh)" "$$USER"
