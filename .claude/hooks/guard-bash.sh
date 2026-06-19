#!/usr/bin/env bash
# PreToolUse(Bash): 위험 명령 차단.
# fail-closed: 내부 오류(jq 부재·stdin 파싱 실패 등)에는 '통과'가 아니라 '차단'으로 떨어진다.
#   (PreToolUse 훅이 exit 2 가 아닌 비정상 종료를 하면 명령이 그대로 실행되므로 — fail-open 방지.)
set -euo pipefail

# 공용 헬퍼(pretooluse_deny_raw 등) — 단일 정본 .claude/hooks/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
# 예기치 못한 오류는 항상 차단으로(jq 없이 동작하는 raw deny).
trap 'pretooluse_deny_raw "guard-bash 내부 오류 — 안전을 위해 차단(fail-closed)"; exit 0' ERR

INPUT=$(cat)
# fail-closed: stdin 이 비었거나 JSON 객체가 아니면(빈/공백/깨진 입력·jq 부재 포함) 통과시키지 않고 차단.
printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1 \
  || { pretooluse_deny_raw "guard-bash: stdin 이 JSON 객체가 아님 — 안전을 위해 차단(fail-closed)"; exit 0; }
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // "default"')
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')

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

# git 서브커맨드 앞에 끼는 전역 옵션을 허용하는 prefix 정규식(우회 차단).
#   예) `git -c user.email=x push --force`, `git -C /repo reset --hard`, `git --no-pager push`
#   -c <kv> · -C <path> · 단문자 플래그(-p 등) · --long[=val] 을 0개 이상 흡수한 뒤 서브커맨드에 도달.
GITX='git([[:space:]]+(-c[[:space:]]+[^[:space:]]+|-C[[:space:]]+[^[:space:]]+|-[A-Za-z]|--[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?))*[[:space:]]+'

# 최근 사용자 프롬프트에 git/원격/배포 의도가 있는가? (있으면 0=true)
# 트랜스크립트의 last-prompt(.lastPrompt) 우선, 없으면 마지막 실제 사용자 발화(툴 결과·메타 제외).
# 판별 불가(빈 transcript·파싱 실패·빈 프롬프트)·부정문이면 비-0 → 호출부에서 기본 차단(false-deny 는 안전).
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
  # 의도 키워드가 없으면 no-intent
  printf '%s' "$prompt" | grep -qiE 'push|푸시|merge|머지|병합|release|릴리스|릴리즈|배포|deploy|tag|태그|버전[[:space:]]?업|pull[[:space:]]+request|dev.{0,4}(to|→|->).{0,6}main' || return 1
  # 부정문(자율 push 금지 의사)이면 no-intent 로 본다 — 막아도 사용자가 직접 실행하면 되므로 안전
  printf '%s' "$prompt" | grep -qiE "하지[[:space:]]?마|하지[[:space:]]?말|말고|아직|나중|금지|취소|don'?t|do not|hold off" && return 1
  return 0
}

# 따옴표 '문자'만 제거(내용 유지) — rm -rf "/" 처럼 따옴표로 가린 대상을 드러낸다.
SCAN=${CMD//\"/}
SCAN=${SCAN//\'/}

# rm 재귀 삭제(루트/홈): 단문자(-rf/-fr)·장문자(--recursive --force)·분리 플래그·따옴표 우회 포함.
# 'rm' + (플래그 토큰)* + 재귀플래그(-..r.. | --recursive) + (플래그 토큰)* + 루트/홈 대상.
printf '%s' "$SCAN" | grep -qE '(^|[^[:alnum:]_./-])rm[[:space:]]+(-[A-Za-z]+[[:space:]]+|--[a-z-]+[[:space:]]+)*(-[A-Za-z]*r[A-Za-z]*|--recursive)([[:space:]]+(-[A-Za-z]+|--[a-z-]+))*[[:space:]]+(/|~|\$HOME)' \
  && deny "위험: 루트/홈 대상 rm -rf 차단"

printf '%s' "$CMD" | grep -qE "${GITX}"'push.*(--force|-f)([[:space:]]|$)' && deny "force push 차단 — 필요하면 사람이 직접 실행"
printf '%s' "$CMD" | grep -qE "${GITX}"'reset[[:space:]]+--hard'           && deny "git reset --hard 차단 — 변경 유실 위험"

# DROP/TRUNCATE: 따옴표로 감싼 문자열(커밋 메시지·echo 등)은 검사 대상에서 제외해 오탐을 줄인다.
# 실제 psql 쓰기(따옴표 안의 SQL)는 guard-psql.sh 가 별도로 커버하므로 false-negative 없음.
SQLSCAN=$(printf '%s' "$CMD" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
printf '%s' "$SQLSCAN" | grep -qiE '(^|[^a-z])(drop[[:space:]]+(table|database)|truncate[[:space:]]+table)' && deny "DB 파괴 SQL 차단"

# 보상 통제(강): 사람 확인(permission prompt)이 빠지는 default/plan 외 모드에서만 추가 차단.
# push 는 최근 사용자 프롬프트에 git/배포 의도가 있으면 허용(자율 push 만 차단), 작업 트리 변경 유실은 차단.
# DB 스키마 변경(migration:run/revert·seed)은 기본 미차단(개발 DB 복구 가능) — 필요 시 여기 추가.
case "$MODE" in
default | plan) ;;
*)
  if printf '%s' "$CMD" | grep -qE "${GITX}"'push([[:space:]]|$)'; then
    user_intent_git_push "$TRANSCRIPT" \
      || deny "auto 모드: 사용자 요청 없는 자율 push 차단 — 직접 요청했거나 default 모드에서 실행"
  fi
  printf '%s' "$CMD" | grep -qE "${GITX}"'(clean[[:space:]]+-[a-z]*f|checkout[[:space:]]+--|restore([[:space:]]|$))' \
    && deny "auto 모드: 작업 트리 변경 유실 명령 차단"
  ;;
esac
exit 0
