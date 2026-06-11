---
name: scaffold-module
description: >-
  NestJS 신규 기능 모듈(엔티티 + CRUD)을 스캐폴딩할 때 사용. "새 모듈 만들기", "X 모듈 추가",
  "엔티티/리소스 스캐폴딩", 새 도메인(posts·orders 등) 추가 시 적용. 이 템플릿의 표준 모듈 구조를
  일관되게 복제하기 위한 가이드.
---

# 신규 모듈 스캐폴딩

`nest g` 스키매틱은 이 템플릿의 관례(경로 별칭·한국어 메시지·`@Exclude` 엔티티·spec 스타일)와
어긋난다. 대신 **`src/modules/users/`를 살아있는 템플릿으로 읽고 그 구조를 그대로 미러링**한다.
users/ 가 바뀌면 이 지침도 자동으로 따라간다(여기에 파일 전문을 박아두지 않는 이유다).

> 시작 전에 `src/modules/users/` 의 실제 파일들을 읽어 현재 패턴을 확인하라.

## 생성할 파일 (feature = 새 모듈명, kebab-case)

```text
src/modules/<feature>/
├── <feature>.controller.ts        # thin: 라우팅·DTO 바인딩만
├── <feature>.service.ts           # 비즈니스 로직 + Repository 주입
├── <feature>.module.ts            # TypeOrmModule.forFeature([Entity]) + providers/exports
├── <feature>.service.spec.ts      # 코로케이트 단위 테스트
├── dto/
│   ├── create-<feature>.dto.ts    # class-validator + @ApiProperty
│   └── update-<feature>.dto.ts    # PartialType(CreateDto)
└── entities/
    └── <feature>.entity.ts        # @Entity + 컬럼, 민감 필드 @Exclude
```

## 각 파일이 따라야 할 패턴 (users/ 기준)

- **컨트롤러** → `@ApiTags`/`@Controller('<feature>')`, 보호가 필요하면 `@UseGuards(JwtAuthGuard, RolesGuard)`
  - `@Roles(...)`, 각 라우트에 `@ApiOperation`. 로직은 전부 서비스로 위임. `@Param('id', ParseIntPipe)`.
  - **상태 코드 명시**: 생성 라우트에 `@HttpCode(HttpStatus.CREATED)`, 본문 없는 삭제에
    `@HttpCode(HttpStatus.NO_CONTENT)`(204).
- **서비스** → `@InjectRepository(Entity) private readonly repo: Repository<Entity>` 직접 주입(커스텀
  리포지토리 클래스 만들지 않음). 없음→`NotFoundException`, 중복→`ConflictException`, **한국어 메시지**.
  - bcrypt 가공 회차 등 매직넘버는 `private static readonly SALT_ROUNDS = 10` 처럼 **UPPER_CASE 상수**로.
- **엔티티** → `@PrimaryGeneratedColumn`, 민감 컬럼에 `@Exclude()`, `@CreateDateColumn`/`@UpdateDateColumn`,
  필드 정의 단언 `!`. enum 컬럼은 `{ type: 'enum', enum: ... }`. **enum 멤버는 PascalCase**(`Role.User`).
- **DTO** → create 는 `@IsXxx` + `@ApiProperty`/`@ApiPropertyOptional`. update 는 `PartialType(CreateDto)`.
- **spec** → `getRepositoryToken(Entity)` 를 `useValue` jest mock 으로 제공. 예외/핵심 로직 케이스 검증.
- **모듈** → `imports: [TypeOrmModule.forFeature([Entity])]`, service `providers`/`exports`.
  생성 후 `AppModule`(또는 상위 모듈) `imports` 에 새 모듈을 등록한다.

## 엔드포인트 규약 정본은 docs/api-conventions.md

라우트/서비스 메서드의 **응답 형태·페이지네이션·예외 타입·직렬화**는 `docs/api-conventions.md`
(정본, `api-endpoint` 스킬이 절차 래퍼)를 따른다.
특히 목록 라우트는 `PaginationQueryDto` + `PaginatedResponseDto<T>`(`{ items, meta }`)로 만든다.

## 마무리

- 새 모듈을 상위 모듈 `imports` 에 등록했는지 확인.
- `pnpm lint` · `pnpm typecheck` · `pnpm test` · `pnpm build` 통과 확인.
