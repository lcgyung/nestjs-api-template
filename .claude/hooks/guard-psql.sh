#!/usr/bin/env bash
# PreToolUse(Bash): psql 은 읽기 전용(SELECT 계열)만 허용 — db-reader 서브에이전트 가드.
# 훅에는 호출 주체 식별자가 없으므로 전 세션 공통으로 적용한다(이 프로젝트에서 정당한
# psql 쓰기는 없다 — 스키마는 마이그레이션, 데이터는 시드가 담당).
# 정적 분석이 불가능한 형태(-f/stdin/heredoc/\i, 다중 -c)는 전부 거부(allowlist 방식).
# 오탐 방지: 인용 문자열 안의 "psql"/리다이렉트(커밋 메시지, SQL 내 < 비교 등)는 호출이
# 아니므로, 호출 감지·플래그 검사는 인용부를 제거한 문자열에서 수행한다.
# 심층 방어: db-reader 본문이 PGOPTIONS='-c default_transaction_read_only=on' 사용을 지시한다.
set -euo pipefail

# 공용 헬퍼(deny·require_json_object_or_deny·arm_fail_closed_trap) — 단일 정본 .claude/hooks/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
# fail-closed: 내부 오류(jq 부재·stdin 파싱 실패 등)는 통과가 아니라 차단(guard-bash 와 동일 원칙).
arm_fail_closed_trap guard-psql

INPUT=$(cat)
# stdin 이 JSON 객체가 아니면(빈/공백/깨진 입력·jq 부재 포함) 차단.
require_json_object_or_deny guard-psql "$INPUT"
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# 인용부('..'/"..")를 제거한 뷰 — psql "호출" 여부와 셸 레벨 플래그/리다이렉트 판단용.
# sed 는 줄 단위라 멀티라인 인용(커밋 메시지 등)이 깨지므로 개행을 먼저 공백으로 접는다.
STRIPPED=$(printf '%s' "$CMD" | tr '\n' ' ' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# psql 이 "명령 위치"(행 시작/;&|/서브셸/env 할당 뒤)에 있을 때만 호출로 본다 —
# 파일명(guard-psql.sh)·문자열 언급은 호출이 아니다.
printf '%s' "$STRIPPED" | grep -qE '(^|[;&|(`]|\$\()[[:space:]]*([A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]]+)*psql([[:space:]]|$)' || exit 0

# 파일/표준입력 SQL 은 정적 분석 불가 → 거부 (인용부 밖 기준)
printf '%s' "$STRIPPED" | grep -qE '(^|[[:space:]])(-f|--file)([[:space:]=]|$)' && deny "psql: -f/--file 금지 — -c '<SELECT...>' 단일 구문만 허용"
printf '%s' "$STRIPPED" | grep -qE '<' && deny "psql: stdin/heredoc 입력 금지 — -c '<SELECT...>' 단일 구문만 허용"
printf '%s' "$STRIPPED" | grep -qE '\|[[:space:]]*psql' && deny "psql: 파이프 입력 금지 — -c '<SELECT...>' 단일 구문만 허용"
printf '%s' "$STRIPPED" | grep -q '\\\\i' && deny "psql: \\i(파일 실행) 금지"

# -c 가 정확히 1개여야 한다 (PGOPTIONS='-c ...' 인용 내부는 STRIPPED 에서 이미 제거됨)
C_COUNT=$(printf '%s' "$STRIPPED" | grep -oE '(^|[[:space:]])(-c|--command)([[:space:]=]|$)' | wc -l | tr -d ' ')
[ "$C_COUNT" -eq 1 ] || deny "psql: -c 단일 구문만 허용 (현재 ${C_COUNT}개)"

# -c 인자(SQL) 추출 — 원본에서 큰따옴표/작은따옴표 모두 지원, 실패 시 거부
CMD_NO_ENV=$(printf '%s' "$CMD" | sed -E "s/PGOPTIONS='[^']*'//g; s/PGOPTIONS=\"[^\"]*\"//g")
SQL=$(printf '%s' "$CMD_NO_ENV" | sed -nE 's/.*(-c|--command)[[:space:]=]+"([^"]*)".*/\2/p')
[ -z "$SQL" ] && SQL=$(printf '%s' "$CMD_NO_ENV" | sed -nE "s/.*(-c|--command)[[:space:]=]+'([^']*)'.*/\2/p")
[ -z "$SQL" ] && deny "psql: SQL 인자를 해석할 수 없음 — -c '<SELECT...>' 인용 형태만 허용"

# allowlist: 첫 키워드가 읽기 계열이어야 한다 (\d·\l 등 메타 조회 포함)
printf '%s' "$SQL" | grep -qiE '^[[:space:]]*(select|with|explain|show|\\d[a-zA-Z+]*|\\l)' \
  || deny "psql: SELECT/WITH/EXPLAIN/SHOW(또는 \\d 메타)로 시작하는 읽기 쿼리만 허용"

# denylist: writable CTE·read-only 해제·세션 부작용 등 쓰기/부작용 키워드가 어디든 있으면 거부.
printf '%s' "$SQL" | grep -qiE '(^|[^a-z])(insert|update|delete|truncate|drop|alter|create|grant|revoke|copy|vacuum|call|do|merge|set|begin|commit|rollback|lock|comment|reindex|cluster|refresh|checkpoint|prepare|execute|deallocate|discard|listen|unlisten|notify)([^a-z]|$)' \
  && deny "psql: 쓰기/DDL/트랜잭션/부작용 키워드 차단 (읽기 전용)"
# ANALYZE 는 문장 위치(시작·세미콜론 뒤)에서만 거부 — 'EXPLAIN ANALYZE'(읽기 진단)는 허용. 'SELECT 1; ANALYZE t' 다중문 우회 차단.
printf '%s' "$SQL" | grep -qiE '(^|;)[[:space:]]*analyze([^a-z]|$)' \
  && deny "psql: ANALYZE 문 차단 (읽기 전용) — EXPLAIN ANALYZE 는 허용"

exit 0
