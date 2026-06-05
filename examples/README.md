# mk FILE= 예시 (형식 레퍼런스)

`mk` 의 `FILE=` 인자에 넣는 파일의 **형식 예시**다. 복사해서 값만 채워 쓴다(기록·재활용 목적).
각 타깃 help에 이 경로가 적혀 있다.

| 예시 파일 | mk 명령 | 형식 |
|-----------|---------|------|
| `lt-data.json` | `mk aws-eks-lt-create NAME=… FILE=lt-data.json` | EC2 LaunchTemplateData (JSON) |

> mk가 FILE 상대경로를 호출 위치 기준 절대경로로 바꿔 넘기므로, 현재 디렉토리에 복사해 두고 `FILE=lt-data.json` 처럼 쓰면 된다.

---

## lt-data.json — 런치템플릿 데이터 (`aws ec2 create-launch-template --launch-template-data`)

핀닝 노드그룹(인게임)용 런치템플릿의 데이터. 핵심 두 필드:

- **`SecurityGroupIds`** — `[클러스터 SG, 커스텀 SG]`.
  ⚠️ **클러스터 SG를 반드시 포함**한다(누락 시 노드가 컨트롤플레인과 통신 못 해 합류 실패).
  클러스터 SG: `mk aws-eks-describe` 의 `ClusterSG`. 커스텀 SG: `mk aws-sg-create` 로 만든 것(예: ingame-ds-sg).
- **`UserData`** — AL2023 NodeConfig(CPU 핀닝: `cpuManagerPolicy: static`, `full-pcpus-only`, `kubeReserved` 등)를 **base64 인코딩**한 문자열.
  NodeConfig 본문은 본 저장소가 아닌 설계 문서(§2.2)를 참고. 인코딩: `base64 -w0 nodeconfig.txt`.

`ImageId`/`InstanceType`은 보통 노드그룹 쪽(`--ami-type`, `--instance-types`)에서 지정하므로 런치템플릿엔 생략한다.

전체 필드 스키마: `aws ec2 create-launch-template help` 의 `--launch-template-data` 참고.
