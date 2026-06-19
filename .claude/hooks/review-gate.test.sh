#!/usr/bin/env bash
# review-gate.sh 케이스 테스트 — claude CLI 를 PATH 스텁으로 대체하고 임시 git repo 로 검증.
# 검증: 모드→FORCE 분기·옵트인·라운드 카운터·VERDICT 행앵커·공백 경로 안전·변경없음 통과.
set -uo pipefail
RG="$(cd "$(dirname "$0")" && pwd)/review-gate.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/src" "$TMP/docs"

# claude 스텁: CLAUDE_STUB_OUT 을 그대로 출력(미설정 시 PASS). 실제 모델 호출 없음.
cat >"$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${CLAUDE_STUB_OUT:-VERDICT: PASS}"
STUB
chmod +x "$TMP/bin/claude"

printf '# 규약\n본문(런타임 주입 대상)\n' >"$TMP/docs/api-conventions.md"
(
  cd "$TMP"
  git init -q
  git config user.email t@t.t
  git config user.name t
  printf 'export const A = 1;\n' >src/a.ts
  git add -A
  git commit -q -m init
)

ROUND="$TMP/.git/cc_review_round"
FAILED=0

rg() { # <mode> <auto:0|1> <stub-out> → review-gate 실행, 종료코드 반환
  # env -u 로 상속된 CC_AUTO_REVIEW/CC_GATE_SKIP(세션 settings.json env)을 비워 결정적으로 만든다.
  local mode=$1 auto=$2 stubout=$3 env_auto=""
  [ "$auto" = "1" ] && env_auto="CC_AUTO_REVIEW=1"
  (
    cd "$TMP"
    printf '%s' "{\"permission_mode\":\"$mode\"}" \
      | env -u CC_AUTO_REVIEW -u CC_GATE_SKIP \
          PATH="$TMP/bin:$PATH" CLAUDE_PROJECT_DIR="$TMP" CLAUDE_STUB_OUT="$stubout" $env_auto bash "$RG"
  ) >/dev/null 2>&1
}
chk() { # <label> <expect> <actual>
  if [ "$3" = "$2" ]; then echo "PASS [$1] → exit $3"; else echo "FAIL [$1] → exit $3 (expect $2)"; FAILED=1; fi
}

# 추적 변경 생성(커밋 본문과 다르게)
printf 'export const A = 2;\n' >"$TMP/src/a.ts"

rm -f "$ROUND"
rg default 0 'VERDICT: BLOCK'
chk "default 옵트인 OFF → 리뷰 안 함" 0 $?

rm -f "$ROUND"
rg default 1 'VERDICT: PASS'
chk "옵트인 ON + PASS" 0 $?

rm -f "$ROUND"
rg default 1 $'- src/a.ts: 위반(수정안)\nVERDICT: BLOCK'
chk "옵트인 ON + BLOCK" 2 $?
[ -f "$ROUND" ] && echo "PASS [BLOCK 후 라운드파일 기록]" || { echo "FAIL [BLOCK 후 라운드파일 기록]"; FAILED=1; }

rm -f "$ROUND"
rg default 1 $'설명: 절대 "VERDICT: BLOCK" 라고 본문에 쓰지 말 것\nVERDICT: PASS'
chk "VERDICT 행앵커(prose 속 BLOCK 무시)" 0 $?

echo 1 >"$ROUND"
rg default 1 'VERDICT: BLOCK'
chk "라운드 상한(default MAX=1) 도달 → 통과" 0 $?

rm -f "$ROUND"
rg acceptEdits 0 'VERDICT: BLOCK'
chk "auto 모드: 옵트인 OFF 라도 리뷰 강제 + BLOCK" 2 $?

# 공백 포함 신규(미추적) 파일도 크래시 없이 처리
rm -f "$ROUND"
printf 'export const B = 1;\n' >"$TMP/src/b c.ts"
rg default 1 'VERDICT: PASS'
chk "공백 경로 신규파일 처리" 0 $?
rm -f "$TMP/src/b c.ts"

# 변경을 커밋 본문으로 되돌리면(변경 0) 통과 + 라운드파일 제거
printf 'export const A = 1;\n' >"$TMP/src/a.ts"
echo 1 >"$ROUND"
rg default 1 'VERDICT: BLOCK'
chk "변경 없음 → 통과" 0 $?
[ -f "$ROUND" ] && { echo "FAIL [변경없음 → 라운드파일 제거]"; FAILED=1; } || echo "PASS [변경없음 → 라운드파일 제거]"

exit "$FAILED"
