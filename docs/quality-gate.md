# TDD / 품질 게이트 자동화 (Claude Code skills + hooks)

> 상태: **계획 (미구현)** · 이 문서는 "어떻게 구현할지"에 대한 작업계획이다. 실제
> `.claude/` 스킬·훅은 아직 없으며(저장소가 스캐폴딩 미완료), 본 문서는 향후 구현의
> 청사진이다.

## 목표

모든 작업을 아래의 **작업 단위(work unit)** 사이클로 일관되게 수행/강제한다.

```
기능 구현 → 테스트 통과 → 린트 통과 → 프리티어 적용 → 작업 완료
```

세분화하면 RED → GREEN → REFACTOR 후 lint → format 게이트를 통과해야 "완료"로 본다.

| 단계     | 의미                      | 도구                  |
| -------- | ------------------------- | --------------------- |
| RED      | 실패하는 테스트 먼저 작성 | `npm run test`        |
| GREEN    | 통과시킬 최소 구현        | `npm run test`        |
| REFACTOR | 정리 (테스트 green 유지)  | `npm run test`        |
| LINT     | 정적 분석 통과            | `npm run lint`        |
| FORMAT   | 포매팅 적용               | `npx prettier --write`|
| DONE     | 위 전부 green일 때만 완료 | (게이트)              |

## 현재 프로젝트 전제

- 패키지 매니저: **npm**.
- 예정 스크립트: `npm run test`(jest), `npm run test:e2e`, `npm run lint`(eslint),
  `npm run format`(prettier --write). (스캐폴딩 후 `package.json`에 정의)
- 테스트 스택: **Jest** + `@nestjs/testing`.
  - 유닛: 서비스 `*.spec.ts` — Repository를 모킹해 비즈니스 로직 검증.
  - e2e: `test/*.e2e-spec.ts` — `supertest` + 실제 DB(또는 테스트 컨테이너) 필요.
- 기존 품질 장치(예정): `.husky/pre-commit` → `lint-staged`
  (`*.ts` → eslint --fix + prettier). **커밋 시점**에만 동작.

## 채택 방식: 하이브리드

1. **편집 시 자동 포맷** — `PostToolUse` 훅이 변경 파일에 prettier를 즉시 적용 (FORMAT 자동화).
2. **종료 시 차단 게이트** — `Stop` 훅이 `test → lint → prettier --check`를 실행, 실패 시 종료를
   막아 Claude가 고치도록 강제 (DONE 보장). **유닛 테스트만** 실행한다(e2e는 DB 의존 → 제외).
3. **절차 안내 스킬** — `/tdd` 스킬이 RED→GREEN→REFACTOR 규율과 명령을 안내.

---

## 구성요소 1 — `/tdd` 스킬

위치: `.claude/skills/tdd/SKILL.md`

```markdown
---
name: tdd
description: 모듈·서비스·컨트롤러를 구현/수정할 때 TDD 사이클(RED→GREEN→REFACTOR)과
  품질 게이트(test→lint→format)를 따르도록 안내한다. "테스트부터", "TDD로",
  새 기능 추가/버그 수정 시 사용.
---

# TDD 작업 단위

다음 순서를 한 작업 단위로 수행한다.

1. **RED** — 대상 옆에 실패하는 Jest 테스트(`*.spec.ts`)를 작성한다.
   `npm run test`로 "의도한 이유로" 실패하는지 확인한다.
   - 서비스: Repository를 모킹(`getRepositoryToken`)하여 로직만 검증.
   - 컨트롤러/통합: `@nestjs/testing`의 `Test.createTestingModule` 사용.
2. **GREEN** — 테스트를 통과시킬 최소 구현. `npm run test` 통과까지 반복.
3. **REFACTOR** — 중복 제거·정리. 테스트는 계속 green 유지.
4. **LINT** — `npm run lint`. 에러 0까지 수정(경고는 가능한 한 정리).
5. **FORMAT** — `npx prettier --write <변경파일>` 후 `npx prettier --check`로 확인.
   (PostToolUse 훅이 켜져 있으면 자동 적용되므로 확인만.)
6. **DONE** — test·lint·prettier가 모두 green이 아니면 완료로 보고하지 않는다.

비즈니스 로직은 Service에 두고(Controller는 얇게), 입력은 DTO + class-validator로 검증한다
(프로젝트 규칙). 운영 스키마 변경은 `synchronize` 대신 마이그레이션으로만 한다.
```

## 구성요소 2 — PostToolUse 훅 (자동 프리티어)

위치: `.claude/settings.json`

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(jq -r '.tool_input.file_path // empty'); case \"$file\" in *.ts|*.js|*.json|*.md) npx prettier --write \"$file\" >/dev/null 2>&1 ;; esac; exit 0"
          }
        ]
      }
    ]
  }
}
```

- 훅은 stdin으로 JSON(`tool_name`, `tool_input`, `tool_response`, `cwd` 등)을 받는다.
  여기서 `tool_input.file_path`를 읽어 대상 파일만 포맷한다.
- **항상 exit 0**(비차단) — 포매팅이 작업 흐름을 끊지 않게 한다.
- 효과: "프리티어 적용" 단계가 편집 직후 자동으로 일어난다.

## 구성요소 3 — Stop 훅 (완료 게이트)

위치: `.claude/settings.json` (위 `hooks`에 병합)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "input=$(cat); [ \"$(echo \"$input\" | jq -r '.stop_hook_active')\" = \"true\" ] && exit 0; if ! (npm run test && npm run lint && npx prettier --check .) >/tmp/qa-gate.log 2>&1; then echo '품질 게이트 실패: test/lint/prettier 중 하나가 실패했습니다. 수정 후 종료하세요.' >&2; tail -n 30 /tmp/qa-gate.log >&2; exit 2; fi"
          }
        ]
      }
    ]
  }
}
```

- **무한루프 방지**: stdin의 `stop_hook_active`가 `true`면(이미 게이트가 한 번 막은 상태) 즉시 exit 0.
- **차단 규약**: 실패 시 `exit 2` + stderr → Claude가 종료하지 못하고 사유를 받아 수정한다.
- 게이트 순서가 곧 요구사항: `test → lint → prettier --check`. **유닛(`npm run test`)만** 실행한다.

### 트레이드오프 / 튜닝

- 매 종료마다 풀 Jest는 지연이 있다. 대안:
  - 변경과 관련된 테스트만 실행: `jest --findRelatedTests <files>` 또는 `--onlyChanged`.
  - 게이트를 가볍게: `lint` + `prettier --check`만 Stop에 두고, 테스트는 `/tdd` 스킬 절차로 보장.
- 타입 안전을 게이트에 포함하려면 `tsc --noEmit`(또는 `nest build`)를 추가한다.
- **e2e는 Stop 게이트에서 제외**한다 — DB(또는 테스트 컨테이너)가 필요해 느리고 환경 의존적이다.
  CI에서 MySQL service container와 함께 별도 단계로 돌린다.

## 기존 husky / lint-staged 와의 관계

- `.husky/pre-commit`(lint-staged)은 **커밋 시점 최종 안전망**으로 유지한다.
- 신규 훅은 피드백을 앞당긴다: 편집 즉시 포맷(PostToolUse), 작업 종료 시 test+lint+format
  게이트(Stop) → **커밋 이전에** 문제를 해소.
- 역할 분담: lint-staged = 스테이징 파일 범위 / Stop 게이트 = 작업 단위 전체 검증.

## 보안 · 공유 주의

- 훅은 **셸 명령을 실행**한다. 신뢰할 수 있는 명령만 둔다.
- 팀 공유 설정은 `.claude/settings.json`(커밋), 개인/민감 설정은
  `.claude/settings.local.json`(gitignore)로 분리.
- 도입 시 **현재 Claude Code 훅 스키마**(이벤트명, exit 코드 의미, JSON 출력 규약,
  `jq` 등 의존 도구 가용성)를 공식 문서로 재확인할 것. 위 예시는 설계 기준이며 실제 적용 전
  검증이 필요하다.

## 단계별 구현 로드맵

1. `.claude/skills/tdd/SKILL.md` 추가 → `/tdd`로 절차 안내 확인.
2. `.claude/settings.json`에 PostToolUse 자동 포맷 훅 추가 → 편집 후 자동 prettier 동작 확인.
3. Stop 게이트 훅 추가 → 일부러 실패 테스트를 두고 종료가 차단되는지 확인.
4. 팀 합의로 차단 강도/테스트 범위/타입체크 포함 여부 튜닝.

## 구현 시 검증 (Definition of Done)

- `/tdd` 스킬이 인식되고 절차대로 안내된다.
- 임의 `.ts` 편집 후 자동으로 prettier가 적용된다(PostToolUse).
- 실패 테스트가 있으면 종료가 차단되고, 고치면 정상 종료된다(Stop, exit 2 → 0).
- 기존 `npm run test/lint/build`와 husky 커밋 훅이 그대로 통과한다.
