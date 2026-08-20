---
paths:
  - 'src/**/*.controller.ts'
---

# 컨트롤러 규칙

- **thin controller** — 라우팅·DTO 바인딩·상태 코드 지정만. 비즈니스 로직(조건 분기·조회 조합·
  트랜잭션)은 전부 서비스로 위임한다.
- **전역 가드 전제** — `JwtAuthGuard`/`RolesGuard` 가 전역 `APP_GUARD` 로 모든 라우트를 보호하므로
  **컨트롤러에 `@UseGuards(JwtAuthGuard)` 재부착 금지**; `@Public()`·`@Roles(Role.Admin)`·`@CurrentUser()`
  만 쓴다. deny-by-default·소유권(IDOR) 등 인가 정책 정본은 `.claude/rules/auth.md`.
- **상태 코드 명시** — 생성 `@HttpCode(HttpStatus.CREATED)`, 본문 없는 삭제
  `@HttpCode(HttpStatus.NO_CONTENT)`. 조회/수정은 기본 200.
- **Swagger** — 컨트롤러에 `@ApiTags`, 라우트 변경 시 `pnpm openapi:generate` 재생성 후 함께 커밋.
- 응답 형태·페이지네이션·예외 매핑 등 정본: `docs/api-conventions.md`.

```typescript
// 전역 가드가 보호하므로 @UseGuards 불필요. 인증된 사용자는 @CurrentUser 로 주입.
@Get('me')
getMe(@CurrentUser() user: User) {
  return user;
}
```
