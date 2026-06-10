#!/usr/bin/env bash
# Stop 게이트: 타입체크 + 린트 통과 후 변경분 자동 코드리뷰(review-gate.sh).
# 실패 시 exit 2 → Claude 가 계속 수정한다.
set -uo pipefail

# 중첩 claude -p(리뷰)가 이 게이트를 다시 트리거하는 재귀를 차단
[ -n "${CC_GATE_SKIP:-}" ] && exit 0

INPUT=$(cat 2>/dev/null || true) # Stop hook stdin(JSON) 캡처 → review-gate 로 전달
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERR=""

if ! pnpm exec tsc --noEmit -p tsconfig.json >/tmp/cc_tsc.log 2>&1; then
  ERR+="[typecheck 실패]\n$(tail -n 40 /tmp/cc_tsc.log)\n\n"
fi

if ! pnpm exec eslint "src/**/*.ts" >/tmp/cc_eslint.log 2>&1; then
  ERR+="[lint 실패]\n$(tail -n 40 /tmp/cc_eslint.log)\n\n"
fi

if [ -n "$ERR" ]; then
  printf "%b" "$ERR" >&2
  exit 2
fi

# tsc/lint 통과 → 변경된 src/*.ts 의미적 규약 자동 리뷰. blocker 시 exit 2 전파.
printf '%s' "$INPUT" | "$DIR/review-gate.sh"
