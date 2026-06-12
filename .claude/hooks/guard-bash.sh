#!/usr/bin/env bash
# PreToolUse(Bash): 위험 명령 차단
set -euo pipefail
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
MODE=$(echo "$INPUT" | jq -r '.permission_mode // "default"')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

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

# 최근 사용자 프롬프트에 git/원격/배포 의도가 있는가? (있으면 0=true)
# 트랜스크립트의 last-prompt(.lastPrompt) 우선, 없으면 마지막 실제 사용자 발화(툴 결과·메타 제외).
# 판별 불가(빈 transcript·파싱 실패·빈 프롬프트)면 비-0 → 호출부에서 기본 차단.
user_intent_git_push() {
  local tp="$1" prompt
  [ -n "$tp" ] && [ -f "$tp" ] || return 1
  prompt=$(jq -rs '
    ([ .[] | select(.type=="last-prompt") | .lastPrompt ]) as $lp
    | if ($lp|length) > 0 then $lp[-1]
      else ([ .[] | select(.type=="user" and (.isMeta != true) and (has("toolUseResult")|not))
                  | (if (.message.content|type)=="string" then .message.content
                     else (.message.content|map(select(.type=="text").text)|join(" ")) end) ]
            | (if length>0 then .[-1] else "" end))
      end' "$tp" 2>/dev/null) || return 1
  [ -n "$prompt" ] || return 1
  echo "$prompt" | grep -qiE 'push|푸시|merge|머지|병합|release|릴리스|릴리즈|배포|deploy|tag|태그|버전[[:space:]]?업|pull[[:space:]]+request|dev.{0,4}(to|→|->).{0,6}main'
}

echo "$CMD" | grep -qE 'rm[[:space:]]+-[a-z]*r[a-z]*f?[[:space:]]+(/|~|\$HOME)' && deny "위험: 루트/홈 대상 rm -rf 차단"
echo "$CMD" | grep -qE 'git[[:space:]]+push.*(--force|-f)([[:space:]]|$)'      && deny "force push 차단 — 필요하면 사람이 직접 실행"
echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'                 && deny "git reset --hard 차단 — 변경 유실 위험"
# SQL 키워드는 관례상 대문자가 흔하므로 대소문자 무시(-i)로 매칭
echo "$CMD" | grep -qiE '(^|[^a-z])(drop[[:space:]]+(table|database)|truncate[[:space:]]+table)' && deny "DB 파괴 SQL 차단"

# 보상 통제(강): 사람 확인(permission prompt)이 빠지는 default/plan 외 모드에서만 추가 차단.
# push 는 최근 사용자 프롬프트에 git/배포 의도가 있으면 허용(자율 push 만 차단), 작업 트리 변경 유실은 차단.
# DB 스키마 변경(migration:run/revert·seed)은 기본 미차단(개발 DB 복구 가능) — 필요 시 여기 추가.
case "$MODE" in
default | plan) ;;
*)
  if echo "$CMD" | grep -qE 'git[[:space:]]+push([[:space:]]|$)'; then
    user_intent_git_push "$TRANSCRIPT" \
      || deny "auto 모드: 사용자 요청 없는 자율 push 차단 — 직접 요청했거나 default 모드에서 실행"
  fi
  echo "$CMD" | grep -qE 'git[[:space:]]+(clean[[:space:]]+-[a-z]*f|checkout[[:space:]]+--|restore([[:space:]]|$))' \
    && deny "auto 모드: 작업 트리 변경 유실 명령 차단"
  ;;
esac
exit 0
