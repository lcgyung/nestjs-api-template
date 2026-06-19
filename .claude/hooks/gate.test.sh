#!/usr/bin/env bash
# gate.sh 케이스 테스트 — pnpm/toolchain 비의존 '조기 종료' 분기만 검증.
# (전체 파이프라인은 실제 toolchain 이 필요해 여기서 다루지 않는다 — 수동/E2E 로 확인.)
# 깨끗한 임시 git repo 안에서 실행해 'src|test 무변경' 분기를 결정적으로 만든다.
set -uo pipefail
GATE="$(cd "$(dirname "$0")" && pwd)/gate.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" config user.email t@t.t
git -C "$TMP" config user.name t
git -C "$TMP" commit -q --allow-empty -m init

FAILED=0
t() { # <label> <stdin-json> <env-assignment-or-empty> <expect-exit>
  local label=$1 json=$2 env=$3 expect=$4 rc
  ( cd "$TMP" && printf '%s' "$json" | env $env bash "$GATE" ) >/dev/null 2>&1
  rc=$?
  if [ "$rc" = "$expect" ]; then
    echo "PASS [$label] → exit $rc"
  else
    echo "FAIL [$label] → exit $rc (expect $expect)"
    FAILED=1
  fi
}

t "재귀가드 CC_GATE_SKIP" '{"permission_mode":"default"}' "CC_GATE_SKIP=1" 0
t "plan 모드 스킵"        '{"permission_mode":"plan"}'    ""               0
t "src|test 무변경 스킵"  '{"permission_mode":"default"}' ""               0
t "acceptEdits 무변경"    '{"permission_mode":"acceptEdits"}' ""           0

exit "$FAILED"
