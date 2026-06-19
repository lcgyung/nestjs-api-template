#!/usr/bin/env bash
# guard-psql.sh 케이스 테스트 — jq 로 JSON 을 안전 생성해 훅에 주입한다.
set -uo pipefail
cd "$(dirname "$0")"

t() { # <label> <command-string> <expect: ALLOW|DENY>
  local label=$1 cmd=$2 expect=$3
  local out decision
  out=$(jq -n --arg c "$cmd" '{tool_input: {command: $c}}' | ./guard-psql.sh)
  if [ -z "$out" ]; then decision="ALLOW"; else decision="DENY"; fi
  if [ "$decision" = "$expect" ]; then
    echo "PASS [$label] → $decision"
  else
    echo "FAIL [$label] → $decision (expect $expect)"
    FAILED=1
  fi
}

FAILED=0
t "DELETE 직접"        'psql -c "DELETE FROM users"'                                        DENY
t "SELECT 허용"        'psql -h localhost -U postgres -c "SELECT * FROM users LIMIT 5"'     ALLOW
t "heredoc"            $'psql <<EOF\nDROP TABLE users;\nEOF'                                DENY
t "-f 파일"            'psql -f evil.sql'                                                   DENY
t "writable CTE"       'psql -c "WITH x AS (DELETE FROM users RETURNING *) SELECT * FROM x"' DENY
t "read-only 해제"     'psql -c "SET default_transaction_read_only=off"'                    DENY
t "PGOPTIONS+SELECT"   "PGOPTIONS='-c default_transaction_read_only=on' psql -c \"SELECT count(*) FROM users\"" ALLOW
t "psql 무관 명령"     'echo hello psqlx'                                                   ALLOW
t "다중 -c"            'psql -c "SELECT 1" -c "DROP TABLE users"'                           DENY
t "메타 \\dt"          'psql -c "\dt"'                                                      ALLOW
t "일반 ls"            'ls -al'                                                             ALLOW
t "파이프 입력"        'echo "DROP TABLE users" | psql'                                     DENY
t "EXPLAIN 허용"       'psql -c "EXPLAIN SELECT * FROM users"'                              ALLOW
t "인용 없는 -c"       'psql -c SELECT1'                                                    DENY
t "커밋 메시지 언급"   "git commit -m 'psql: -c <SELECT...> 가드 추가'"                     ALLOW
t "SQL 내 < 비교"      'psql -c "SELECT * FROM users WHERE id < 5"'                         ALLOW
t "인용 밖 리다이렉트" 'psql -c "SELECT 1" < input.sql'                                     DENY
t "파일명 언급"        'cat .claude/hooks/guard-psql.sh'                                    ALLOW
t "멀티라인 커밋"      $'git commit -m "feat: guard-psql.sh 추가\n\nCo-Authored-By: X <x@y.z>"' ALLOW
t "체인 뒤 호출"       'echo hi && psql -c "SELECT 1"'                                      ALLOW
t "체인 뒤 쓰기"       'echo hi && psql -c "DELETE FROM users"'                             DENY

# 부작용 키워드 보강 — 다중문 우회(SELECT 로 시작 후 부작용문) 차단
t "다중문 ANALYZE"     'psql -c "SELECT 1; ANALYZE users"'                                  DENY
t "다중문 CHECKPOINT"  'psql -c "SELECT 1; CHECKPOINT"'                                     DENY
t "다중문 NOTIFY"      'psql -c "SELECT 1; NOTIFY ch"'                                      DENY
t "다중문 EXECUTE"     'psql -c "SELECT 1; EXECUTE stmt"'                                   DENY
t "VACUUM"             'psql -c "VACUUM"'                                                   DENY
t "REFRESH MV"         'psql -c "REFRESH MATERIALIZED VIEW mv"'                             DENY
# EXPLAIN ANALYZE 는 읽기 진단이라 허용(analyze 는 문장 위치에서만 거부)
t "EXPLAIN ANALYZE"    'psql -c "EXPLAIN ANALYZE SELECT * FROM users"'                      ALLOW

# fail-closed: 깨진/빈 stdin 은 통과가 아니라 차단
fc() { # <label> <raw-stdin>
  local label=$1 raw=$2 out
  out=$(printf '%s' "$raw" | ./guard-psql.sh 2>/dev/null || true)
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then
    echo "PASS [$label] → DENY"
  else
    echo "FAIL [$label] → ALLOW (expect DENY=fail-closed)"
    FAILED=1
  fi
}
fc "malformed stdin fail-closed" 'not json'
fc "empty stdin fail-closed" ''

exit "$FAILED"
