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
# ng-describe 등에서 NAME= 생략 시 기본 노드그룹(local.mk에서 override). 인라인 주석 금지(값에 공백 섞임).
EKS_NG      ?= general
# Agones helm 차트 버전 핀. 비우면 최신. local.mk에서 'AGONES_VERSION := 1.43.0' 식으로 override.
AGONES_VERSION ?=

# AWS CLI v2 기본 페이저(less) 비활성화 — 짧은 테이블을 less로 열지 않고 인라인 출력.
# recipe 환경에만 적용되며 사용자 대화형 셸엔 영향 없음. (파이프 시엔 AWS가 알아서 끔)
export AWS_PAGER :=

# 인자 변수는 mk가 명령줄(KEY=val)로 전달한다. 같은 이름의 '환경변수' 누출(예: $NAME=호스트명)은
# make가 변수로 흡수해 가드를 무력화하므로, 환경 출처(origin=environment)인 것만 비운다.
# (명령줄로 넘긴 값은 origin=command line 이라 보존됨)
ARG_VARS := NAME VPC PROTO FROM TO CIDR DESC SG FILE YES
$(foreach v,$(ARG_VARS),$(if $(filter environment,$(origin $(v))),$(eval $(v) :=)))

.PHONY: help ctx-eks ctx-local aws-tools aws-whoami aws-can aws-clusters aws-login change-shell contrib-install-hooks contrib-edit aws-sg-create aws-sg-authorize aws-sg-list aws-sg-delete aws-eks-describe aws-eks-nodes aws-eks-ng-list aws-eks-ng-describe aws-eks-cluster-create aws-eks-ng-create aws-eks-ng-delete aws-eks-lt-delete helm-agones helm-status

# ── 공통 해소(이름 기반 디스커버리, D-03=C) ──────────────────
# VPC: 인자 VPC= 우선, 없으면 EKS_CLUSTER 의 VPC 를 describe 로 해소.
define RESOLVE_VPC
VPC="$(VPC)"
if [ -z "$$VPC" ]; then
  if [ "$(EKS_CLUSTER)" = "CHANGE_ME" ]; then echo "VPC= 를 주거나 ~/.peach.local.mk 에 EKS_CLUSTER 를 설정하세요" >&2; exit 1; fi
  VPC=$$(aws eks describe-cluster --name $(EKS_CLUSTER) --region $(AWS_REGION) --profile $(AWS_PROFILE) --query 'cluster.resourcesVpcConfig.vpcId' --output text)
fi
endef
# SG ID: 이름(NAME)+VPC 로 describe 해 ID 를 즉석 해소(저장 안 함).
define RESOLVE_SG
SG=$$(aws ec2 describe-security-groups --filters Name=group-name,Values="$(NAME)" Name=vpc-id,Values="$$VPC" --region $(AWS_REGION) --profile $(AWS_PROFILE) --query 'SecurityGroups[0].GroupId' --output text)
if [ -z "$$SG" ] || [ "$$SG" = "None" ]; then echo "SG '$(NAME)' 를 VPC $$VPC 에서 찾지 못했습니다" >&2; exit 1; fi
endef

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

aws-login: ## 콘솔 로그인(브라우저 자동·자동갱신). 세션 만료 시 재실행 ('--remote' 금지)
	aws login --profile $(AWS_PROFILE)

##@ aws sg — 보안그룹 (mk aws-sg-<동작>). NAME=엔 SG '이름'을 넣는다(sg-ID 아님) → 내부에서 ID 자동해소
aws-sg-create: ## 생성 (NAME= [DESC=] [VPC=])
	@test -n "$(NAME)" || { echo "NAME= 필요 (예: mk aws sg create NAME=ingame-ds-sg)" >&2; exit 1; }
	$(RESOLVE_VPC)
	aws ec2 create-security-group --group-name "$(NAME)" --description "$(if $(DESC),$(DESC),$(NAME))" \
	  --vpc-id "$$VPC" --region $(AWS_REGION) --profile $(AWS_PROFILE) --query GroupId --output text

aws-sg-authorize: ## 인바운드 규칙 추가 (NAME= PROTO= FROM= TO= [CIDR=] [VPC=])
	@test -n "$(NAME)" || { echo "NAME= 필요" >&2; exit 1; }
	@test -n "$(PROTO)" && test -n "$(FROM)" && test -n "$(TO)" || { echo "PROTO= FROM= TO= 필요" >&2; exit 1; }
	$(RESOLVE_VPC)
	$(RESOLVE_SG)
	aws ec2 authorize-security-group-ingress --group-id "$$SG" --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  --ip-permissions "IpProtocol=$(PROTO),FromPort=$(FROM),ToPort=$(TO),IpRanges=[{CidrIp=$(if $(CIDR),$(CIDR),0.0.0.0/0)}]"

aws-sg-list: ## 인바운드/아웃바운드 규칙 조회 (NAME= [VPC=])
	@test -n "$(NAME)" || { echo "NAME= 필요" >&2; exit 1; }
	$(RESOLVE_VPC)
	$(RESOLVE_SG)
	aws ec2 describe-security-group-rules --filters Name=group-id,Values="$$SG" --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  --query 'SecurityGroupRules[].{Id:SecurityGroupRuleId,Egress:IsEgress,Proto:IpProtocol,From:FromPort,To:ToPort,CIDR:CidrIpv4,SrcSG:ReferencedGroupInfo.GroupId}' --output table

aws-sg-delete: ## 삭제 (NAME= [VPC=])
	@test -n "$(NAME)" || { echo "NAME= 필요" >&2; exit 1; }
	$(RESOLVE_VPC)
	$(RESOLVE_SG)
	aws ec2 delete-security-group --group-id "$$SG" --region $(AWS_REGION) --profile $(AWS_PROFILE)
	echo "deleted SG '$(NAME)' ($$SG)"

##@ aws eks — 클러스터·노드그룹 라이프사이클 (mk aws eks <명령>; 삭제는 YES=1 확인)
aws-eks-describe: ## 클러스터 VPC·clusterSG·endpoint 조회 (describe-cluster)
	@if [ "$(EKS_CLUSTER)" = "CHANGE_ME" ]; then echo "EKS_CLUSTER 미설정 (~/.peach.local.mk)" >&2; exit 1; fi
	aws eks describe-cluster --name $(EKS_CLUSTER) --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  --query 'cluster.{Name:name,Status:status,Version:version,VPC:resourcesVpcConfig.vpcId,ClusterSG:resourcesVpcConfig.clusterSecurityGroupId,Endpoint:endpoint}' --output table

aws-eks-nodes: ## 노드 목록(기본 컬럼 + 인스턴스타입·arch) — kubectl get nodes -L
	kubectl get nodes -L node.kubernetes.io/instance-type -L kubernetes.io/arch

aws-eks-ng-list: ## 노드그룹 목록·TYPE(managed/unmanaged) (eksctl)
	@if [ "$(EKS_CLUSTER)" = "CHANGE_ME" ]; then echo "EKS_CLUSTER 미설정 (~/.peach.local.mk)" >&2; exit 1; fi
	AWS_PROFILE=$(AWS_PROFILE) eksctl get nodegroup --cluster $(EKS_CLUSTER) --region $(AWS_REGION)

aws-eks-ng-describe: ## 노드그룹 role·subnets 조회 (NAME= 생략 시 EKS_NG=general)
	@if [ "$(EKS_CLUSTER)" = "CHANGE_ME" ]; then echo "EKS_CLUSTER 미설정 (~/.peach.local.mk)" >&2; exit 1; fi
	aws eks describe-nodegroup --cluster-name $(EKS_CLUSTER) --nodegroup-name "$(if $(NAME),$(NAME),$(EKS_NG))" --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  --query 'nodegroup.{Role:nodeRole,Subnets:subnets,Status:status,Type:nodegroupType}' --output table

aws-eks-cluster-create: ## 클러스터 생성 (FILE=cluster.yaml; eksctl -f)
	@test -n "$(FILE)" || { echo "FILE= 필요 (예: mk aws eks cluster-create FILE=cluster.yaml)" >&2; exit 1; }
	@test -f "$(FILE)" || { echo "파일 없음: $(FILE)" >&2; exit 1; }
	AWS_PROFILE=$(AWS_PROFILE) eksctl create cluster -f "$(FILE)"

aws-eks-ng-create: ## 노드그룹 생성 (FILE=ng.json; --cli-input-json)
	@test -n "$(FILE)" || { echo "FILE= 필요 (예: mk aws eks ng-create FILE=ng.json)" >&2; exit 1; }
	@test -f "$(FILE)" || { echo "파일 없음: $(FILE)" >&2; exit 1; }
	aws eks create-nodegroup --cli-input-json "file://$(FILE)" --region $(AWS_REGION) --profile $(AWS_PROFILE)

aws-eks-ng-delete: ## 노드그룹 삭제 (NAME= YES=1)
	@test -n "$(NAME)" || { echo "NAME= 필요 (예: mk aws eks ng-delete NAME=ingame-ds)" >&2; exit 1; }
	@if [ "$(EKS_CLUSTER)" = "CHANGE_ME" ]; then echo "EKS_CLUSTER 미설정 (~/.peach.local.mk)" >&2; exit 1; fi
	echo "▼ 삭제 대상 (cluster=$(EKS_CLUSTER)):" >&2
	aws eks describe-nodegroup --cluster-name $(EKS_CLUSTER) --nodegroup-name "$(NAME)" --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  --query 'nodegroup.{NG:nodegroupName,Status:status,Type:nodegroupType,Desired:scalingConfig.desiredSize,Min:scalingConfig.minSize,Max:scalingConfig.maxSize}' --output table
	if [ "$(YES)" != "1" ]; then
	  echo "" >&2
	  echo "⚠️  이 노드그룹을 삭제하면 해당 노드의 진행 중 매치가 모두 종료됩니다." >&2
	  echo "    확인하려면 YES=1 을 추가하세요:  mk aws eks ng-delete NAME=$(NAME) YES=1" >&2
	  exit 1
	fi
	aws eks delete-nodegroup --cluster-name $(EKS_CLUSTER) --nodegroup-name "$(NAME)" --region $(AWS_REGION) --profile $(AWS_PROFILE)
	echo "✅ 삭제 요청됨: nodegroup '$(NAME)' (비동기 — mk aws eks ng-list 로 진행 확인)"

aws-eks-lt-delete: ## 런치템플릿 삭제 (NAME= YES=1)
	@test -n "$(NAME)" || { echo "NAME= 필요 (예: mk aws eks lt-delete NAME=ingame-lt)" >&2; exit 1; }
	echo "▼ 삭제 대상:" >&2
	aws ec2 describe-launch-templates --launch-template-names "$(NAME)" --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  --query 'LaunchTemplates[0].{Name:LaunchTemplateName,Id:LaunchTemplateId,Default:DefaultVersionNumber,Latest:LatestVersionNumber}' --output table
	if [ "$(YES)" != "1" ]; then
	  echo "    확인하려면 YES=1 을 추가하세요:  mk aws eks lt-delete NAME=$(NAME) YES=1" >&2
	  exit 1
	fi
	aws ec2 delete-launch-template --launch-template-name "$(NAME)" --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  --query 'LaunchTemplate.LaunchTemplateId' --output text
	echo "✅ 삭제됨: launch-template '$(NAME)'"

##@ helm — 클러스터 차트 (mk helm-<차트>; upgrade --install 으로 멱등)
helm-agones: ## Agones 설치/업그레이드 (agones-system, 컨트롤러 대기). 버전=AGONES_VERSION(미지정 시 최신)
	helm repo add agones https://agones.dev/chart/stable
	helm repo update agones
	helm upgrade --install agones agones/agones \
	  --namespace agones-system --create-namespace \
	  $(if $(AGONES_VERSION),--version $(AGONES_VERSION),)
	kubectl -n agones-system rollout status deploy/agones-controller --timeout=5m

helm-status: ## 설치된 helm 릴리스 목록 (helm list -A)
	helm list -A

change-shell: ## 기본 셸을 zsh로 변경
	sudo chsh -s "$$(which zsh)" "$$USER"

##@ contrib — 저장소 기여 (mk contrib <명령>)
contrib-install-hooks: ## 이 clone에 누출 가드(pre-commit) 활성화
	git -C $(HOME)/.peach config core.hooksPath hooks 2>/dev/null || git config core.hooksPath hooks
	chmod +x $(HOME)/.peach/hooks/pre-commit 2>/dev/null || true
	@echo "core.hooksPath=hooks 설정 완료(누출 가드 활성)"
contrib-edit: ## 관리 dotfile을 $EDITOR로 열기 (mk contrib edit [zshrc|gitconfig|p10k|nvim])
	@target="$(ARGS)"; case "$$target" in \
	  zshrc|"") f="$(HOME)/.peach/dotfiles/zshrc.shared" ;; \
	  gitconfig) f="$(HOME)/.peach/dotfiles/gitconfig.shared" ;; \
	  p10k) f="$(HOME)/.peach/dotfiles/p10k.zsh" ;; \
	  nvim) f="$(HOME)/.peach/config/nvim/shared.vim" ;; \
	  *) echo "알 수 없는 대상: $$target (zshrc|gitconfig|p10k|nvim)"; exit 1 ;; \
	esac; \
	$${EDITOR:-vi} "$$f"
