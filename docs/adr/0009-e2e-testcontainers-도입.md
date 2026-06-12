# 0009. e2e DB 격리에 testcontainers 도입

- 상태: 승인
- 날짜: 2026-06-11
- 대체: [0003](0003-e2e-db-격리-testcontainers-비채택.md)

## 맥락

ADR 0003 은 "CI service container 가 이미 깨끗한 DB 를 보장하고, e2e 스위트가 1개뿐"이라는
이유로 testcontainers 를 비채택했다. 이후 두 가지가 바뀌었다:

1. 하네스 점검(`docs/cc-harness-nestjs.md`)을 정본으로 삼는 하네스 v2 작업에서
   `rules/testing`·`write-e2e` 스킬이 testcontainers 격리를 전제한다.
2. PostgreSQL 전환(ADR 0008)으로 e2e/CI DB 셋업을 어차피 전부 재작성하게 되어
   도입 한계비용이 가장 낮은 시점이었다.

또한 0003 이 감수했던 트레이드오프(로컬 e2e 가 dev DB 를 오염)가 그대로 남아 있었다.

## 결정

`@testcontainers/postgresql` 로 e2e DB 를 격리한다.

- `test/global-setup.ts`: PG 17 컨테이너 기동 → `process.env.DB_*` 주입(jest globalSetup 은
  워커 fork 전에 실행되므로 전 워커에 전파) → **CI 와 동일한 CLI 경로**(`pnpm migration:run`
  → `pnpm seed`)로 스키마·시드 준비. colima 소켓 자동 인식 폴백 포함(Docker Desktop·CI no-op).
- `test/global-teardown.ts`: 컨테이너 정지.
- CI e2e 잡: `services` 블록·DB env·마이그레이션/시드 스텝 제거. `RUN_E2E=true` 게이트는 유지
  (기본 파이프라인 비용·시간 보호).

### 비자명한 구현 결정 — globalSetup 에서 ts-node 훅을 등록하지 않는다

globalSetup 프로세스에 `ts-node/register` 를 등록하면 Jest 트랜스포머(ts-jest)와 require 훅이
겹쳐 globalTeardown 파일이 **이중 컴파일**(TS→JS 출력을 다시 TS 로 컴파일)되어 가짜 타입
에러(TS7017)가 난다. 그래서 TypeORM 글롭 로딩(엔티티/마이그레이션 .ts) 대신 자식 프로세스
CLI(`pnpm migration:run`/`pnpm seed`)를 실행한다 — CI·로컬과 완전히 같은 경로라는 부수 이점.

## 결과

- 로컬 e2e 가 dev DB(docker-compose)와 완전히 분리된다. compose DB 가 꺼져 있어도 동작.
- e2e 실행마다 컨테이너 기동 비용(이미지 캐시 후 수 초)이 추가된다.
- e2e 를 돌리는 모든 환경에 Docker(또는 colima 등 호환 런타임)가 필요하다.
- 재검토 트리거: e2e 가 Docker 없는 환경에서 필요해지면 `app_test` DB + `.env.test` 폴백 추가.
