#!/usr/bin/env bash
# record-touched.sh 케이스 테스트 — 세션별 매니페스트 분리(CC_SCOPED_GATE)와 레거시 폴백 검증.
# 동시 세션이 한 매니페스트에 뒤섞이지 않는지(교차 오염 없음)를 결정적으로 확인한다.
set -uo pipefail
RT="$(cd "$(dirname "$0")" && pwd)/record-touched.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP [record-touched] jq 없음"; exit 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" config user.email t@t.t
git -C "$TMP" config user.name t

# record-touched 는 dirname 으로 cd 하므로 대상 파일이 실재해야 한다(경로 정규화 위해).
mkdir -p "$TMP/src"
printf 'x\n' >"$TMP/src/a.ts"
printf 'y\n' >"$TMP/src/b.ts"

FAILED=0
pass() { echo "PASS [$1]"; }
fail() {
  echo "FAIL [$1]"
  FAILED=1
}

# record-touched 실행 — stdin JSON 주입. cwd=repo. 상속된 CC_SCOPED_GATE 는 비워 결정적으로.
run_rt() { # <file-abs> <session-id> <scoped-or-empty>
  local file=$1 sid=$2 scoped=$3 env_s=""
  [ -n "$scoped" ] && env_s="CC_SCOPED_GATE=$scoped"
  printf '{"tool_input":{"file_path":"%s"},"session_id":"%s"}' "$file" "$sid" |
    (cd "$TMP" && env -u CC_SCOPED_GATE $env_s bash "$RT")
}

# record-touched 의 common_dir()·git_dir() 과 동일 값을 재현(심링크 정규화 차이 회피).
CDIR=$(cd "$TMP" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
LEGACY=$(cd "$TMP" && git rev-parse --absolute-git-dir 2>/dev/null)/cc_touched

# 1) 스코프 모드: 두 세션이 서로 다른 세션 디렉터리에 분리 기록
run_rt "$TMP/src/a.ts" "sessionA" "1"
run_rt "$TMP/src/b.ts" "sessionB" "1"
SA="$CDIR/cc_sessions/sessionA/touched"
SB="$CDIR/cc_sessions/sessionB/touched"
{ [ -f "$SA" ] && grep -qx 'src/a.ts' "$SA"; } &&
  pass "세션A 매니페스트 분리 기록" || fail "세션A 매니페스트 분리 기록"
{ [ -f "$SB" ] && grep -qx 'src/b.ts' "$SB"; } &&
  pass "세션B 매니페스트 분리 기록" || fail "세션B 매니페스트 분리 기록"
# 교차 오염 없음 — 세션A 에 세션B 파일이 섞이지 않는다(동시 세션 핵심 불변식)
grep -qx 'src/b.ts' "$SA" 2>/dev/null &&
  fail "세션 간 교차 오염 없음" || pass "세션 간 교차 오염 없음"
# heartbeat(활동 신호) 생성
[ -f "$CDIR/cc_sessions/sessionA/heartbeat" ] &&
  pass "heartbeat 생성" || fail "heartbeat 생성"

# 2) 레거시 폴백: CC_SCOPED_GATE 미설정 → 단일 cc_touched 파일
run_rt "$TMP/src/a.ts" "sessionA" ""
{ [ -f "$LEGACY" ] && grep -qx 'src/a.ts' "$LEGACY"; } &&
  pass "레거시 폴백 cc_touched 기록" || fail "레거시 폴백 cc_touched 기록"

exit "$FAILED"
