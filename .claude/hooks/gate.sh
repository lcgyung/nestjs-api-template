#!/usr/bin/env bash
# Stop 게이트: 정적 검사(타입체크·린트·포맷) + 유닛 테스트 통과 후 변경분 자동 코드리뷰(review-gate.sh).
# 단계별 fail-fast(첫 실패에서 exit 2 → Claude 가 계속 수정) + 단계별 타임아웃(행 방지). e2e 는 기본 제외(옵트인 CC_E2E_GATE).
set -uo pipefail

# 중첩 claude -p(리뷰)가 이 게이트를 다시 트리거하는 재귀를 차단
[ -n "${CC_GATE_SKIP:-}" ] && exit 0

INPUT=$(cat 2>/dev/null || true) # Stop hook stdin(JSON) 캡처 → review-gate 로 전달
MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // "default"' 2>/dev/null || echo default)
# 보상 통제(약): plan 모드는 src 변경이 없으니 정적검사·테스트·리뷰를 스킵(효율).
[ "$MODE" = "plan" ] && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 변경분-한정(효율): src/test 변경이 전혀 없으면 정적검사·테스트·리뷰가 모두 무의미하므로 건너뛴다.
# 단 docs/config 등 다른 변경은 있을 수 있으니 자동 커밋은 시도한다(auto-commit.sh 가 변경 0 이면 no-op).
CHANGES=$(git status --porcelain -- src test 2>/dev/null || true)
[ -z "$CHANGES" ] && exec "$DIR/auto-commit.sh"

# 공용 헬퍼(run_with_timeout·cc_sess_dir 등) — 단일 정본 .claude/hooks/lib.sh
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

# 변경분 스코프 게이트(CC_SCOPED_GATE): 동시 세션에서 '내 세션 작업파일'로 검사를 좁혀,
# 같은 워킹트리의 다른 세션 미완성 코드(린트·실패 스펙·타입오류)가 내 커밋을 막지 않게 한다.
# 미설정이면 현행 전체 검사(else)로 폴백 — 롤백 안전.
SCOPED=""
case "${CC_SCOPED_GATE:-}" in 1 | true | yes | on) SCOPED=1 ;; esac

# 커밋 체이닝(맨 아래)에서 참조하는 변수 — 폴백 경로의 set -u 안전을 위해 미리 초기화.
MY_TS_LINES=""
MY_ALL_LINES=""
SDIR=""

# typecheck 는 전체로 돌리되(정확성 유지) 에러 라인의 파일이 '내 작업 파일'일 때만 blocker 로 본다.
# tsc 비-TTY 출력은 "path(line,col): error TSxxxx: ..." 형식이고 path 는 repo 루트 상대다(단일 앱).
# 내 파일 0개 + 에러면 안전측=차단.
scoped_typecheck() { # <logfile> ; 전역 MY_TS[]·ROOT 사용
  local log=$1 f rel
  run_with_timeout 120 "$log" pnpm exec tsc --noEmit -p tsconfig.json && return 0 # 타입에러 0건 → 통과
  [ "${#MY_TS[@]}" -gt 0 ] || return 1                                            # 내 파일 없는데 에러 → 보수적 차단
  for f in "${MY_TS[@]}"; do
    rel="${f#"$ROOT/"}"
    # 'path(' 형태로 등장하는 error 라인이 있으면 내 파일 타입오류 → 차단.
    grep -E ': error TS' "$log" | grep -qF "$rel(" && return 1
  done
  return 0 # 에러는 전부 다른(남의) 파일 → 강등(통과)
}

if [ -n "$SCOPED" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
  SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
  SDIR=$(cc_sess_dir "$SID")
  # 내 작업 파일 수집 — 두 목록을 분리한다:
  #   MY_TS  = 검사용 .ts(존재하는 것만, 절대경로). lint/prettier/jest/tsc-필터 대상.
  #   MY_ALL = 커밋용 전체(repo-상대, 삭제 파일도 포함). 검사는 .ts 만 보지만 커밋 스테이징은
  #            .ts 가 아닌 변경(문서·설정·스크립트)도 빠짐없이 담아야 하므로 분리한다.
  MY_TS=()
  MY_ALL=()
  if [ -s "$SDIR/touched" ]; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      MY_ALL+=("$rel")
      case "$rel" in *.ts) ;; *) continue ;; esac
      [ -f "$ROOT/$rel" ] && MY_TS+=("$ROOT/$rel")
    done < <(sort -u "$SDIR/touched")
  fi
  MY_N=${#MY_TS[@]}
  [ "$MY_N" -gt 0 ] && MY_TS_LINES=$(printf '%s\n' "${MY_TS[@]}")
  [ "${#MY_ALL[@]}" -gt 0 ] && MY_ALL_LINES=$(printf '%s\n' "${MY_ALL[@]}")

  # typecheck — 전체 + 내-파일-에러만 blocker.
  scoped_typecheck "$LOGDIR/tsc.log" || fail "[typecheck 실패: 내 작업 파일 타입오류]" "$LOGDIR/tsc.log"
  # lint/format — 내 작업 .ts 한정(없으면 정적 검사 스킵).
  if [ "$MY_N" -gt 0 ]; then
    step "[lint 실패]"   120 "$LOGDIR/eslint.log"   pnpm exec eslint "${MY_TS[@]}"
    step "[format 실패: prettier --write 로 정리]" 60 "$LOGDIR/prettier.log" pnpm exec prettier --check "${MY_TS[@]}"
  fi
  # 마이그레이션 데이터 손실 가드 — 안전·희소이므로 전체 유지.
  step "[migration-safety 실패: up() 파괴적 DDL — ack 주석 필요]" 60 "$LOGDIR/migsafety.log" pnpm check:migrations
  # API 테스트 3종 — 내 작업 파일 한정 주입(남의 모듈 누락이 내 게이트를 막지 않음).
  export CHECK_API_TESTS_FILES="$MY_TS_LINES"
  step "[API 테스트 3종 누락 — 변경분 한정]" 60 "$LOGDIR/apitests.log" pnpm check:api-tests
  unset CHECK_API_TESTS_FILES
  # 유닛 테스트 — 내 작업 .ts 관련 스펙만(findRelatedTests). 관련 스펙 없으면 통과.
  if [ "$MY_N" -gt 0 ]; then
    step "[unit test 실패]" 300 "$LOGDIR/jest.log" \
      pnpm exec jest --findRelatedTests "${MY_TS[@]}" --passWithNoTests
  fi
else
  # 전체 검사(폴백) — 현행 동작. 순서는 '흔히 깨지고 가벼운 것' 우선.
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
fi

# e2e 게이트(옵트인): CC_E2E_GATE 가 켜진 경우에만 실행. Docker 데몬에 못 붙으면 경고 후 스킵(fail-open) —
# 코드로 못 고치는 환경 문제로 Stop 을 막지 않는다. 켠 상태에서 실제 e2e 실패는 차단(exit 2).
case "${CC_E2E_GATE:-0}" in
  1 | true | yes | on)
    if docker info >/dev/null 2>&1; then
      step "[e2e 실패]" 600 "$LOGDIR/e2e.log" pnpm test:e2e
    else
      echo "[e2e 스킵] Docker 데몬에 연결할 수 없어 e2e 를 건너뜁니다(CC_E2E_GATE 설정됨, fail-open)." >&2
    fi
    ;;
esac

# 정적검사·테스트 통과 → 변경된 src/*.ts 의미적 규약 자동 리뷰. blocker 시 exit 2(커밋 안 함), 통과 시 자동 커밋.
if printf '%s' "$INPUT" | "$DIR/review-gate.sh"; then
  # 게이트 전부 통과 → 작업 내용 자동 커밋(옵트인 CC_AUTO_COMMIT, push 안 함).
  # 스코프 모드면 세션 작업파일 목록(CC_COMMIT_FILES)·세션 디렉터리(CC_SESSION_DIR)를 넘겨
  # 그 파일만 스테이징하고 커밋 후 세션 매니페스트를 소비한다.
  if [ -n "$SCOPED" ]; then
    CC_COMMIT_FILES="$MY_ALL_LINES" CC_SESSION_DIR="$SDIR" "$DIR/auto-commit.sh"
  else
    "$DIR/auto-commit.sh"
  fi
else
  exit 2
fi
