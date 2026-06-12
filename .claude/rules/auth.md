---
paths:
  - 'src/modules/**'
  - 'src/common/guards/**'
  - 'src/common/decorators/**'
---

# 인증 / 인가 규칙

## 인증 (JWT)

- 비밀번호는 bcrypt 해싱, 평문/해시를 응답에 노출하지 않는다(`User.password` 는 `@Exclude()`).
- 토큰은 **httpOnly 쿠키(`access_token`)로 발급**하고 `jwt.strategy` 가 쿠키 우선·Bearer 헤더
  폴백으로 추출한다(모바일·서버 간 호출 유지 — ADR 0005).
- 로그인은 전용 `@Throttle`(분당 5)로 brute-force 완화, 성공/실패는 이메일 마스킹 감사 로그.

## 인가 (deny-by-default)

- `JwtAuthGuard`·`RolesGuard` 가 `app.module.ts` 전역 `APP_GUARD` 로 등록되어 **모든 라우트를
  기본 보호**한다(가드 순서: Throttler → JwtAuth → Roles).
- 인증 없이 열 라우트만 `@Public()` 명시(로그인·로그아웃·health). 역할 제한은 `@Roles(Role.Admin)`.
- **컨트롤러에 `@UseGuards(JwtAuthGuard)` 를 다시 붙이지 말 것.**

## 소유권 검증 (IDOR/BOLA 방지) — 필수 패턴

본인 리소스만 접근하는 엔드포인트는 **서비스 계층에서 소유권을 반드시 확인**한다:

```typescript
async findOwn(id: number, currentUser: User): Promise<Order> {
  const order = await this.repo.findOne({ where: { id } });
  if (!order) throw new NotFoundException('주문을 찾을 수 없습니다.');
  // 소유권 검증 없이 findOne 결과를 그대로 반환하지 않는다(IDOR)
  if (order.userId !== currentUser.id) {
    throw new ForbiddenException('본인의 주문만 조회할 수 있습니다.');
  }
  return order;
}
```

- 존재 자체를 숨겨야 하면 `ForbiddenException` 대신 `NotFoundException`.
- admin 전용 라우트는 `@Roles(Role.Admin)` 만으로 충분(소유권 표면 없음).
- **권한 시나리오는 e2e 로 검증한다** — 토큰 없음 401, 타 유저/롤 403 (`test/app.e2e-spec.ts` 참고).
- 응답·예외 규약 정본: `docs/api-conventions.md` §6.
