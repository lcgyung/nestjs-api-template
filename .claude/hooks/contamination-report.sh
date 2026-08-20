#!/usr/bin/env bash
# SessionStart: knip 으로 dead code/unused export 를 탐지해 "오염 맵" 요약을 컨텍스트로 주입한다(Pattern Contamination 인지).
# 정책: 탐지·인지 전용 — 삭제/커밋은 하지 않는다. 정리는 .claude/rules/pattern-contamination.md 가 에이전트를 유도한다.
# 안전: 옵트인(CC_CONTAMINATION_REPORT) · 타임아웃 · 캐시(lockfile/package.json mtime) · 실패 시 비차단(graceful degrade).
set -uo pipefail

# 옵트인 아니면 조용히 통과(settings.json env 의 CC_CONTAMINATION_REPORT=1 로 활성)
[ -z "${CC_CONTAMINATION_REPORT:-}" ] && exit 0
# 중첩 claude -p(리뷰 게이트 등)가 세션을 다시 트리거하는 재귀 방지
[ -n "${CC_GATE_SKIP:-}" ] && exit 0
# knip 미설치(clean checkout/CI 등) → 비차단
pnpm exec knip --version >/dev/null 2>&1 || exit 0

# 공용 헬퍼(run_with_timeout 등) — 단일 정본 .claude/hooks/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

CACHE="$(git_dir)/cc_knip_cache" # worktree 안전(lib.sh git_dir) — ".git/" 하드코딩 금지

# 캐시 신선도: 캐시가 lockfile·package.json 보다 최신이면 재사용(매 세션 knip 재실행 회피)
if [ -f "$CACHE" ] && [ "$CACHE" -nt "pnpm-lock.yaml" ] && [ "$CACHE" -nt "package.json" ]; then
  emit_session_context "$(cat "$CACHE" 2>/dev/null || echo '')"
  exit 0
fi

OUT_F=$(mk_tmp cc_knip)
# dependencies 분석은 test/scripts 전체 커버가 필요해 오탐이 많으므로 files,exports 만(룰과 동일 스코프)
run_with_timeout 60 "$OUT_F" env CC_GATE_SKIP=1 pnpm exec knip --include files,exports --no-progress --reporter compact
RAW=$(head -n 40 "$OUT_F" 2>/dev/null || true)
rm -f "$OUT_F"

if [ -z "$RAW" ]; then
  # 오염 0 또는 인프라 실패 — 둘 다 비차단. 캐시에 '없음' 기록.
  printf 'Pattern Contamination(knip): 탐지된 dead code/unused export 없음(또는 분석 생략).' >"$CACHE" 2>/dev/null || true
  emit_session_context "$(cat "$CACHE" 2>/dev/null || echo '')"
  exit 0
fi

SUMMARY="Pattern Contamination 후보(knip — files,exports). 정책 정본: .claude/rules/pattern-contamination.md
$RAW

주의: 위는 '후보'다. NestJS DI(provider/controller/guard/decorator)·*.module.ts·migrations/seeds 는 정적 unused 여도 삭제 금지 — 참조 경로 확인 후 판단.
정리는 현재 작업 범위 내에서만, 기능 변경과 분리해 chore(cleanup): 단독 커밋. 전체 일괄 정리는 /contamination-sweep 로."

printf '%s' "$SUMMARY" >"$CACHE" 2>/dev/null || true
emit_session_context "$SUMMARY"
exit 0
