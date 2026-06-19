#!/usr/bin/env bash
# Stop 게이트: 정적 검사(타입체크·린트·포맷) + 유닛 테스트 통과 후 변경분 자동 코드리뷰(review-gate.sh).
# 단계별 fail-fast(첫 실패에서 exit 2 → Claude 가 계속 수정) + 단계별 타임아웃(행 방지). e2e(DB 의존)는 제외.
set -uo pipefail

# 중첩 claude -p(리뷰)가 이 게이트를 다시 트리거하는 재귀를 차단
[ -n "${CC_GATE_SKIP:-}" ] && exit 0

INPUT=$(cat 2>/dev/null || true) # Stop hook stdin(JSON) 캡처 → review-gate 로 전달
MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // "default"' 2>/dev/null || echo default)
# 보상 통제(약): plan 모드는 src 변경이 없으니 정적검사·테스트·리뷰를 스킵(효율).
[ "$MODE" = "plan" ] && exit 0

# 변경분-한정(효율): src/test 변경이 전혀 없으면 정적검사·테스트·리뷰가 모두 무의미하므로 스킵.
CHANGES=$(git status --porcelain -- src test 2>/dev/null || true)
[ -z "$CHANGES" ] && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 공용 헬퍼(run_with_timeout) — 단일 정본 .claude/hooks/lib.sh
. "$DIR/lib.sh"

# 로그는 세션별 임시 디렉터리로 격리(동시 세션의 /tmp 고정경로 경합 방지). 종료 시 정리.
LOGDIR=$(mktemp -d 2>/dev/null || echo "/tmp/cc_gate_$$")
mkdir -p "$LOGDIR"
trap 'rm -rf "$LOGDIR"' EXIT

fail() { # <title> <logfile> — 로그 끝부분을 그대로 stderr 로(이스케이프 가공 없이) 출력 후 종료
  echo "$1" >&2
  tail -n 60 "$2" >&2
  exit 2
}

# 단계별 fail-fast + 타임아웃. run_with_timeout 은 stdout+stderr 를 logfile 로 합쳐 캡처한다.
# 순서는 '흔히 깨지고 가벼운 것' 우선(tsc→lint→format→migration→api-tests→unit) — 첫 실패에서 즉시 종료.
step() { # <title> <timeout-secs> <logfile> <cmd...>
  local title=$1 to=$2 log=$3
  shift 3
  run_with_timeout "$to" "$log" "$@" || fail "$title" "$log"
}

# lint/format 범위는 package.json 정본 스크립트와 일치({src,test,scripts}) — 게이트만 src 로 좁아 생기던 누락 차단.
step "[typecheck 실패]"                          120 "$LOGDIR/tsc.log"      pnpm exec tsc --noEmit -p tsconfig.json
step "[lint 실패]"                               120 "$LOGDIR/eslint.log"   pnpm lint
step "[format 실패: prettier --write 로 정리]"     60 "$LOGDIR/prettier.log" pnpm exec prettier --check "{src,test,scripts}/**/*.ts"
# 마이그레이션 데이터 손실 가드(DB 불필요): up() 에 ack 없는 파괴적 DDL 이 있으면 차단.
step "[migration-safety 실패: up() 파괴적 DDL — ack 주석 필요]" 60 "$LOGDIR/migsafety.log" pnpm check:migrations
# API 테스트 3종 강제(변경분 한정): 작업 모듈 컨트롤러에 controller/service spec·e2e 누락 시 차단.
step "[API 테스트 3종 누락 — 변경분 한정]"          60 "$LOGDIR/apitests.log" pnpm check:api-tests
# 유닛 테스트(jest, *.spec.ts). e2e(test/*.e2e-spec.ts, DB 의존)는 별도 config 라 제외됨.
step "[unit test 실패]"                          300 "$LOGDIR/jest.log"     pnpm exec jest --passWithNoTests

# 정적검사·테스트 통과 → 변경된 src/*.ts 의미적 규약 자동 리뷰. blocker 시 exit 2 전파.
printf '%s' "$INPUT" | "$DIR/review-gate.sh"
