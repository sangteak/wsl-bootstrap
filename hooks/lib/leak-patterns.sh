#!/usr/bin/env bash
# 누출 탐지 정규식(가드/테스트 공유). grep -E 용. 고정밀 우선.
# shellcheck disable=SC2034  # 라이브러리 파일: 소싱 스크립트에서 사용됨
PEACH_LEAK_PATTERNS=(
    '/home/[A-Za-z0-9._-]+'                       # 홈 절대경로
    '/mnt/[cdCD]/'                                # Windows 드라이브 마운트
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'  # 이메일
    '(^|[^0-9])(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)[0-9]'  # 사설 IP
    'AKIA[0-9A-Z]{16}'                            # AWS access key
    'ghp_[A-Za-z0-9]{20,}'                        # GitHub PAT
    'BEGIN [A-Z ]*PRIVATE KEY'                    # PEM 키
)
