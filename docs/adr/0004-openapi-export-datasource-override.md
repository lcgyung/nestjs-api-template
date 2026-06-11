# 0004. OpenAPI 스펙 export — DataSource 스텁 치환 방식

- 상태: 승인
- 날짜: 2026-06-11

## 맥락

OpenAPI 스펙을 파일(`docs/openapi.json`)로 export 해 프론트 타입 생성(orval /
openapi-typescript)의 소스로 쓰고, CI 에서 드리프트를 막아야 한다. 문제는 CI 의
`lint-build-test` 잡에 DB 가 없는데, `DatabaseModule` 의 `TypeOrmModule.forRootAsync` 가
모듈 인스턴스화 시점에 실제 MySQL 연결(`dataSource.initialize()`)을 수행한다는 것.

검토한 대안:

1. **main.ts 분기**(`GENERATE_OPENAPI=1` 류) — DB 연결·listen·프로세스 종료 관리가 필요해
   CI 부적합.
2. **Swagger 전용 모듈 재조립** — `forFeature` 리포지토리 의존성 때문에 모듈 그래프를
   중복 유지해야 해 드리프트 위험.
3. **`@nestjs/testing` + `overrideProvider(getDataSourceToken())` 스텁** — 데코레이터
   메타데이터를 전부 유지하면서 DB 무연결.

## 결정

3안을 채택한다 (`scripts/generate-openapi.ts`).

- 스텁은 리포지토리 팩토리(`options.type` 체크 + `getRepository`)와 `EntityManager`
  프로바이더(`manager` 접근)가 요구하는 표면만 충족한다.
- `init()` 은 호출하지 않는다(실연결 전제 훅 회피). Swagger 문서 생성은 메타데이터 스캔만
  필요하다.
- DocumentBuilder 설정은 `src/config/swagger.config.ts` 로 추출해 main.ts 와 공유한다.
- CI 게이트: `pnpm openapi:generate && git diff --exit-code -- docs/openapi.json`.

## 결과

- 트레이드오프: TypeOrmModule 내부 프로바이더 표면에 의존 — `@nestjs/typeorm` 메이저 업그레이드
  시 스텁이 깨질 수 있다(스크립트 실패로 즉시 드러남).
- 재검토 트리거: Nest/TypeORM 메이저 업그레이드로 스텁 표면 변경, 또는 공식 무연결 문서 생성
  지원 등장.
