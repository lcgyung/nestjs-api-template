# 위협 모델 — NestJS API Template

> 이 템플릿의 보안 가정·자산·신뢰 경계와 STRIDE 위협별 완화책을 정리한다. 구현 정본은 코드와
> [`secure-harness-nestjs.md`](secure-harness-nestjs.md) 체크리스트이며, 이 문서는 "왜 이 통제가
> 필요한가"를 잇는다. 새 도메인/엔드포인트를 추가할 때 이 표의 가정이 깨지지 않는지 확인한다.

## 자산 (Assets)

- 사용자 자격증명(이메일·bcrypt 해시 비밀번호)
- 세션 토큰(JWT access token) — httpOnly 쿠키 / Bearer
- 사용자 PII(이메일·이름)와 역할(RBAC)
- 환경 비밀(JWT_SECRET, DB 자격증명)

## 신뢰 경계 (Trust Boundaries)

```
[브라우저/모바일/외부 서버]  ──TLS──▶  [리버스 프록시/LB]  ──▶  [NestJS 앱]  ──▶  [MySQL]
        (신뢰 안 함)                    (trust proxy 1단계)      (신뢰)        (신뢰)
```

- 경계 1: 클라이언트 ↔ 앱 — 모든 입력은 검증 전까지 적대적이라고 가정.
- 경계 2: 앱 ↔ DB — 파라미터화 쿼리(TypeORM)로만 접근, raw 보간 금지.
- 경계 3: 앱 ↔ 환경(시크릿) — 부팅 시 스키마 검증(fail-fast), 리포에 시크릿 금지.

## STRIDE 위협 ↔ 완화 매핑

| 위협 (STRIDE)              | 시나리오                            | 완화책 (구현 위치)                                                                          |
| -------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------- |
| **S**poofing (위장)        | 자격증명 도용·무차별 대입           | bcrypt 해싱; 로그인 `@Throttle`(분당 5); JWT 서명 검증(`jwt.strategy`); 감사 로그           |
| **T**ampering (변조)       | 요청 본문 조작·Mass Assignment      | 전역 `ValidationPipe`(`whitelist`+`forbidNonWhitelisted`); DTO + class-validator            |
| **R**epudiation (부인)     | 로그인 시도 추적 불가               | 로그인 성공/실패 감사 로그(이메일 마스킹) + requestId 전파(winston)                         |
| **I**nformation Disclosure | 비밀번호/스택/PII 노출              | `@Exclude()`+`ClassSerializerInterceptor`; 예외 필터 500 스택 비노출; 로그 마스킹           |
| **D**enial of Service      | 과대 본문·요청 폭주                 | body limit 100kb; `ThrottlerModule`(전역) + 로그인 전용 강화 throttle                       |
| **E**levation of Privilege | 타 역할/리소스 무단 접근(IDOR/BOLA) | deny-by-default 전역 `JwtAuthGuard` + `@Public()`; `RolesGuard`/`@Roles`; 소유권 검증(아래) |

## 잔여 위험 / 의도적 보류

- **토큰 강제 폐기 불가** — refresh 토큰 회전·블랙리스트 미도입([ADR 0006](adr/0006-refresh-토큰-회전-보류.md)).
  탈취된 access 토큰은 만료까지 유효. 완화: `JWT_EXPIRES_IN` 단축.
- **객체 소유권(IDOR)** — 현재 `users` 라우트는 전부 admin 전용이라 소유권 표면이 없다. **일반 사용자가
  자기 리소스만 접근하는 도메인을 추가하면**, 서비스 계층에서 "이 리소스가 이 유저의 것인가"를 반드시
  확인한다(없으면 `ForbiddenException`/`NotFoundException`). 규약 정본은 `api-endpoint` 스킬.
- **CSRF** — 쿠키 경로는 `SameSite=Strict` 로 차단([ADR 0005](adr/0005-jwt-쿠키-전환-csrf-전략.md)).
  쿠키 인증 기반 상태 변경 폼이 늘면 double-submit 토큰 재검토.
- **인프라 통제** — TLS 종료, 시크릿 매니저(Vault 등), 브랜치 보호, 컨테이너 스캔은 배포 환경의 책임
  (체크리스트에 사유와 함께 보류 표기).
