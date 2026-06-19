#!/usr/bin/env bash
# 공용 훅 헬퍼 — 여러 훅 스크립트가 source 한다(복붙 제거, 단일 정본).
# 외부 바이너리 의존 최소화: 타임아웃은 순수 bash(macOS 기본 timeout 없음), PreToolUse deny 는 jq 없이도 동작.
# 이 파일은 source 전용이라 set/exec 부수효과를 두지 않는다(함수 정의만).

# 순수 bash 타임아웃 래퍼(timeout 바이너리 불요, bash 3.2 호환).
# 진단 메시지(예: jest·prettier 는 stderr 로 출력)도 잃지 않도록 stdout+stderr 를 합쳐 outfile 로 캡처한다.
run_with_timeout() { # <secs> <outfile> <cmd...>
  local secs=$1 out=$2
  shift 2
  "$@" >"$out" 2>&1 &
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
