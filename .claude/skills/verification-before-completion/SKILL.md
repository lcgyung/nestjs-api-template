---
name: verification-before-completion
description: >-
  "완료"를 선언하기 전에 Stop 게이트가 자동으로 못 잡는 항목을 직접 검증하는 체크리스트. "다 됐어",
  "마무리", "PR 전에 확인", "끝내기 전에 검증", 작업을 마쳤다고 보고하기 직전에 적용. 경계: 자동
  게이트(tsc·lint·유닛)를 대체하지 않는다 — 게이트가 제외하는 e2e·동작 확인·스펙 드리프트를 챙긴다.
---

# 완료 전 검증

**Stop 게이트 통과 = 완성이 아니다.** 게이트는 정적 검사(`tsc`·`lint`·`prettier --check`)와
`check:migrations`·`check:api-tests`·유닛 `jest`(+ 헤드리스 리뷰)를 강제하지만, **e2e 는 기본 제외**
(옵트인 `CC_E2E_GATE=1`; PR 은 CI 가 강제)이고 **실제 동작 확인도 제외**한다.
완료를 보고하기 전에 아래를 직접 확인한다.

## 체크리스트

1. **동작이 실제로 맞는가** — 테스트가 "통과"만 하는 게 아니라 의도한 동작을 실제로 덮는지 확인한다.
   바꾼 코드가 의도대로 작동하는 경로를 한 번은 실행/관측한다.
2. **e2e (로컬 게이트 기본 제외)** — 컨트롤러/라우트/가드를 만졌으면 해당 모듈 e2e 를 직접 돌린다(또는 `CC_E2E_GATE=1`).
   ```bash
   pnpm test:e2e        # testcontainers PG 자동 기동 (Docker 데몬 필요)
   ```
3. **API 계약 드리프트** — 컨트롤러·DTO·라우트를 바꿨으면 OpenAPI 를 재생성·커밋한다
   (안 하면 CI 와 pre-commit 이 `git diff --exit-code` 로 차단).
   ```bash
   pnpm openapi:generate   # docs/openapi.json 갱신 → 함께 커밋
   ```
4. **테스트 3종 (blocker)** — 컨트롤러를 가진 모듈은 service spec + controller spec + 모듈별 e2e 가
   모두 있어야 "완성"이다(정본 `.claude/rules/testing.md`).
   ```bash
   pnpm check:api-tests    # 변경분 한정 — 누락 시 미완성
   ```
5. **마이그레이션** — 엔티티를 바꿨으면 생성→검토→`migration:run` 까지. `up()` 의 파괴적 DDL 은
   의도라면 `// migration-safety-ack: <사유>` 주석으로 승인(아니면 `check:migrations` 가 차단).
6. **오염(선택)** — 경쟁 패턴/dead code/unused export 를 남기지 않았는지 본다(`pnpm knip`,
   정본 `.claude/rules/pattern-contamination.md`).

## 보고

점검 결과를 표로 남기고, **미충족 항목이 하나라도 있으면 "완료"로 선언하지 않는다.**

| 항목             | 결과           |
| ---------------- | -------------- |
| 동작 확인        | ✅/❌          |
| e2e              | ✅/❌/해당없음 |
| openapi 드리프트 | ✅/❌/해당없음 |
| 테스트 3종       | ✅/❌          |
| 마이그레이션     | ✅/❌/해당없음 |

<!-- obra/superpowers (MIT) 의 verification-before-completion 을 이 템플릿(NestJS) 컨벤션에 맞게 각색 -->
