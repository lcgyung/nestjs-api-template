---
name: scaffold-module
description: >-
  NestJS 신규 기능 모듈(엔티티 + CRUD)을 스캐폴딩할 때 사용. "새 모듈 만들기", "X 모듈 추가",
  "엔티티/리소스 스캐폴딩", 새 도메인(posts·orders 등) 추가 시 적용. 이 템플릿의 표준 모듈 구조를
  일관되게 복제하기 위한 가이드. 경계: 신규 도메인 모듈을 통째로 만들 때만 — 기존 모듈에 라우트만
  추가/수정하면 api-endpoint, 테스트 우선으로 갈 때의 절차는 tdd 를 쓴다(상호 보완).
---

# 신규 모듈 스캐폴딩

`nest g` 스키매틱은 이 템플릿의 관례(경로 별칭·한국어 메시지·`@Exclude` 엔티티·spec 스타일)와
어긋난다. 대신 **`src/modules/users/`를 살아있는 템플릿으로 읽고 그 구조를 그대로 미러링**한다.
users/ 가 바뀌면 이 지침도 자동으로 따라간다(여기에 파일 전문을 박아두지 않는 이유다).

> 시작 전에 아래 실제 파일에서 각 패턴을 확인하라 — `users` 모듈을 미러링한다.
>
> - 컨트롤러·라우트 관례 → `src/modules/users/users.controller.ts` · `users.controller.spec.ts`
> - DTO·검증 → `src/modules/users/dto/create-user.dto.ts`
> - 서비스·`Repository` 주입·spec(jest mock) → `src/modules/users/users.service.ts` · `users.service.spec.ts`
> - 엔티티·`@Exclude()`·enum → `src/modules/users/entities/user.entity.ts`
> - e2e → `test/app.e2e-spec.ts`

## 생성할 파일 (feature = 새 모듈명, kebab-case)

```text
src/modules/<feature>/
├── <feature>.controller.ts        # thin: 라우팅·DTO 바인딩만
├── <feature>.service.ts           # 비즈니스 로직 + Repository 주입
├── <feature>.module.ts            # TypeOrmModule.forFeature([Entity]) + providers/exports
├── <feature>.controller.spec.ts   # 코로케이트 단위 테스트(서비스 mock — 라우트 위임 검증)
├── <feature>.service.spec.ts      # 코로케이트 단위 테스트(Repository mock)
├── dto/
│   ├── create-<feature>.dto.ts    # class-validator + @ApiProperty
│   └── update-<feature>.dto.ts    # PartialType(CreateDto)
└── entities/
    └── <feature>.entity.ts        # @Entity + 컬럼, 민감 필드 @Exclude
```

## 각 파일이 따라야 할 패턴 (users/ 기준)

- **컨트롤러** → `@ApiTags`/`@Controller('<feature>')`. 전역 가드가 이미 모든 라우트를 보호한다 —
  **`@UseGuards` 재부착 금지**, `@Roles(...)`/`@Public()` 데코레이터만 사용.
  - 각 라우트에 `@ApiOperation`. 로직은 전부 서비스로 위임. `@Param('id', ParseIntPipe)`.
  - **상태 코드 명시**: 생성 라우트에 `@HttpCode(HttpStatus.CREATED)`, 본문 없는 삭제에
    `@HttpCode(HttpStatus.NO_CONTENT)`(204).
- **서비스** → `@InjectRepository(Entity) private readonly repo: Repository<Entity>` 직접 주입(커스텀
  리포지토리 클래스 만들지 않음). 없음→`NotFoundException`, 중복→`ConflictException`, **한국어 메시지**.
  - bcrypt 가공 회차 등 매직넘버는 `private static readonly SALT_ROUNDS = 10` 처럼 **UPPER_CASE 상수**로.
- **엔티티** → `@PrimaryGeneratedColumn`, 민감 컬럼에 `@Exclude()`, `@CreateDateColumn`/`@UpdateDateColumn`,
  필드 정의 단언 `!`. enum 컬럼은 `{ type: 'enum', enum: ... }`. **enum 멤버는 PascalCase**(`Role.User`).
- **DTO** → create 는 `@IsXxx` + `@ApiProperty`/`@ApiPropertyOptional`. update 는 `PartialType(CreateDto)`.
- **spec** → 서비스 spec 은 `getRepositoryToken(Entity)` 를 `useValue` jest mock 으로 제공(예외/핵심 로직),
  컨트롤러 spec 은 서비스를 mock 해 라우트별 위임/인자 전달을 검증한다. **여기에 모듈별 e2e
  (`test/<feature>.e2e-spec.ts`)까지 더한 3종이 "완성"의 정의**다 — 정본 `.claude/rules/testing.md`.
- **모듈** → `imports: [TypeOrmModule.forFeature([Entity])]`, service `providers`/`exports`.
  생성 후 `AppModule`(또는 상위 모듈) `imports` 에 새 모듈을 등록한다.

## 엔드포인트 규약

라우트/서비스 메서드의 **응답 형태·페이지네이션·예외 타입·직렬화**는 정본
`docs/api-conventions.md`(`api-endpoint` 스킬이 절차 래퍼)를 그대로 적용한다.

## 마무리

- 새 모듈을 상위 모듈 `imports` 에 등록했는지 확인.
- **테스트 3종**(service spec · controller spec · `test/<feature>.e2e-spec.ts`)을 갖췄는지 확인 —
  `pnpm check:api-tests` 가 변경분 한정으로 강제한다(Stop 게이트).
- `pnpm lint` · `pnpm typecheck` · `pnpm test` · `pnpm test:e2e` · `pnpm build` 통과 확인.
