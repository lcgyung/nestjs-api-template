---
name: systematic-debugging
description: >-
  버그·실패 원인을 추측 패치 대신 근본원인부터 추적하는 절차. "왜 안 되지", "디버깅", "테스트가
  실패한다", "원인 찾아줘", "재현이 안 된다", 예외/스택트레이스 분석 시 적용. 증상만 덮지 말고
  재현→범위 좁히기→근본원인→회귀 검증의 한 사이클을 돈다. 경계: 테스트를 약화시켜 통과시키는 것은
  디버깅이 아니다 — 테스트 우선 구현은 tdd, 의미적 규약 점검은 code-review 를 함께 본다.
---

# 체계적 디버깅 (재현 → 좁히기 → 근본원인 → 회귀)

추측으로 코드를 바꾸지 않는다. **관측 → 가설 → 검증**의 작은 루프를 돈다. 한 번에 가설 하나만.

## 1. 재현 — 가장 작은 실패 케이스를 고정

먼저 실패를 **재현 가능한 최소 단위**로 못 박는다(없으면 디버깅이 아니라 추측이다). RED 를
새로 쓰는 게 빠르면 `tdd` 스킬로 실패 테스트부터 만든다.

```bash
pnpm exec jest -t "<실패하는 케이스명>"                  # 테스트명으로 단일 케이스
pnpm exec jest src/modules/<m>/<m>.service.spec.ts      # 단일 파일
pnpm test:watch                                         # 좁히는 동안 워치 루프
pnpm test:e2e                                           # e2e 경로 재현 (testcontainers — Docker 데몬 필요)
```

"기대대로 실패"인지 확인한다 — 오타·설정 오류로 인한 실패면 재현이 잘못된 것이다.

## 2. 범위 좁히기 — 추측 대신 관측

- **스택트레이스를 끝까지 읽는다.** 첫 줄이 아니라 우리 코드의 마지막 프레임이 단서다.
- **요청 흐름 추적** — 모든 로그에 `RequestIdMiddleware`(AsyncLocalStorage)가 넣은 **request id**
  가 자동 주입된다(Winston format). 같은 id 로 컨트롤러→서비스→리포지토리 경로를 따라간다.
- **에러는 표준화되어 있다** — Global Exception Filter 가 모든 예외를 표준 형식으로 변환하므로,
  실제 throw 지점은 필터 이전(서비스/가드/파이프)에 있다. statusCode 로 계층을 좁힌다
  (401/403=가드, 400=ValidationPipe/DTO, 404/409=서비스 도메인 예외).
- 이분 탐색: 입력을 반으로 줄이거나, 의심 구간을 잠시 우회해 **원인이 위/아래 어디인지**만 가른다.

## 3. 근본원인 — 증상이 아니라 원인

- "이 한 줄을 바꾸니 통과"에서 멈추지 말고 **왜** 그랬는지 설명할 수 있어야 한다.
- 흔한 원인 계층: DTO 검증 경로(env 명시변환 vs 요청 implicit 변환 차이), TypeORM 관계/지연로딩,
  전역 가드 순서(Throttler→JwtAuth→Roles, deny-by-default), 경로 별칭(`@/*` 3곳 설정) 불일치.
- 불확실하면 `db-reader` 에이전트로 데이터 상태를 읽어(읽기 전용 SELECT) 가설을 검증한다.

## 4. 수정 + 회귀 검증

- 1번에서 고정한 실패 케이스가 **GREEN** 이 되는지 먼저 확인한다.
- 테스트·타입을 약화시켜 통과시키지 않는다(그건 버그를 숨기는 것).
- 회귀 확인:

```bash
pnpm test                 # 유닛 전체 (*.spec.ts)
pnpm test:e2e             # 동작 경로를 바꿨으면 관련 e2e 까지
```

- 마무리 전 `verification-before-completion` 체크리스트로 게이트 밖 항목(e2e·openapi 등)을 점검한다.

<!-- obra/superpowers (MIT) 의 systematic-debugging 을 이 템플릿(NestJS) 컨벤션에 맞게 각색 -->
