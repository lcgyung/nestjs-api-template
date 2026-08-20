#!/usr/bin/env bash
# Stop(3차 게이트): 정적검사·테스트·리뷰를 모두 통과한 뒤 작업 내용을 자동 커밋한다.
#   끄기: CC_AUTO_COMMIT=0  (기본 ON — .claude/settings.json 의 env 에 "1" 로 명시)
# - gate.sh 가 전부 통과한 경우에만 호출된다(별도 Stop 훅이 아니라 gate.sh 내부 체이닝). broken 코드 커밋 방지.
# - main 브랜치·detached HEAD·변경 없음 → no-op(exit 0). 변경 없음 no-op 이 루프 차단의 핵심.
# - 메시지: 헤드리스 claude(haiku)가 staged diff 로 Conventional Commits 1줄 생성, 실패/형식불일치 시 고정 템플릿 폴백.
# - push 는 하지 않는다(자율 push 금지 정책 — guard-bash.sh). 어떤 실패도 Stop 을 막지 않는다(graceful degrade, exit 0).
set -uo pipefail

# 중첩 claude -p(메시지 생성)가 이 훅/게이트를 다시 트리거하는 재귀 차단(최우선)
[ -n "${CC_GATE_SKIP:-}" ] && exit 0

# 끄기 스위치(기본 ON): 0/false/off/no 일 때만 비활성
case "${CC_AUTO_COMMIT:-1}" in
  0 | false | off | no) exit 0 ;;
esac

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 공용 헬퍼(run_with_timeout) — 단일 정본 .claude/hooks/lib.sh
. "$DIR/lib.sh"

# 보호 브랜치/비정상 상태 스킵 — main 만 제외, detached HEAD·비-git 도 스킵(나머지 전부 허용)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
case "$BRANCH" in
  main | HEAD | "") exit 0 ;;
esac

# repo 루트로 이동(경로 정규화) — 호출 cwd 와 무관하게 안전.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) && cd "$ROOT"

# 변경 없으면 no-op (커밋 후 트리 청결 → 다음 Stop 은 여기서 종료 = 루프 차단)
[ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0

# 스테이징 범위 = "현재 작업 컨텍스트"만 — 워킹트리 전체를 무차별 sweep 하지 않는다(세션과 무관한
# 기존 변경 혼입 방지). 우선순위:
#   1) CC_COMMIT_FILES(env, 개행구분) — gate.sh(스코프 게이트)가 주입하는 세션 작업파일 목록.
#   2) 레거시 .git/cc_touched 매니페스트(record-touched.sh, CC_SCOPED_GATE 미설정 경로).
#   3) 둘 다 없으면 승인된 기본대로 워킹트리 전체(예: Bash 로만 변경·기록 없음).
# 매니페스트는 커밋 성공 후 소비(삭제).
TOUCHED="$(git rev-parse --absolute-git-dir 2>/dev/null)/cc_touched"
if [ -n "${CC_COMMIT_FILES:-}" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    git add -A -- "$p" 2>/dev/null || true # 수정·신규·삭제 모두 반영
  done <<<"$CC_COMMIT_FILES"
elif [ -s "$TOUCHED" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    git add -A -- "$p" 2>/dev/null || true # 수정·신규·삭제 모두 반영
  done < <(sort -u "$TOUCHED")
else
  git add -A 2>/dev/null || exit 0
fi
# 스테이징 결과가 비면(컨텍스트 파일이 실제로는 무변경) 종료 — 무관한 dirty 파일은 건드리지 않는다.
[ -z "$(git diff --cached --name-only 2>/dev/null)" ] && exit 0

# OpenAPI 스펙 동기화(AI 경로) — gate.sh 는 openapi 를 안 보므로 여기서 재생성+스테이징해 커밋에 동봉한다
# (사람 경로는 pre-commit 이 drift 검사로 강제). src 변경이 스테이징에 있을 때만 돌려 불필요한
# ts-node 부팅을 피한다. 실패해도 비차단(graceful) — 드리프트는 CI 가 최종 차단.
if git diff --cached --name-only 2>/dev/null | grep -q '^src/'; then
  pnpm openapi:generate >/dev/null 2>&1 || true
  git add docs/openapi.json 2>/dev/null || true
fi

# --- 커밋 메시지 생성 ---
N=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d '[:space:]')
MSG="chore: 자동 커밋 — ${N}개 파일 변경" # 폴백(commitlint 통과 형식)

if command -v claude >/dev/null 2>&1; then
  DIFF=$(git diff --cached 2>/dev/null | head -n 1500)
  if [ -n "$DIFF" ]; then
    PROMPT="다음 git staged diff 를 한 줄 Conventional Commits 메시지로 요약하라.
형식: <type>(<scope>): <subject> — type 은 feat|fix|chore|docs|refactor|test|ci|style|perf 중 하나, scope 는 선택(소문자/숫자/하이픈).
규칙: 정확히 한 줄만 출력. 마침표·따옴표·백틱·코드펜스 금지. 72자 이내. 한국어 subject 허용.
=== diff ===
$DIFF"
    OUT_F=$(mk_tmp cc_commit)
    # 재귀 방지 sentinel + 경량 모델(run_headless_claude=lib.sh). 타임아웃/실패 → 빈 출력 → 폴백 유지(비차단).
    run_headless_claude 60 "$OUT_F" "$PROMPT"
    # head -n 1 금지: claude CLI 의 stdin 경고("no stdin data received...")나 haiku 가 종종 두르는
    # 코드펜스(```)가 첫 줄을 차지해 정규식에 실패하면 매번 폴백으로 떨어진다. 대신 Conventional Commits
    # 형식에 맞는 첫 줄을 grep 으로 추출(grep -m1 이 형식 검증 겸함 — 경고·펜스·preamble 을 건너뜀).
    CAND=$(grep -m1 -E '^[[:space:]]*(feat|fix|chore|docs|refactor|test|ci|style|perf)(\([a-z0-9-]+\))?: .+' "$OUT_F" 2>/dev/null \
      | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    rm -f "$OUT_F"
    [ -n "$CAND" ] && MSG="$CAND" # 매칭 줄을 못 찾으면 폴백 유지(비차단).
  fi
fi

# Co-Authored-By 트레일러(추적성). 빈 줄 뒤 footer — commitlint 와 충돌 없음.
COMMIT_MSG="$MSG

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"

# 비대화식 커밋. pre-commit(lint-staged/gitleaks)·commit-msg(commitlint) 실패 시 막지 말고 경고만(graceful degrade).
# gate.sh 가 이미 엄격 세트를 통과시켰으므로 pre-commit 의 엄격 블록은 센티넬로 중복 회피(AI 루프 2배 지연 방지).
ERR_F=$(mk_tmp cc_commit_err)
if CC_SKIP_PRECOMMIT_STRICT=1 git commit -q -m "$COMMIT_MSG" 2>"$ERR_F"; then
  # 커밋된 작업 컨텍스트 소비 — 다음 사이클은 이후 편집만 대상.
  rm -f "$TOUCHED" # 레거시 매니페스트
  [ -n "${CC_SESSION_DIR:-}" ] && rm -f "$CC_SESSION_DIR/touched" 2>/dev/null # 세션 매니페스트
  echo "[auto-commit] 커밋 완료: $MSG" >&2
else
  {
    echo "[auto-commit] 커밋 실패(pre-commit/commitlint 등) — 수동 확인 필요:"
    cat "$ERR_F" 2>/dev/null || true
  } >&2
fi
rm -f "$ERR_F"
exit 0
