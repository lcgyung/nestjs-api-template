#!/usr/bin/env bash
# PreToolUse(Bash): 위험 명령 차단
set -euo pipefail
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
MODE=$(echo "$INPUT" | jq -r '.permission_mode // "default"')

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

echo "$CMD" | grep -qE 'rm[[:space:]]+-[a-z]*r[a-z]*f?[[:space:]]+(/|~|\$HOME)' && deny "위험: 루트/홈 대상 rm -rf 차단"
echo "$CMD" | grep -qE 'git[[:space:]]+push.*(--force|-f)([[:space:]]|$)'      && deny "force push 차단 — 필요하면 사람이 직접 실행"
echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'                 && deny "git reset --hard 차단 — 변경 유실 위험"
# SQL 키워드는 관례상 대문자가 흔하므로 대소문자 무시(-i)로 매칭
echo "$CMD" | grep -qiE '(^|[^a-z])(drop[[:space:]]+(table|database)|truncate[[:space:]]+table)' && deny "DB 파괴 SQL 차단"

# 보상 통제(강): 사람 확인(permission prompt)이 빠지는 default/plan 외 모드에서만 추가 차단.
# 무인 외부 반영·작업 트리 변경 유실 방지. DB 스키마 변경(migration:run/revert·seed)은 기본 미차단(개발 DB 복구 가능) — 필요 시 여기 추가.
case "$MODE" in
default | plan) ;;
*)
  echo "$CMD" | grep -qE 'git[[:space:]]+push([[:space:]]|$)' \
    && deny "auto 모드: 원격 push 는 사람이 직접 — 무인 외부 반영 차단"
  echo "$CMD" | grep -qE 'git[[:space:]]+(clean[[:space:]]+-[a-z]*f|checkout[[:space:]]+--|restore([[:space:]]|$))' \
    && deny "auto 모드: 작업 트리 변경 유실 명령 차단"
  ;;
esac
exit 0
