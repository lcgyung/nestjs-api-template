#!/usr/bin/env bash
# 공용 훅 헬퍼 — 여러 훅 스크립트가 source 한다(복붙 제거, 단일 정본).
# 외부 바이너리 의존 최소화: 타임아웃은 순수 bash(macOS 기본 timeout 없음), PreToolUse deny 는 jq 없이도 동작.
# 이 파일은 source 전용이라 set/exec 부수효과를 두지 않는다(함수 정의만).

# 순수 bash 타임아웃 래퍼(timeout 바이너리 불요, bash 3.2 호환).
# 진단 메시지(예: jest·prettier 는 stderr 로 출력)도 잃지 않도록 stdout+stderr 를 합쳐 outfile 로 캡처한다.
run_with_timeout() { # <secs> <outfile> <cmd...>
  local secs=$1 out=$2
  shift 2
  "$@" >"$out" 2>&1 </dev/null & # 자식 stdin 을 /dev/null 로 고정 — claude 의 "no stdin" 경고/3초 대기 차단(비대화식 명령만 호출)
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

# PreToolUse 차단 결정을 jq 없이 raw JSON 으로 출력(fail-closed 경로 — jq 부재·내부 오류 시 사용).
# reason 의 JSON 메타문자(백슬래시·큰따옴표·개행·탭)만 최소 이스케이프한다.
pretooluse_deny_raw() { # <reason>
  local reason=${1:-"guard 내부 오류 — 안전을 위해 차단(fail-closed)"}
  reason=${reason//\\/\\\\}
  reason=${reason//\"/\\\"}
  reason=${reason//$'\n'/\\n}
  reason=${reason//$'\t'/\\t}
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
}

# PreToolUse 차단 결정을 jq 로 출력(정상 경로 — 가드가 이미 jq 로 입력을 파싱하므로 jq 존재 전제).
# 각 가드가 복붙하던 deny JSON 블록의 단일 정본. 종료까지 포함한 형태는 아래 deny() 를 쓴다.
pretooluse_deny() { # <reason>
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
}

# PreToolUse 차단 결정 출력 + 종료(정상 경로). 각 가드가 복붙하던 `deny(){...}` 의 단일 정본.
# 주의: source 된 함수의 exit 는 호출 스크립트를 종료한다 — 가드의 의도된 동작(차단 후 즉시 종료).
deny() { # <reason>
  pretooluse_deny "$1"
  exit 0
}

# fail-closed: stdin 이 JSON 객체가 아니면(빈/공백/깨진 입력·jq 부재 포함) 통과시키지 않고 차단.
# <label> 은 진단용 가드 이름(예: guard-bash). 각 가드가 복붙하던 검사의 단일 정본.
require_json_object_or_deny() { # <label> <input>
  printf '%s' "$2" | jq -e 'type == "object"' >/dev/null 2>&1 \
    || { pretooluse_deny_raw "$1: stdin 이 JSON 객체가 아님 — 안전을 위해 차단(fail-closed)"; exit 0; }
}

# fail-closed ERR 트랩 무장: 예기치 못한 오류(jq 부재·파싱 실패 등)는 통과가 아니라 차단으로 떨어뜨린다.
# set -e 와 함께 PreToolUse 가드에서만 쓴다. <label> 은 진단용 가드 이름.
arm_fail_closed_trap() { # <label>
  trap "pretooluse_deny_raw '$1 내부 오류 — 안전을 위해 차단(fail-closed)'; exit 0" ERR
}

# repo 의 .git 디렉터리 절대경로(worktree·서브모듈 안전 — linked worktree 는 <root>/.git/worktrees/<name>).
# 훅 캐시/상태 파일(cc_knip_cache·cc_review_round 등)은 ".git/" 하드코딩 대신 여기에 둔다.
git_dir() {
  git rev-parse --absolute-git-dir 2>/dev/null || echo .git
}

# repo 의 공유 .git common dir 절대경로. git_dir()(--absolute-git-dir)는 linked worktree 에서
# worktree-로컬 경로를 주지만, 동시 세션이 공유해야 하는 상태(세션 레지스트리)는 여기에 둔다.
# --git-common-dir 가 상대경로(.git)를 줄 수 있어 절대화한다(git 2.31+ 의 --path-format=absolute).
common_dir() {
  git rev-parse --path-format=absolute --git-common-dir 2>/dev/null \
    || { d=$(git rev-parse --git-common-dir 2>/dev/null || echo .git); (cd "$d" 2>/dev/null && pwd) || echo "$d"; }
}

# 이 세션의 작업 컨텍스트 디렉터리(common-dir 공유). <sid> 는 훅 stdin 의 session_id.
# 같은 워킹트리에서 동시 세션이 한 매니페스트에 뒤섞이지 않도록 세션별로 분리한다.
# sid 부재 시 worktree 기준 안정 폴백(사실상 worktree당 1세션 = 현행 단일 매니페스트와 동질).
cc_sess_dir() { # <sid>
  local sid=${1:-}
  [ -n "$sid" ] || sid="wt-$(basename "$(git_dir)")"
  echo "$(common_dir)/cc_sessions/$sid"
}

# 임시 파일 경로(mktemp 우선, 미지원 환경은 PID 기반 폴백). <prefix> 로 폴백 파일명을 구분한다.
mk_tmp() { # <prefix>
  mktemp 2>/dev/null || echo "/tmp/${1:-cc_tmp}_$$"
}

# 헤드리스 claude 호출(재귀 방지 sentinel CC_GATE_SKIP=1 + 경량 모델 haiku 고정). 출력은 <outfile> 로 캡처.
# 타임아웃/실패 시 비차단은 호출부가 빈 출력으로 처리한다(run_with_timeout 가 stdout+stderr 합쳐 캡처).
run_headless_claude() { # <timeout-secs> <outfile> <prompt>
  run_with_timeout "$1" "$2" env CC_GATE_SKIP=1 claude -p "$3" --model haiku
}

# SessionStart additionalContext(JSON) 출력 — 여러 SessionStart 훅의 공통 emit 정본.
emit_session_context() { # <text>
  jq -n --arg s "$1" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $s}}'
}
