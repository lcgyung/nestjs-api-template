#!/usr/bin/env bash
# Stop(2차 게이트): 변경된 src/*.ts 의 "의미적 규약" 자동 리뷰 — 기본 OFF, 옵트인.
#   켜기: CC_AUTO_REVIEW=1  (예: .claude/settings.json 의 env, 또는 셸 export)
# - 변경 없음 / claude 미설치 / 타임아웃 → 막지 않음(exit 0, graceful degrade).
# - 규약 위반 blocker → exit 2 로 계속 수정 유도. 연속 라운드 상한(MAX_ROUNDS).
# - 타임아웃은 순수 bash 래퍼(timeout 바이너리 불요, bash 3.2 호환).
# - 규약 정본 docs/api-conventions.md 전문을 런타임 주입한다(동기화 지점 없음).
set -uo pipefail

[ -n "${CC_GATE_SKIP:-}" ] && exit 0 # 중첩 리뷰(claude -p)가 게이트를 재트리거하는 재귀 방지(최우선)

# 공용 헬퍼(run_with_timeout 등) — 단일 정본 .claude/hooks/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

INPUT=$(cat 2>/dev/null || true) # Stop stdin(JSON) — 모드 분기에 사용
MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // "default"' 2>/dev/null || echo default)

# 보상 통제(강): default/plan 외(사람 확인 없는 편집 모드)는 CC_AUTO_REVIEW 옵트인과 무관하게 리뷰 강제.
case "$MODE" in default | plan) FORCE="" ;; *) FORCE=1 ;; esac
[ -z "$FORCE" ] && [ -z "${CC_AUTO_REVIEW:-}" ] && exit 0 # default 모드는 기존 옵트인 유지

ROUND_FILE=".git/cc_review_round"
MAX_ROUNDS=$([ -n "$FORCE" ] && echo 2 || echo 1) # default 는 1회만 재수정 요구(오탐 마찰 최소화), 강한 통제(auto)는 +1
REVIEW_TIMEOUT=150
REVIEW_MODEL=haiku

# 1) 변경된 src TypeScript 존재 확인(추적 변경 + 미추적 신규). 없으면 통과 + 카운터 리셋.
#    NUL 구분으로 공백·리네임 안전. 추적 변경은 git diff HEAD, 미추적 신규는 git ls-files --others 가 커버.
TRACKED_TS=$(git diff HEAD --name-only -z -- src 2>/dev/null | tr '\0' '\n' | grep -E '\.ts$' || true)
UNTRACKED_TS=$(git ls-files --others --exclude-standard -z -- src 2>/dev/null | tr '\0' '\n' | grep -E '\.ts$' || true)
if [ -z "$TRACKED_TS" ] && [ -z "$UNTRACKED_TS" ]; then
  rm -f "$ROUND_FILE"
  exit 0
fi

# 2) 루프 가드: 연속 blocking 라운드 상한
ROUND=0
[ -f "$ROUND_FILE" ] && ROUND=$(cat "$ROUND_FILE" 2>/dev/null || echo 0)
if [ "${ROUND:-0}" -ge "$MAX_ROUNDS" ]; then
  echo "[review-gate] 리뷰 라운드 상한($MAX_ROUNDS) 도달 — 경고만 남기고 통과(나머지는 수동 검토)." >&2
  rm -f "$ROUND_FILE"
  exit 0
fi

# 3) claude CLI 없으면(예: CI) 리뷰 생략 — 게이트 막지 않음
command -v claude >/dev/null 2>&1 || exit 0

# 4) 변경 diff(상한) 수집 — 추적 변경 diff + 미추적 신규 파일 본문. 예산을 넉넉히(부분 입력 오탐 BLOCK 방지).
FULLDIFF=$(git diff HEAD -- src 2>/dev/null)
DIFF=$(printf '%s' "$FULLDIFF" | head -n 2000)
DIFF_LINES=$(printf '%s\n' "$FULLDIFF" | wc -l | tr -d '[:space:]')
[ "${DIFF_LINES:-0}" -gt 2000 ] \
  && DIFF+=$'\n\n[알림: diff 가 2000행에서 잘렸다 — 보이는 범위만 판단하고 잘린 부분은 추측하지 말 것(모호하면 PASS).]'
# 미추적 신규 파일(추적 변경은 위 diff 가 커버). NUL→줄 변환 후 줄 단위 read 라 공백 경로 안전.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  DIFF+=$'\n\n--- new file: '"$f"$' ---\n'"$(head -n 400 "$f" 2>/dev/null)"
done <<<"$UNTRACKED_TS"
[ -z "$DIFF" ] && exit 0

# 5) 규약 정본 전문을 런타임 주입(동기화 지점 없음, 절단 금지). 정본을 못 읽으면 막지 않음(graceful degrade).
CONV=$(cat "${CLAUDE_PROJECT_DIR:-.}/docs/api-conventions.md" 2>/dev/null)
[ -z "$CONV" ] && exit 0
PROMPT="너는 이 NestJS 템플릿의 코드 리뷰어다. 아래 '규약'(정본 전문)을 기준으로만 변경분(diff)을 검토하라.
**명백하고 명확한 규약 위반만** blocker 로 보고하라. 규약에 명시되지 않은 사항·스타일·추측성 지적·warning/nit 은
보고하지 말고, 판단이 모호하면 PASS 로 둔다(오탐보다 누락을 택한다). blocker 가 없으면 마지막 줄에 정확히 \"VERDICT: PASS\",
하나 이상이면 \"- 파일: 사유(수정안)\" 으로 나열 후 마지막 줄에 정확히 \"VERDICT: BLOCK\".
=== 규약 (docs/api-conventions.md) ===
$CONV
=== diff ===
$DIFF"

# 6) 헤드리스 리뷰(재귀 방지 sentinel + 경량 모델). run_with_timeout 은 lib.sh. 타임아웃/실패 → 빈 출력 → 비차단.
OUT_F=$(mktemp 2>/dev/null || echo "/tmp/cc_review_$$")
run_with_timeout "$REVIEW_TIMEOUT" "$OUT_F" env CC_GATE_SKIP=1 claude -p "$PROMPT" --model "$REVIEW_MODEL"
OUT=$(cat "$OUT_F" 2>/dev/null || true)
rm -f "$OUT_F"
[ -z "$OUT" ] && exit 0 # 인프라 실패/타임아웃 → 막지 않음

if printf '%s' "$OUT" | grep -qE '^[[:space:]]*VERDICT: BLOCK[[:space:]]*$'; then
  echo "$((ROUND + 1))" >"$ROUND_FILE"
  {
    echo "[review-gate] 규약 위반(blocker) 발견 — 수정 후 다시 종료하세요:"
    printf '%s\n' "$OUT" | grep -v 'VERDICT:'
  } >&2
  exit 2
fi

rm -f "$ROUND_FILE"
exit 0
