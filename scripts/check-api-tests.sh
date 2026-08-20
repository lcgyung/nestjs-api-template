#!/usr/bin/env bash
# API 테스트 3종 강제 (변경분 한정).
#
# 정책(정본: .claude/rules/testing.md "API 완성의 정의"):
#   컨트롤러가 구현된 모듈/엔드포인트는 controller spec · service spec · e2e 가 모두 있어야 한다.
#   spec 은 컨트롤러 파일과 같은 디렉터리(하위 리소스 디렉터리 포함), e2e 는 test/ 에서 찾는다.
#
# 범위(중요): **레포 전체 스캔이 아니라 git 변경분(작업이 들어간 파일)에 든 모듈만** 검사한다.
#   - 엔티티 전용 모듈(컨트롤러 없음)·미변경 모듈은 검사하지 않는다(일괄 구현이 아니므로).
#   - 컨트롤러가 있는데 그에 대응하는 spec/e2e 가 없을 때만 문제로 잡는다.
#
# 변경분 산정:
#   - 명시 목록: `CHECK_API_TESTS_FILES`(개행구분 파일목록) 지정 시 그 파일만 — 스코프 게이트가
#     동시 세션의 '내 작업파일'만 검사하도록 주입(남의 모듈 누락이 내 게이트를 막지 않음).
#   - 기본: `git status --porcelain`(추적 변경 + 미추적) — Stop 게이트(로컬 작업 트리)용.
#   - CI: `API_TESTS_DIFF_BASE=origin/main` 지정 시 `git diff --name-only <base>...HEAD` 사용.
#
# 실패 시 누락 목록을 stderr 로 출력하고 exit 1.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 0

# 1) 변경된 src/modules 파일 수집
if [ -n "${CHECK_API_TESTS_FILES:-}" ]; then
  # 명시 파일목록(절대 또는 repo-상대) → repo-상대화 후 src/modules 한정.
  CHANGED=$(printf '%s\n' "$CHECK_API_TESTS_FILES" | sed "s#^${ROOT}/##" | grep -E '^src/modules/' || true)
elif [ -n "${API_TESTS_DIFF_BASE:-}" ]; then
  CHANGED=$(git diff --name-only "${API_TESTS_DIFF_BASE}...HEAD" -- src/modules 2>/dev/null || true)
else
  CHANGED=$(git status --porcelain -- src/modules 2>/dev/null | awk '{ print $NF }' || true)
fi
[ -z "$CHANGED" ] && exit 0

# 2) 변경 파일 → 변경된 모듈 디렉터리 집합(src/modules/<feature>)
MOD_DIRS=$(printf '%s\n' "$CHANGED" | sed -nE 's#^(src/modules/[^/]+)/.*#\1#p' | sort -u)
[ -z "$MOD_DIRS" ] && exit 0

PROBLEMS=""

for dir in $MOD_DIRS; do
  [ -d "$dir" ] || continue

  # 모듈 안의 컨트롤러 파일(스펙 제외) — 하위 리소스 디렉터리 포함 재귀(예: users/profile/*.controller.ts).
  # 한 모듈에 컨트롤러가 여러 개일 수 있다(feature 단위).
  while IFS= read -r ctl; do
    [ -n "$ctl" ] || continue

    base=$(basename "$ctl" .controller.ts) # 예: users, auth, health
    cdir=$(dirname "$ctl")                 # spec 은 컨트롤러 자신의 디렉터리 기준

    # (a) 컨트롤러 단위 spec
    if [ ! -e "$cdir/$base.controller.spec.ts" ]; then
      PROBLEMS+="  - $ctl\n      → $base.controller.spec.ts 누락(컨트롤러 단위 테스트)\n"
    fi

    # (b) 서비스 단위 spec (대응 서비스 파일이 있을 때만)
    if [ -e "$cdir/$base.service.ts" ] && [ ! -e "$cdir/$base.service.spec.ts" ]; then
      PROBLEMS+="  - $cdir/$base.service.ts\n      → $base.service.spec.ts 누락(서비스 단위 테스트)\n"
    fi

    # (c) e2e: 컨트롤러 라우트 prefix 를 다루는 test/*.e2e-spec.ts 존재 확인
    #     (prefix 가 통합 e2e 파일(예: app.e2e-spec.ts)에 있어도 인정 — 파일명에 묶지 않음)
    prefix=$(grep -oE "@Controller\(['\"][^'\"]+['\"]" "$ctl" | head -n1 |
      sed -E "s/@Controller\(['\"]//; s/['\"].*//")
    if [ -n "$prefix" ]; then
      if ! grep -rqsE "/${prefix}([/'\"\`?]|$)" test/*.e2e-spec.ts 2>/dev/null; then
        PROBLEMS+="  - $ctl\n      → '/$prefix' 라우트를 다루는 e2e(test/*.e2e-spec.ts) 누락\n"
      fi
    elif [ ! -e "test/$base.e2e-spec.ts" ]; then
      PROBLEMS+="  - $ctl\n      → test/$base.e2e-spec.ts 누락(e2e)\n"
    fi
  done < <(find "$dir" -name '*.controller.ts' ! -name '*.controller.spec.ts' | sort)
done

if [ -n "$PROBLEMS" ]; then
  {
    printf 'API 테스트 3종 누락 — 변경분 한정(controller spec / service spec / e2e):\n'
    printf '%b' "$PROBLEMS"
    printf '정본: .claude/rules/testing.md "API 완성의 정의". '
    printf '엔티티 전용·미변경 모듈은 검사하지 않는다.\n'
  } >&2
  exit 1
fi
exit 0
