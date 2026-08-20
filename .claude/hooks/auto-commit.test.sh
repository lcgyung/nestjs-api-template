#!/usr/bin/env bash
# auto-commit.sh 케이스 테스트 — claude 를 PATH 스텁으로 대체하고 임시 git repo 로 검증.
# 검증: 기본 ON 커밋·끄기 스위치·main 보호·변경없음 no-op·메시지 폴백/채택·
#       작업 컨텍스트(.git/cc_touched) 한정 스테이징·커밋 후 트리/매니페스트 정리(루프 차단).
set -uo pipefail
AC="$(cd "$(dirname "$0")" && pwd)/auto-commit.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

# claude 스텁: CLAUDE_STUB_OUT 을 그대로 출력. 실제 모델 호출 없음.
cat >"$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${CLAUDE_STUB_OUT:-feat(stub): 스텁 메시지}"
STUB
chmod +x "$TMP/bin/claude"

(
  cd "$TMP"
  git init -q
  git config user.email t@t.t
  git config user.name t
  printf 'init\n' >base.txt
  git add -A
  git commit -q -m init
  git branch -m work # 비-main 브랜치(기본 ON 케이스)
)

TOUCHED="$TMP/.git/cc_touched"
FAILED=0
pass() { echo "PASS [$1]"; }
fail() {
  echo "FAIL [$1]"
  FAILED=1
}

# auto-commit 실행 — 상속된 세션 env(CC_*) 를 비워 결정적으로.
run_ac() { # <CC_AUTO_COMMIT-or-empty> <stub-out>
  local ac=$1 stub=$2 env_ac=""
  [ -n "$ac" ] && env_ac="CC_AUTO_COMMIT=$ac"
  (
    cd "$TMP"
    env -u CC_AUTO_COMMIT -u CC_GATE_SKIP \
      PATH="$TMP/bin:$PATH" CLAUDE_STUB_OUT="$stub" $env_ac bash "$AC"
  ) >/dev/null 2>&1
}
count() { git -C "$TMP" rev-list --count HEAD; }
headmsg() { git -C "$TMP" log -1 --pretty=%s; }

# 1) 기본 ON + dirty + 매니페스트 없음(폴백 add -A) + 유효 stub → 커밋 1건, 메시지 채택, 트리 clean
printf 'a\n' >"$TMP/f1.txt"
before=$(count)
run_ac "" "feat(scope): 유효한 메시지"
[ "$(count)" = "$((before + 1))" ] && pass "기본 ON dirty → 커밋 생성(폴백)" || fail "기본 ON dirty → 커밋 생성(폴백)"
[ "$(headmsg)" = "feat(scope): 유효한 메시지" ] && pass "유효 stub 메시지 채택" || fail "유효 stub 메시지 채택"
[ -z "$(git -C "$TMP" status --porcelain)" ] && pass "커밋 후 트리 clean(루프 차단)" || fail "커밋 후 트리 clean(루프 차단)"

# 2) 변경 없음 → no-op
before=$(count)
run_ac "" "feat(x): 무시됨"
[ "$(count)" = "$before" ] && pass "변경 없음 → no-op" || fail "변경 없음 → no-op"

# 3) 끄기 스위치 CC_AUTO_COMMIT=0 → 커밋 없음
printf 'b\n' >"$TMP/f2.txt"
before=$(count)
run_ac "0" "feat(x): 안됨"
[ "$(count)" = "$before" ] && pass "CC_AUTO_COMMIT=0 → 커밋 없음" || fail "CC_AUTO_COMMIT=0 → 커밋 없음"

# 4) 형식불일치 stub → 폴백(chore:) 메시지 채택 (f2.txt 아직 미커밋 = dirty)
before=$(count)
run_ac "" "이건 형식이 틀린 메시지"
[ "$(count)" = "$((before + 1))" ] && pass "형식불일치 → 폴백 커밋" || fail "형식불일치 → 폴백 커밋"

# 4-1) 오염 출력(stdin 경고 + 코드펜스)에서도 실제 메시지 추출 — 회귀 방지(폴백으로 떨어지면 실패)
printf 'f3\n' >"$TMP/f3.txt"
before=$(count)
run_ac "" "Warning: no stdin data received in 3s, proceeding without it.
\`\`\`
feat(reg): 오염 출력에서도 추출
\`\`\`"
[ "$(count)" = "$((before + 1))" ] && pass "오염 출력 → 커밋 생성" || fail "오염 출력 → 커밋 생성"
[ "$(headmsg)" = "feat(reg): 오염 출력에서도 추출" ] && pass "경고+펜스 오염에도 실제 메시지 채택" || fail "경고+펜스 오염에도 실제 메시지 채택"

# 5) 작업 컨텍스트 한정: 두 파일 dirty 인데 매니페스트엔 하나만 → 그 파일만 커밋, 다른 파일은 그대로 dirty
printf 'ctx\n' >"$TMP/ctx.txt"
printf 'other\n' >"$TMP/other.txt"
printf 'ctx.txt\n' >"$TOUCHED"
before=$(count)
run_ac "" "feat(ctx): 컨텍스트만"
[ "$(count)" = "$((before + 1))" ] && pass "컨텍스트 한정 → 커밋 생성" || fail "컨텍스트 한정 → 커밋 생성"
if git -C "$TMP" show --name-only --pretty=format: HEAD | grep -qx 'ctx.txt' &&
  ! git -C "$TMP" show --name-only --pretty=format: HEAD | grep -qx 'other.txt'; then
  pass "컨텍스트 파일만 스테이징(other 제외)"
else
  fail "컨텍스트 파일만 스테이징(other 제외)"
fi
git -C "$TMP" status --porcelain | grep -q 'other.txt' && pass "비컨텍스트 파일은 dirty 유지" || fail "비컨텍스트 파일은 dirty 유지"
[ -f "$TOUCHED" ] && fail "커밋 후 매니페스트 삭제" || pass "커밋 후 매니페스트 삭제"

# 7) CC_COMMIT_FILES 우선 — env 목록의 파일만 스테이징(레거시 매니페스트·add -A 보다 우선), 다른 dirty 는 제외
printf 'cf\n' >"$TMP/cf.txt"
printf 'skip\n' >"$TMP/skip.txt"
before=$(count)
(
  cd "$TMP"
  env -u CC_AUTO_COMMIT -u CC_GATE_SKIP \
    PATH="$TMP/bin:$PATH" CLAUDE_STUB_OUT="feat(cf): 목록만" \
    CC_COMMIT_FILES="cf.txt" bash "$AC"
) >/dev/null 2>&1
[ "$(count)" = "$((before + 1))" ] && pass "CC_COMMIT_FILES → 커밋 생성" || fail "CC_COMMIT_FILES → 커밋 생성"
if git -C "$TMP" show --name-only --pretty=format: HEAD | grep -qx 'cf.txt' &&
  ! git -C "$TMP" show --name-only --pretty=format: HEAD | grep -qx 'skip.txt'; then
  pass "CC_COMMIT_FILES 목록만 스테이징(skip 제외)"
else
  fail "CC_COMMIT_FILES 목록만 스테이징(skip 제외)"
fi
git -C "$TMP" status --porcelain | grep -q 'skip.txt' && pass "목록 밖 파일은 dirty 유지" || fail "목록 밖 파일은 dirty 유지"

# 8) main 브랜치 → 커밋 없음 (skip.txt 가 아직 dirty)
git -C "$TMP" branch -m main
before=$(count)
run_ac "" "feat(x): main 보호"
[ "$(count)" = "$before" ] && pass "main 브랜치 → 커밋 없음" || fail "main 브랜치 → 커밋 없음"
git -C "$TMP" branch -m work

exit "$FAILED"
