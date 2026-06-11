---
paths:
  - 'src/**/dto/**'
  - 'src/**/*.dto.ts'
  - 'src/**/*.entity.ts'
---

# DTO 검증 / 직렬화 규칙

## 입력 DTO

- 모든 입력 필드에 class-validator 데코레이터를 단다. 데코레이터 없는 필드는
  `forbidNonWhitelisted` 에 걸려 400 이 나거나, whitelist 에 의해 잘려 나간다.
- 수정 DTO 는 `PartialType(CreateXxxDto)` 를 유지한다(개별 재선언 금지).
- **bcrypt 비밀번호 필드**는 `@MinLength(8)` + `@MaxLength(72)`(bcrypt 72바이트 한계)를 **쌍으로**
  건다. 비밀번호를 받는 모든 DTO(생성·로그인 등)에 일관 적용.

```typescript
export class CreateUserDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;
}
```

## 엔티티 직렬화

- **새 엔티티에 비밀/토큰 등 민감 필드를 추가하면 반드시 `@Exclude()` 를 붙인다**
  (예: `User.password`). 전역 `ClassSerializerInterceptor` 가 응답에서 제거한다.
- 엔티티 필드의 `!`(definite assignment)는 TypeORM/검증이 런타임에 채우는 값이라 의도적이다 —
  제거 금지(ADR 0002).

## ValidationPipe 옵션 정본

- 전역 `ValidationPipe` 옵션의 정본은 `src/common/pipes/validation-pipe.options.ts`
  (`VALIDATION_PIPE_OPTIONS`) — **main.ts 와 e2e 가 공유하므로 한쪽만 고치지 말 것.**
  `whitelist` + `forbidNonWhitelisted`(DTO 에 없는 필드는 silent strip 이 아니라 400) + `transform`.
- 응답 DTO 수동 매핑 금지 등 직렬화 정본: `docs/api-conventions.md` §5.
