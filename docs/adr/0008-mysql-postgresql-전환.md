# 0008. MySQL → PostgreSQL 전환

- 상태: 승인
- 날짜: 2026-06-11

## 맥락

하네스 점검(`docs/cc-harness-nestjs.md`)을 정본으로 삼아 하네스 v2 작업을 진행하면서,
이 템플릿의 실제 사용처(ThinkSeed 등)가 PostgreSQL 기반으로 결정되었다. 템플릿의 DB 가
실사용 환경과 다르면 마이그레이션·시드·e2e·db-reader(psql) 등 하네스 전반이 이중 기준이 된다.

## 결정

DB 를 MySQL 8.0 에서 **PostgreSQL 17** 로 전면 전환한다.

- `docker-compose.yml`: `postgres:17-alpine` + `pg_isready` healthcheck
- 드라이버: `mysql2` → `pg`(+`@types/pg`)
- `data-source.ts`/`database.module.ts`: `type: 'postgres'`, 기본 포트 5432, 기본 사용자 `postgres`
- `scripts/generate-openapi.ts` DataSource 스텁의 `options.type` 도 `postgres` 로 일치(ADR 0004 의
  forFeature 팩토리가 type 을 체크하므로 불일치 시 `openapi:generate` 가 실패한다)
- CI e2e 잡: service container 를 PostgreSQL 로 교체(이후 testcontainers 전환 — ADR 0009)

## 결과

- **마이그레이션 히스토리 리셋**: 기존 MySQL 문법(백틱·`AUTO_INCREMENT`·`ENGINE=InnoDB`)
  마이그레이션을 삭제하고 PG 기준으로 재생성했다. 이 템플릿은 운영 DB 가 없다는 전제이며,
  기존 로컬 MySQL 볼륨은 폐기한다(`docker volume rm`).
- **enum 은 별도 TYPE**: PG 에서 `role` enum 은 `users_role_enum` TYPE 으로 생성된다. 값 추가는
  `ALTER TYPE ... ADD VALUE`, down 에서는 테이블과 함께 `DROP TYPE` 까지 제거해야 가역적이다
  (초기 마이그레이션에 반영됨).
- **`@UpdateDateColumn` 동작 차이**: MySQL 의 `ON UPDATE CURRENT_TIMESTAMP` 에 대응하는 DDL 이
  PG 엔 없다. TypeORM 이 `save()` 시 앱 레벨에서 갱신하므로 ORM 경로 동작은 동일하지만,
  raw SQL `UPDATE` 로는 `updatedAt` 이 갱신되지 않는다(raw SQL 금지 규칙이 이를 보완).
- 재검토 트리거: 사용처에서 MySQL 요구가 생기면 멀티 DB 지원이 아니라 별도 브랜치/포크로 대응.
