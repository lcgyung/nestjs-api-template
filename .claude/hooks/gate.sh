#!/usr/bin/env bash
# Stop 게이트: 정적 검사(타입체크·린트·포맷) + 유닛 테스트 통과 후 변경분 자동 코드리뷰(review-gate.sh).
# 실패 시 exit 2 → Claude 가 계속 수정한다. e2e(DB 의존)는 게이트에서 제외한다.
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

# 포맷 검사: 미적용분도 종료 게이트로 차단(정리는 `pnpm format` / prettier --write).
if ! pnpm exec prettier --check "src/**/*.ts" "test/**/*.ts" >/tmp/cc_prettier.log 2>&1; then
  ERR+="[format 실패: prettier --write 로 정리]\n$(tail -n 40 /tmp/cc_prettier.log)\n\n"
fi

if [ -n "$ERR" ]; then
  printf "%b" "$ERR" >&2
  exit 2
fi

# 정적 검사 통과 → 유닛 테스트(jest, *.spec.ts). e2e(test/*.e2e-spec.ts, DB 의존)는 별도 config 라 제외됨.
# 프로젝트가 커져 게이트가 느려지면 `--onlyChanged` 또는 `--findRelatedTests <files>` 로 좁힐 수 있다.
if ! pnpm exec jest --passWithNoTests >/tmp/cc_jest.log 2>&1; then
  printf "%b" "[unit test 실패]\n$(tail -n 60 /tmp/cc_jest.log)\n" >&2
  exit 2
fi

# tsc/lint/format/test 통과 → 변경된 src/*.ts 의미적 규약 자동 리뷰. blocker 시 exit 2 전파.
printf '%s' "$INPUT" | "$DIR/review-gate.sh"
