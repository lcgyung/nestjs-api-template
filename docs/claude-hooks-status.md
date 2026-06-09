# Claude Code 훅 자동화 — 구현 현황 및 잔여 작업

> 구현 완료분은 `.claude/`(settings·hooks·skills·agents)에 반영되어 있다. 이 문서는 상태 기록이며,
> 기존 블루프린트(구 `docs/quality-gate.md`) 대비 **미구현/부분 구현** 항목을 잔여 작업으로 남긴다.
> 잔여 작업은 별도 컨텍스트에서 진행한다.

## 구현 완료 (`.claude/`)

- **SessionStart** — 브랜치 + NestJS 규칙(컨트롤러 얇게 / DTO class-validator / ConfigService / any 금지) 주입.
- **PreToolUse(Bash) 가드** — `rm -rf /|~|$HOME`, force push, `reset --hard`, **DB DROP/TRUNCATE**(대소문자 무시) 차단.
- **PostToolUse 포맷** — 변경 `*.ts` 에 `prettier --write` + `eslint --fix`, `*.{json,md,yml,yaml}` 에 prettier.
- **Stop 게이트(부분)** — `tsc --noEmit -p tsconfig.json` + `eslint "src/**/*.ts"`. 실패 시 exit 2 로 피드백.
- **code-review 스킬 + code-reviewer 서브에이전트** — git diff 기반 백엔드 리뷰.

## 잔여 (블루프린트 대비 미구현/부분 — 다른 컨텍스트에서 진행)

- [ ] **`/tdd` 스킬** (RED→GREEN→REFACTOR 안내) — 미구현.
- [ ] **Stop 게이트에 테스트 추가** — 현재 `tsc + lint`만. 블루프린트 목표는 `test → lint → prettier --check`.
      유닛(`jest`)만 게이트에 포함하고, e2e(`test:e2e`, DB 의존)는 제외.
- [ ] **Stop 게이트에 `prettier --check` 추가** — 포맷 미적용분도 종료 게이트로 차단.

## 메모

- husky/lint-staged(`*.ts` → eslint --fix + prettier)는 **커밋 시점 안전망**으로 유지(편집·종료 게이트와 보완).
- 매 Stop 마다 풀 `jest`는 지연 → 변경 관련만(`jest --findRelatedTests` / `--onlyChanged`) 또는 lint/format만 게이트로 두는 튜닝 가능.
