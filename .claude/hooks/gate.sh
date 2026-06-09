#!/usr/bin/env bash
# Stop: 타입체크 + 린트 게이트. 실패 시 exit 2 → Claude가 계속 수정
set -uo pipefail
ERR=""

if ! npx tsc --noEmit -p tsconfig.json >/tmp/cc_tsc.log 2>&1; then
  ERR+="[typecheck 실패]\n$(tail -n 40 /tmp/cc_tsc.log)\n\n"
fi

if ! npx eslint "src/**/*.ts" >/tmp/cc_eslint.log 2>&1; then
  ERR+="[lint 실패]\n$(tail -n 40 /tmp/cc_eslint.log)\n\n"
fi

# (선택) 빠른 테스트만 게이트에 포함하고 싶으면 주석 해제 — 느리면 제외
# if ! npx jest --bail --silent >/tmp/cc_jest.log 2>&1; then
#   ERR+="[test 실패]\n$(tail -n 40 /tmp/cc_jest.log)\n\n"
# fi

if [ -n "$ERR" ]; then
  printf "%b" "$ERR" >&2
  exit 2
fi
exit 0
