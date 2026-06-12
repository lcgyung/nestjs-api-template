#!/usr/bin/env bash
# Stop(2차 게이트): 변경된 src/*.ts 의 "의미적 규약" 자동 리뷰 — 기본 OFF, 옵트인.
#   켜기: CC_AUTO_REVIEW=1  (예: .claude/settings.json 의 env, 또는 셸 export)
# - 변경 없음 / claude 미설치 / 타임아웃 → 막지 않음(exit 0, graceful degrade).
# - 규약 위반 blocker → exit 2 로 계속 수정 유도. 연속 라운드 상한(MAX_ROUNDS).
# - 타임아웃은 순수 bash 래퍼(timeout 바이너리 불요, bash 3.2 호환).
# - 규약 정본은 .claude/skills/api-endpoint/SKILL.md. 여기엔 haiku 1-shot 용 "요지"만 인라인한다.
set -uo pipefail

[ -z "${CC_AUTO_REVIEW:-}" ] && exit 0 # 기본 off — 옵트인일 때만 동작
[ -n "${CC_GATE_SKIP:-}" ] && exit 0    # 중첩 리뷰(claude -p)가 게이트를 재트리거하는 재귀 방지

cat >/dev/null 2>&1 || true # stdin(JSON) 소비(현재 미사용)

ROUND_FILE=".git/cc_review_round"
MAX_ROUNDS=2
REVIEW_TIMEOUT=150
REVIEW_MODEL=haiku

# 1) 변경된 src TypeScript(추적 변경 + 미추적). 없으면 통과 + 카운터 리셋.
CHANGED=$(git status --porcelain -- src 2>/dev/null | awk '{print $NF}' | grep -E '\.ts$' || true)
if [ -z "$CHANGED" ]; then
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

# 4) 변경 diff(상한) 수집 — 추적 변경 + 미추적 신규 파일
DIFF=$(git diff HEAD -- src 2>/dev/null | head -n 600)
for f in $CHANGED; do
  if ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    DIFF+=$'\n\n--- new file: '"$f"$' ---\n'"$(head -n 200 "$f" 2>/dev/null)"
  fi
done
[ -z "$DIFF" ] && exit 0

# 5) 규약 요지 인라인 프롬프트(정본: .claude/skills/api-endpoint/SKILL.md)
read -r -d '' PROMPT <<'EOF' || true
너는 이 NestJS 템플릿의 코드 리뷰어다. 아래 변경분(diff)을 이 프로젝트 규약 기준으로만 검토하라.
규약 요지: 목록 응답=PaginatedResponseDto({items,meta}) — bare 배열/{data}/{results} 금지;
단건/생성/수정=엔티티 직접 반환(@Exclude+ClassSerializerInterceptor, 수동 DTO 매핑 금지);
예외=빌트인 HttpException 매핑(404/409/401/403/422)·한국어 메시지·내부 비노출;
컨트롤러 thin(로직은 서비스); 입력=DTO+class-validator, 수정 DTO=PartialType;
정렬/필터=화이트리스트; 관계 명시적(eager 금지); any 금지; 민감 컬럼 @Exclude.
규약을 위반한 blocker 만 보고하라(warning/nit 무시). blocker 가 없으면 마지막 줄에 정확히 "VERDICT: PASS",
하나 이상이면 "- 파일: 사유(수정안)" 으로 나열 후 마지막 줄에 정확히 "VERDICT: BLOCK".
=== diff ===
EOF
PROMPT+=$'\n'"$DIFF"

# 6) 순수 bash 타임아웃 래퍼(바이너리 불요). 명령 stdout 은 파일로 캡처.
run_with_timeout() { # <secs> <outfile> <cmd...>
  local secs=$1 out=$2
  shift 2
  "$@" >"$out" 2>/dev/null &
  local pid=$!
  (
    sleep "$secs"
    kill -TERM "$pid" 2>/dev/null
    sleep 2
    kill -KILL "$pid" 2>/dev/null
  ) &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill -TERM "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  return $rc
}

# 7) 헤드리스 리뷰(재귀 방지 sentinel + 경량 모델). 타임아웃/실패 → 빈 출력 → 비차단.
OUT_F=$(mktemp 2>/dev/null || echo "/tmp/cc_review_$$")
run_with_timeout "$REVIEW_TIMEOUT" "$OUT_F" env CC_GATE_SKIP=1 claude -p "$PROMPT" --model "$REVIEW_MODEL"
OUT=$(cat "$OUT_F" 2>/dev/null || true)
rm -f "$OUT_F"
[ -z "$OUT" ] && exit 0 # 인프라 실패/타임아웃 → 막지 않음

if printf '%s' "$OUT" | grep -q 'VERDICT: BLOCK'; then
  echo "$((ROUND + 1))" >"$ROUND_FILE"
  {
    echo "[review-gate] 규약 위반(blocker) 발견 — 수정 후 다시 종료하세요:"
    printf '%s\n' "$OUT" | grep -v 'VERDICT:'
  } >&2
  exit 2
fi

rm -f "$ROUND_FILE"
exit 0
