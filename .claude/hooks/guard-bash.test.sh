#!/usr/bin/env bash
# guard-bash.sh 케이스 테스트 — jq 로 JSON 을 안전 생성해 훅에 주입한다.
# auto 모드의 push 게이트는 transcript_path 의 last-prompt(사용자 의도)를 읽으므로
# 픽스처 트랜스크립트(JSONL)를 만들어 ALLOW/DENY 를 고정한다.
set -uo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

INTENT="$TMP/intent.jsonl"        # git/배포 의도 있는 프롬프트
NOINTENT="$TMP/nointent.jsonl"    # 의도 없는 프롬프트
NEGATE="$TMP/negate.jsonl"        # push 를 부정(자율 push 금지)하는 프롬프트
jq -nc '{type:"last-prompt", lastPrompt:"v0.2.2 릴리즈하자 dev to main"}' >"$INTENT"
jq -nc '{type:"last-prompt", lastPrompt:"오타 좀 고쳐줘"}' >"$NOINTENT"
jq -nc '{type:"last-prompt", lastPrompt:"아직 push 하지마, 커밋만 해줘"}' >"$NEGATE"

t() { # <label> <command> <mode> <transcript-path> <expect: ALLOW|DENY>
  local label=$1 cmd=$2 mode=$3 tp=$4 expect=$5 out decision
  out=$(jq -n --arg c "$cmd" --arg m "$mode" --arg t "$tp" \
    '{tool_input: {command: $c}, permission_mode: $m, transcript_path: $t}' | ./guard-bash.sh)
  if [ -z "$out" ]; then decision="ALLOW"; else decision="DENY"; fi
  if [ "$decision" = "$expect" ]; then
    echo "PASS [$label] → $decision"
  else
    echo "FAIL [$label] → $decision (expect $expect)"
    FAILED=1
  fi
}

FAILED=0
# 모드 무관 고정 차단
t "rm -rf 홈"           'rm -rf $HOME/x'              auto    "$INTENT"          DENY
t "rm 따옴표 루트 우회"  'rm -rf "/"'                 auto    "$INTENT"          DENY
t "rm 장문자 플래그"     'rm --recursive --force /'   auto    "$INTENT"          DENY
t "force push(의도 O)"  'git push --force origin dev' auto    "$INTENT"          DENY
t "force push -c 우회"   'git -c user.email=a@b.c push --force origin dev' auto "$INTENT" DENY
t "reset --hard"        'git reset --hard'           auto    "$INTENT"          DENY
t "reset --hard -C 우회" 'git -C /repo reset --hard'  auto    "$INTENT"          DENY
# DROP/TRUNCATE: 따옴표 안 SQL 은 guard-psql 위임이라 guard-bash 단독으론 통과, 비따옴표만 차단.
t "drop table(비따옴표)" 'mysql -e DROP TABLE users'  auto    "$INTENT"          DENY
t "drop table(psql 위임)" 'psql -c "DROP TABLE x"'    auto    "$INTENT"          ALLOW
t "drop table 문자열 오탐" 'git commit -m "fix: drop table 가드"' auto "$INTENT"  ALLOW

# default/plan 모드: push 자유(사람 확인 존재)
t "default push"        'git push origin dev'        default "$NOINTENT"        ALLOW
t "plan push"           'git push origin dev'        plan    "$NOINTENT"        ALLOW

# auto 모드 push: 사용자 의도 기반 게이트
t "auto push 의도 O"    'git push origin dev'        auto    "$INTENT"          ALLOW
t "auto push 의도 X"    'git push origin dev'        auto    "$NOINTENT"        DENY
t "auto push 부정문"    'git push origin dev'        auto    "$NEGATE"          DENY
t "auto 태그 push 의도 O" 'git push origin v0.2.2'   auto    "$INTENT"          ALLOW
t "auto push transcript 빈값" 'git push origin dev'  auto    ""                 DENY
t "auto push 파일 없음" 'git push origin dev'        auto    "$TMP/none.jsonl"  DENY
t "acceptEdits push 의도 O" 'git push origin dev'    acceptEdits "$INTENT"      ALLOW

# auto 모드 트리유실: 항상 차단(의도 무관)
t "auto checkout --"    'git checkout -- src/app.ts' auto    "$INTENT"          DENY
t "auto restore"        'git restore src/app.ts'     auto    "$INTENT"          DENY
t "auto clean -f"       'git clean -fd'              auto    "$INTENT"          DENY
t "auto 브랜치 전환"    'git checkout main'          auto    "$INTENT"          ALLOW

# 무관 명령
t "일반 ls"             'ls -al'                     auto    "$INTENT"          ALLOW
t "git status"          'git status'                 auto    "$NOINTENT"        ALLOW

# fail-closed: 깨진 stdin(JSON 아님)·빈 stdin 은 '통과'가 아니라 '차단' 으로 떨어져야 한다.
fc() { # <label> <raw-stdin>
  local label=$1 raw=$2 out
  out=$(printf '%s' "$raw" | ./guard-bash.sh 2>/dev/null || true)
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then
    echo "PASS [$label] → DENY"
  else
    echo "FAIL [$label] → ALLOW (expect DENY=fail-closed)"
    FAILED=1
  fi
}
fc "malformed stdin fail-closed" 'not json at all'
fc "empty stdin fail-closed" ''

exit "$FAILED"
