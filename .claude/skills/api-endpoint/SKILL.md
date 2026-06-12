---
name: api-endpoint
description: >-
  NestJS API 엔드포인트(컨트롤러 라우트·서비스 메서드)를 새로 만들거나 수정할 때의 응답 형태·
  페이지네이션·예외 타입·DTO/직렬화 규약. 목록(list) API, CRUD 라우트, @Get/@Post/@Patch/@Delete
  추가, PaginationQueryDto 사용, "엔드포인트 추가/수정", "응답 형태", "페이지네이션" 작업 시 적용.
---

# API 엔드포인트 구현 규약 (운영 체크리스트)

이 스킬이 이 템플릿의 **API 응답·예외·DTO 규약 정본**이다(엔드포인트 작업 시 자동 로드).
기준 예시(정답 코드)는 `src/modules/users/`(컨트롤러·서비스·DTO)와 `src/common/dto/`다.

## 1. 응답 형태

- **단건 / 생성 / 수정 / `me`** → **엔티티를 직접 반환**한다. 전역 `ClassSerializerInterceptor`가
  `@Exclude()` 필드(예: password)를 제거한다. **`{ data: ... }` 래핑 금지.**
- **목록(list)** → 반드시 `PaginatedResponseDto<T>`(`{ items, meta }`)로 반환한다.
  bare 배열(`T[]`)·`{ data }`·`{ results }` 금지.
- 전역 `{ data }` 래핑은 **도입하지 않는다**(보일러플레이트·Swagger 타입 비용만 늘고 REST 관용도 깨짐).

## 2. 페이지네이션 (모든 목록 엔드포인트)

- 쿼리는 공용 `@/common/dto/pagination-query.dto` 의 `PaginationQueryDto`를 `@Query()`로 받는다
  (기본 `page=1`/`limit=20`, `limit` 최대 100).
- 서비스는 `findAndCount({ skip, take, order })`로 조회하고
  `new PaginatedResponseDto(items, total, query)`를 반환한다.

```ts
// service
async findAll(query: PaginationQueryDto): Promise<PaginatedResponseDto<User>> {
  const [items, total] = await this.repo.findAndCount({
    skip: (query.page - 1) * query.limit,
    take: query.limit,
    order: { id: 'DESC' },
  });
  return new PaginatedResponseDto(items, total, query);
}

// controller
@Get()
findAll(@Query() query: PaginationQueryDto): Promise<PaginatedResponseDto<User>> {
  return this.service.findAll(query);
}
```

## 3. 예외 타입 (빌트인 HttpException, 커스텀 클래스 금지)

| 상황                      | 예외                              | 코드 |
| ------------------------- | --------------------------------- | ---- |
| 입력 형식/타입 오류       | `BadRequestException` (대개 자동) | 400  |
| 인증 실패(토큰 없음/만료) | `UnauthorizedException`           | 401  |
| 권한 없음                 | `ForbiddenException`              | 403  |
| 리소스 없음               | `NotFoundException`               | 404  |
| 중복/상태 충돌            | `ConflictException`               | 409  |
| 형식 OK·의미상 처리 불가  | `UnprocessableEntityException`    | 422  |

- 메시지는 **사용자에게 보여줄 한국어 문장**. 내부 구현/스택/원시 DB 오류를 노출하지 않는다.
- 커스텀 예외 클래스 계층은 도메인이 복잡해지기 전까지 만들지 않는다. 머신리더블 `code` 필드는 기본 미도입
  (클라이언트가 메시지 대신 코드로 분기해야 할 때만 도입).

## 4. 쿼리 / 관계

- 목록 = `findAndCount` + `PaginationQueryDto`. 무한정 `find()` 지양.
- 정렬/필터는 **화이트리스트**(enum/맵)로만 수용. 클라이언트 컬럼명을 `order`/`where`에 직접 넣지 않는다.
- 복잡 쿼리는 `QueryBuilder`로 **서비스 계층**에. 관계는 `relations`로 **명시적** 로딩(엔티티 `eager: true` 금지).
- soft-delete가 필요한 엔티티는 `@DeleteDateColumn` + `softRemove()`/`withDeleted` 규칙을 따른다(현재 `User`는 hard delete).

## 5. DTO / 직렬화

- 기본은 **엔티티 반환 + `@Exclude()`/`@Expose()` + 전역 직렬화**. 응답 DTO로 **수동 매핑하지 않는다.**
- 엔티티와 응답 형태가 실제로 다를 때만 Response DTO 도입 →
  `plainToInstance(Dto, entity, { excludeExtraneousValues: true })`.
- 입력은 항상 DTO + class-validator. 수정 DTO는 `PartialType` 유지.

## 마무리

- 검증: `pnpm build` · `pnpm lint` · `pnpm test`. 목록은 `GET /...?page=1&limit=10`으로 `{ items, meta }` 확인.
- 신규 모듈 전체를 만드는 경우 `scaffold-module` 스킬을 함께 본다.
