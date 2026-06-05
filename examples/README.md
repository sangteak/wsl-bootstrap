# mk FILE= 예시 (형식 레퍼런스)

`mk` 의 `FILE=` 인자에 넣는 파일의 **형식 예시**다. 복사해서 값(`<...>`)만 채워 쓴다(기록·재활용 목적).
각 타깃 help에 이 경로가 적혀 있다.

| 예시 파일 | mk 명령 | 형식 |
|-----------|---------|------|
| `cluster.yaml` | `mk aws-eks-cluster-create FILE=cluster.yaml` | eksctl ClusterConfig (YAML) |
| `ng.json` | `mk aws-eks-ng-create FILE=ng.json` | eks create-nodegroup (cli-input-json) |
| `lt-data.json` | `mk aws-eks-lt-create NAME=… FILE=lt-data.json` | ec2 LaunchTemplateData (JSON) |
| `sg-rules.json` | `mk aws-sg-authorize NAME=… FILE=sg-rules.json` | ec2 IpPermissions 배열 (JSON) |

> mk가 FILE 상대경로를 호출 위치 기준 절대경로로 바꿔 넘기므로, 현재 디렉토리에 복사해 두고 `FILE=cluster.yaml` 처럼 쓰면 된다.
> 전체 필드 스키마는 각 `aws … help` 또는 eksctl 문서 참고.

---

## cluster.yaml — eksctl ClusterConfig
- `iam.withOIDC: true` — IRSA용, 사실상 필수.
- `managedNodeGroups` — 기본 노드그룹. 핀닝 노드그룹은 별도(런치템플릿) 경로로.

## ng.json — 노드그룹 (`aws eks create-nodegroup --cli-input-json`)
- `nodeRole`/`subnets` — 기존 노드그룹 것 재사용: `mk aws-eks-ng-describe NAME=general` 의 Role·Subnets.
- `launchTemplate.id` — `mk aws-eks-lt-create` 출력의 `lt-…`. `version`은 `"$Latest"`.
- ⚠️ 커스텀 LT 쓸 땐 **instanceTypes는 노드그룹에만**(LT엔 InstanceType 넣지 말 것 — 충돌).

## lt-data.json — 런치템플릿 데이터 (`aws ec2 create-launch-template --launch-template-data`)
- `SecurityGroupIds` — `[클러스터 SG, 커스텀 SG]`. ⚠️ **클러스터 SG 반드시 포함**(누락 시 노드 합류 실패).
  클러스터 SG: `mk aws-eks-describe` 의 ClusterSG. 커스텀 SG: `mk aws-sg-list NAME=<이름>` 상단의 SG ID.
- `UserData` — AL2023 NodeConfig(핀닝)를 base64. 인코딩: `base64 -w0 nodeconfig.txt`.
- ImageId/InstanceType은 보통 노드그룹에서 지정하므로 생략.

## sg-rules.json — 인바운드 규칙 (`aws ec2 authorize-security-group-ingress --ip-permissions`)
- 배열 안에 규칙 객체 여러 개(멀티포트·멀티소스).
- 출발지: `IpRanges`(CIDR) 또는 `UserIdGroupPairs`(소스 SG, `GroupId`는 `sg-…` ID).
- `Description`으로 규칙 용도 표기(감사성).
