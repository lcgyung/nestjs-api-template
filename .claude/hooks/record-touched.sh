#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): 이 세션이 편집한 파일 경로를 "작업 컨텍스트" 매니페스트(.git/cc_touched)에 기록.
# auto-commit.sh 가 이 목록만 스테이징해 현재 작업 컨텍스트만 커밋한다(워킹트리 전체 무차별 sweep 방지).
# 비차단(graceful degrade): jq/git 없으면 조용히 통과. repo 밖 파일은 무시.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$FILE" ] || exit 0
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib.sh"

GITDIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
ROOT_P=$(cd "$ROOT" 2>/dev/null && pwd -P) || exit 0

# 파일을 물리 절대경로로 정규화(심링크·상대경로 해소; macOS /var→/private/var 불일치 방지) 후
# repo 루트 기준 상대경로로 변환해 기록. repo 밖 파일은 무시(공백 경로 안전).
d=$(dirname -- "$FILE")
b=$(basename -- "$FILE")
dp=$(cd "$d" 2>/dev/null && pwd -P) || exit 0
abs="$dp/$b"
case "$abs" in
  "$ROOT_P"/*) REL="${abs#"$ROOT_P"/}" ;;
  *) exit 0 ;;
esac

# 세션 분리(CC_SCOPED_GATE): 동시 세션이 한 매니페스트에 뒤섞이지 않도록 세션별 디렉터리에 기록.
# heartbeat 의 mtime 으로 '마지막 활동'을 남긴다(Phase 2 활성 판정 선반영, 무해).
# 미설정이거나 디렉터리 생성 실패 시 레거시 단일 파일($GITDIR/cc_touched)로 폴백(현행 동작 보존).
case "${CC_SCOPED_GATE:-}" in
  1 | true | yes | on)
    SDIR=$(cc_sess_dir "$SID")
    if mkdir -p "$SDIR" 2>/dev/null; then
      printf '%s\n' "$REL" >>"$SDIR/touched"
      : >"$SDIR/heartbeat"
      exit 0
    fi
    ;;
esac

printf '%s\n' "$REL" >>"$GITDIR/cc_touched"
exit 0
