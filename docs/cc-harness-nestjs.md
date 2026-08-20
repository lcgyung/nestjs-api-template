# Claude Code 하네스 구성 점검 — NestJS (API)

**목적**: CLAUDE.md · rules · skills · subagents · hooks · docs가 **최적 셋팅으로 구성되어, 컨텍스트 최적화를 통해 매회 작업 시 동일한 산출물**을 내도록 점검·정비한다.
**실행 모델**: 메인 세션은 사용자 선택 모델. 서브에이전트는 **역할별 차등 고정**(판단=opus, 기계 실행=haiku — 원안 "전부 opus-4-8 고정"과의 의도적 편차, [ADR 0010](adr/0010-claude-code-하네스-v2-결정.md)).
상태: 🟢 최적 / 🟡 존재하나 미흡 / 🔴 부재 — **2026-06-11 하네스 v2 작업으로 전 항목 정비 완료.**

---

## 0. 결정성 원칙 (이 문서 전체의 기준)

매회 동일 산출물 = **입력(컨텍스트)이 매번 같고, 강제 계층이 모델 판단에 의존하지 않을 때** 달성된다.

| 계층                  | 성격                 | 신뢰도 | 용도                                                 |
| --------------------- | -------------------- | ------ | ---------------------------------------------------- |
| **Hooks**             | 결정론적 (스크립트)  | ~100%  | 반드시 지켜야 할 불변식 (포맷·금지 명령·테스트 통과) |
| **CLAUDE.md / rules** | 확률적 (모델이 따름) | ~70%   | 컨벤션·선호. 위반해도 빌드가 안 깨지는 규칙          |
| **모델 판단**         | 비결정적             | 낮음   | 위 둘로 못 박지 않은 모든 것                         |

**핵심 전략 4가지**

1. **결정적 계층으로 밀기** — 깨지면 안 되는 규칙은 CLAUDE.md 문장이 아니라 **hook**으로. ("ValidationPipe 빼지 마"는 문장보다 lint+hook이 확실)
2. **컨텍스트 예산 관리** — CLAUDE.md는 200줄 이내, 나머지는 rules/docs로 분리(progressive disclosure). 컨텍스트가 깨끗할수록 출력이 일관됨.
3. **모델 고정** — 모든 subagent에 `model` 명시(역할별 차등 — ADR 0010). 모델이 바뀌면 산출물이 달라짐.
4. **장황한 출력 격리** — 테스트/마이그레이션 로그는 subagent(test-runner 등)에서 처리해 메인 컨텍스트 오염 방지.
5. **한 규칙 최대 2곳** — 규칙 본문은 (1) 정본(docs)과 (2) 경로 트리거 rules 카드에만 둔다.
   CLAUDE.md·skills·agents 는 포인터만, hooks 는 정본을 **런타임 주입**한다(요지 인라인 복제 금지 —
   수동 동기화 드리프트의 근원).

---

## 1. CLAUDE.md (항상 로드 — 컨텍스트 예산의 핵심)

- [x] 🟢 200줄 이내 유지 — **트림 완료(212→167줄)**: 인증/DTO/마이그레이션 상세→rules, 머신 강제 규칙→CONTRIBUTING.md, 검증 이원화→docs/architecture.md, 로드맵→README
- [x] 🟢 빌드/실행/테스트 명령 명시 — `pnpm start:dev` `pnpm test` `pnpm test:e2e` `pnpm lint` `pnpm typecheck`
- [x] 🟢 모듈/레이어 구조 1문단 (controller→service→repository, 상세는 docs/architecture.md)
- [x] 🟢 **불변 규칙만** 기재 — DTO+ValidationPipe, raw SQL 금지, 적용 마이그레이션 불변, 시크릿 ConfigModule 경유, 완료 전 lint/typecheck/test(Stop 게이트가 hook 으로도 강제)
- [ ] 자주 틀리는 것 발견 시 한 줄씩 추가, 모델이 무시하는 규칙은 삭제 (**지속 정비 — 상시 과제**)
- [x] 🟢 상세 컨벤션은 `docs/api-conventions.md`·`.claude/rules/` 참조로 위임 (본문 인라인 금지)

## 2. rules/ (경로 스코프 규칙 — 부분 컨텍스트)

`.claude/rules/*.md` + frontmatter `paths` 글롭 — 해당 파일을 만질 때만 로드. CLAUDE.md 비대화 방지.

- [x] 🟢 `rules/controllers.md` — thin controller, 전역 가드 전제(@UseGuards 재부착 금지), @HttpCode
- [x] 🟢 `rules/dto-validation.md` — class-validator 규칙, 출력 직렬화(`@Exclude`), VALIDATION_PIPE_OPTIONS 정본
- [x] 🟢 `rules/migrations.md` — 적용본 불변, PG enum TYPE·@UpdateDateColumn 특이사항, down 가역성
- [x] 🟢 `rules/auth.md` — deny-by-default, 소유권 검증(IDOR 방지) 필수 패턴
- [x] 🟢 `rules/testing.md` — testcontainers 격리(ADR 0009), 인증/인가 e2e 필수
- [x] 🟢 `rules/pattern-contamination.md` — ELEMENT 1: 경쟁 패턴 통일·dead code 제거·`chore(cleanup)` 분리 커밋(`src/**`)

## 3. skills/ (반복 절차 — 호출 시 로드)

매번 프롬프트에 같은 지시를 붙이지 않도록 절차를 SKILL.md로 고정 → 산출물 일관성↑.

- [x] 🟢 `skills/scaffold-module/` — 도메인 모듈 스캐폴드 (원안의 `new-module` 역할 — 기존 이름 유지, ADR 0010)
- [x] 🟢 `skills/migration-workflow/` — 마이그레이션 생성→검토→적용→드리프트 확인 표준 절차
- [x] 🟢 `skills/write-e2e/` — e2e 작성 절차(testcontainers 전제·보일러플레이트·필수 시나리오)
- [x] 🟢 `skills/api-endpoint/` — 정본 `docs/api-conventions.md` 의 절차 래퍼(이중 정본 방지)
- [x] 🟢 `skills/contamination-sweep/` — 전체 코드베이스 Pattern Contamination 정기 스윕(knip, 전용 세션)
- [x] 🟢 description 구체화 — 트리거 문구("마이그레이션 만들어", "e2e 테스트 작성" 등) 포함
- [x] 🟢 스킬 본문 포인터화 — 규약 요지를 스킬에 중복하지 않고 정본 절 번호로 참조(원칙 5)

## 4. subagents/ (독립 컨텍스트 — 오염 방지 + 전문화)

모델은 **역할별 차등 고정**(판단=opus, 실행=haiku — ADR 0010). 메인 컨텍스트를 깨끗이 유지.

- [x] 🟢 `agents/test-runner.md` — haiku. 단위/e2e 실행, **실패만 요약** 반환 (장황한 로그 격리)
- [x] 🟢 `agents/security-reviewer.md` — opus. `tools: Read, Grep, Glob` 읽기전용. IDOR/검증/시크릿/직렬화. `memory: project` 패턴 누적
- [x] 🟢 `agents/migration-reviewer.md` — opus. 파괴적 변경·down 가역성·적용본 수정 감지
- [x] 🟢 `agents/db-reader.md` — haiku. `tools: Bash, Read` + PreToolUse `guard-psql.sh` 로 **SELECT만 허용**(쓰기 차단) + PGOPTIONS read-only 2차 방어
- [x] 🟢 skills 프리로드 — code-reviewer/security-reviewer ← `code-review`, migration-reviewer ← `migration-workflow`

## 5. hooks (결정론적 강제 — 산출물 일관성의 보루)

`.claude/settings.json`. **모델이 우회할 수 없는** 계층.

- [x] 🟢 `SessionStart` → `session-context.sh`(브랜치 컨텍스트) + `contamination-report.sh`(knip 오염 맵 주입, 옵트인 `CC_CONTAMINATION_REPORT`, 캐시·비차단)
- [x] 🟢 `PostToolUse` (Edit|Write) → `prettier --write` + `eslint --fix` (포맷 항상 동일) + `record-touched.sh`(이 세션이 편집한 파일을 세션별 매니페스트에 기록 — 스코프 게이트·자동 커밋의 입력)
- [x] ❌ `PostToolUse` typecheck — **의도적 비채택**(ADR 0010): PostToolUse 는 차단 불가(이미 실행됨) + Stop 게이트가 풀 `tsc --noEmit` 을 이미 강제 + 편집마다 풀 tsc 는 루프만 느리게 함
- [x] 🟢 `PreToolUse` (Bash) → `guard-bash.sh`: DROP/TRUNCATE 등 파괴적 DB 명령 차단 (exit 2 대신 deny JSON)
- [x] 🟢 `PreToolUse` (Bash) → `rm -rf`/force push/reset --hard 차단(`git -c/-C` prefix 우회 가드) + `guard-psql.sh`(읽기전용). 가드/게이트 회귀는 `pnpm check:hooks`(6종 `.test.sh`)
- [x] 🟢 `Stop` 게이트 → 단계별 fail-fast(+타임아웃) `tsc --noEmit` + `eslint` + `prettier --check` + `check:migrations` + `check:api-tests`(변경분 한정) + 유닛 `jest` 미통과 시 차단(exit 2),
      통과 시 `review-gate.sh` 의미 리뷰(haiku, **규약 정본 전문 런타임 주입** — 동기화 0, CC_AUTO_REVIEW=1 상시). 공용 헬퍼는 `hooks/lib.sh` 정본
- [x] 🟢 `Stop` 게이트 **스코프 모드**(`CC_SCOPED_GATE=1`) → 검사를 '내 세션 작업파일'로 좁힌다. typecheck 는 전체로 돌리되 **내 파일 에러만 blocker**,
      lint/prettier/jest(`--findRelatedTests`)·`check:api-tests`(`CHECK_API_TESTS_FILES` 주입)는 작업파일 한정. 같은 워킹트리의 다른 세션 미완성 코드가 내 게이트를 막지 않게 한다(미설정 시 전체 검사로 폴백)
- [x] 🟢 `Stop` 게이트 **e2e 옵트인**(`CC_E2E_GATE=1`) → 켜면 `pnpm test:e2e` 까지 실행(Docker 미가용 시 경고 후 스킵=fail-open). 기본은 제외(빠른 루프)
- [x] 🟢 `Stop` 게이트 **자동 커밋**(`CC_AUTO_COMMIT=1`, 기본 OFF) → 전 단계 통과 시 `auto-commit.sh` 가 작업 컨텍스트만 스테이징해 커밋(헤드리스 haiku 로 Conventional Commits 메시지, 실패 시 폴백). main·detached HEAD·무변경은 no-op, **push 는 하지 않는다**
- [ ] (선택) `SubagentStop` — 현재 정리할 자원 없음(db-reader 는 구문당 단발 접속). 필요 시 추가

> 점검 포인트: "테스트 통과 후 완료"를 CLAUDE.md 문장으로만 두면 ~70%만 지켜짐. **hook으로 박으면 100%** → 매회 동일 품질.

## 6. docs/ (참조 문서 — on-demand)

- [x] 🟢 `docs/architecture.md` — 모듈 의존 다이어그램·요청 수명주기·검증 이원화·경로 별칭
- [x] 🟢 `docs/api-conventions.md` — 응답 포맷·에러 포맷·페이지네이션 **정본**(스킬이 참조, review-gate 가 전문을 런타임 주입)
- [x] 🟢 `docs/adr/` — 주요 결정 기록(0001~0010)
- [x] 🟢 CLAUDE.md/rules에서 참조만 (본문 인라인 금지 = 컨텍스트 절약)

## 7. settings & MCP

- [x] 🟢 `.claude/settings.json` — hooks + `permissions.deny`(sudo·강제 push·publish 등) 버전관리 포함
- [x] ❌ `.mcp.json` — **의도적 비채택**(ADR 0010): DB 조회는 db-reader(psql), 이슈는 `gh` CLI 로 충분.
      미사용 MCP 서버는 컨텍스트 낭비(이 절의 원칙 그대로)
- [x] 🟢 팀 공유: rules/skills/agents/hooks/settings 모두 `.claude/`에 커밋 → 팀 전체 동일 하네스

---

## 점검 매트릭스

| 구성요소     | 존재 | 최적화                | 결정성 기여   | 비고                              |
| ------------ | ---- | --------------------- | ------------- | --------------------------------- |
| CLAUDE.md    | ✅   | ✅ (167줄)            | 컨텍스트 예산 | 상세는 rules/docs 로 위임         |
| rules/       | ✅   | ✅ (paths 글롭)       | 부분 로드     | 6종 (pattern-contamination 포함)  |
| skills/      | ✅   | ✅ (구체 description) | 절차 고정     | 10종 (api-endpoint 는 정본 래퍼)  |
| subagents/   | ✅   | ✅ (model 차등 고정)  | 컨텍스트 격리 | 5종, ADR 0010                     |
| hooks        | ✅   | ✅ (불변식 강제)      | **최고**      | 스코프 게이트·자동 커밋 토글 포함 |
| docs/        | ✅   | ✅ (참조 위임)        | 예산 절약     | architecture·api-conventions·adr  |
| settings/MCP | ✅   | ✅ (deny 목록)        |               | .mcp.json 비채택(필요 서버 없음)  |

## 디렉터리 구조 (현재)

```
.claude/
├── rules/                   # controllers, dto-validation, migrations, auth, testing, pattern-contamination (paths 글롭)
├── skills/                  # api-endpoint(래퍼), code-review, scaffold-module, migration-workflow, write-e2e, tdd, contamination-sweep,
│                           # systematic-debugging, verification-before-completion, writing-skills(메타)
├── agents/                  # code-reviewer, security-reviewer, migration-reviewer, test-runner, db-reader
├── hooks/                   # lib(공용), session-context, contamination-report, guard-bash(+test), guard-psql(+test), format-changed-file,
│                           # record-touched(+test), gate(+test), review-gate(+test), auto-commit(+test)
└── settings.json            # hooks 체인 + permissions.deny + CC_AUTO_REVIEW · CC_CONTAMINATION_REPORT · CC_SCOPED_GATE · CC_E2E_GATE · CC_AUTO_COMMIT
CLAUDE.md                    # 167줄, 불변 규칙 + 참조 포인터 (루트 — Claude Code 표준 위치)
docs/                        # architecture, api-conventions(정본), adr/(0001~0010), 위협모델·보안 체크리스트
```

## 완료 정의

- [x] 깨지면 안 되는 규칙(포맷·typecheck·테스트·DB 안전)이 전부 **hook으로 강제**됨
- [x] CLAUDE.md 200줄 이내(167줄), 상세는 rules/docs로 분리
- [x] 모든 subagent `model` 고정 — 역할별 차등(판단=opus, 실행=haiku, ADR 0010)
- [ ] 동일 작업 3회 반복 시 산출물 구조·품질 동일 (회귀 확인 — **후속 과제**:
      `scaffold-module` 로 더미 모듈을 3회 생성해 구조 diff 비교 후 폐기)
