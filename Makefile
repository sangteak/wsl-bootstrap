# peach ops Makefile — zsh 함수 'mk <그룹> <명령> [옵션...]' 으로 어디서나 실행한다.
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

.PHONY: help ctx-eks ctx-local aws-clusters change-shell

help: ## 이 명령 목록 출력
	@awk 'BEGIN{FS=":.*##"} /^##@/{printf "\n\033[1m%s\033[0m\n", substr($$0,5); next} /^[a-zA-Z0-9_-]+:.*##/{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ ctx — kubectl 컨텍스트 전환 (mk ctx <대상>)
ctx-eks: ## AWS EKS 클러스터로 전환(kubeconfig 갱신)
	@if [ "$(EKS_CLUSTER)" = "CHANGE_ME" ]; then \
	  echo "EKS_CLUSTER 가 설정되지 않았습니다." >&2; \
	  echo "  ~/.peach.local.mk 에 'EKS_CLUSTER := <클러스터명>' 을 추가하세요" >&2; \
	  echo "  (없으면: cp ~/.peach/peach.local.mk.example ~/.peach.local.mk)" >&2; \
	  exit 1; \
	fi
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(EKS_CLUSTER) --profile $(AWS_PROFILE)

ctx-local: ## minikube(로컬)로 전환
	kubectl config use-context minikube
	kubectl config get-contexts

##@ (정리 예정) — 그룹 미확정
aws-clusters: ## AWS EKS 클러스터 목록 조회
	aws eks list-clusters --region $(AWS_REGION) --profile $(AWS_PROFILE)

change-shell: ## 기본 셸을 zsh로 변경
	sudo chsh -s "$$(which zsh)" "$$USER"
