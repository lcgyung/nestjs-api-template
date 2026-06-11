# 0003. e2e DB 격리에 testcontainers 비채택

- 상태: 폐기 ([0009](0009-e2e-testcontainers-도입.md) 로 대체)
- 날짜: 2026-06-11

## 맥락

하네스 체크리스트(`docs/harness-nestjs.md`)는 e2e 테스트 DB 격리에 testcontainers 를 권장한다.
현재 e2e 는 `test/app.e2e-spec.ts` 단일 스위트이며, CI 의 `e2e` 잡이 GitHub Actions
service container(MySQL 8.0)에 migration:run → seed 후 실행한다(`RUN_E2E=true` 게이트).

## 결정

testcontainers 를 도입하지 않는다.

- CI 는 이미 **런마다 깨끗한 MySQL** 을 확보한다 — 격리의 핵심 목적은 달성됨.
- e2e 스위트가 1개뿐이라 스위트별/병렬 DB 격리 수요 자체가 없다.
- `@testcontainers/mysql` 의존성 + 스위트별 컨테이너 기동은 e2e 시간만 늘리고
  템플릿 미니멀리즘과 상충한다.

## 결과

- 트레이드오프: 로컬 e2e 가 dev DB(docker-compose `app`)를 오염시킬 수 있다 —
  필요해지면 testcontainers 없이도 `app_test` DB + `.env.test` 로 해결 가능(후속 과제).
- 재검토 트리거: e2e 스위트 다수화, 병렬 실행, 스키마 단위 격리 필요.
