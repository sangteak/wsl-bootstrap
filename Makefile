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

.PHONY: help ctx-eks ctx-local aws-tools aws-whoami aws-can aws-clusters change-shell

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

##@ aws — AWS/EKS 권한·환경 점검 (mk aws <명령>)
aws-tools: ## 필수 도구 버전 확인(aws/eksctl/kubectl)
	aws --version
	eksctl version
	kubectl version --client

aws-whoami: ## 현재 AWS 신원(Arn) 확인
	aws sts get-caller-identity --query Arn --output text --profile $(AWS_PROFILE)

aws-can: ## EKS 생성 액션 허용 여부 시뮬레이션 (mk aws can [PRINCIPAL_ARN])
	@PRINCIPAL="$(ARGS)"
	if [ -z "$$PRINCIPAL" ]; then
	  PRINCIPAL="$$(aws sts get-caller-identity --query Arn --output text --profile $(AWS_PROFILE))"
	fi
	# 역할 기반 인증(SSO/AssumeRole)의 STS ARN을 simulate-principal-policy가 받는 IAM role ARN으로 정규화.
	# (IAM 사용자 ARN(user/...)은 패턴이 안 맞아 그대로 통과 → 부작용 없음)
	PRINCIPAL="$$(printf '%s' "$$PRINCIPAL" | sed 's#:sts:#:iam:#; s#assumed-role/\([^/]*\)/.*#role/\1#')"
	echo "PRINCIPAL=$$PRINCIPAL" >&2
	aws iam simulate-principal-policy \
	  --policy-source-arn "$$PRINCIPAL" \
	  --action-names \
	    eks:CreateCluster eks:CreateNodegroup eks:DescribeCluster \
	    ec2:CreateVpc ec2:CreateSubnet ec2:CreateSecurityGroup ec2:RunInstances \
	    iam:CreateRole iam:AttachRolePolicy iam:CreateServiceLinkedRole iam:PassRole \
	    cloudformation:CreateStack cloudformation:DescribeStacks \
	    autoscaling:CreateAutoScalingGroup \
	  --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' \
	  --output table \
	  --profile $(AWS_PROFILE)

aws-clusters: ## AWS EKS 클러스터 목록 조회
	aws eks list-clusters --region $(AWS_REGION) --profile $(AWS_PROFILE)

change-shell: ## 기본 셸을 zsh로 변경
	sudo chsh -s "$$(which zsh)" "$$USER"
