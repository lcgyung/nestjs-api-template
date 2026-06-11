# 0005. JWT 를 httpOnly 쿠키로 발급 + Bearer 폴백 + SameSite CSRF

- 상태: 승인
- 날짜: 2026-06-11

## 맥락

시큐어 코딩 체크리스트(`docs/secure-harness-nestjs.md` §2)는 토큰을 `httpOnly` + `Secure` +
`SameSite` 쿠키로 전달할 것을 요구한다(localStorage 지양 — XSS 시 토큰 탈취 방지). 기존 구현은
로그인 응답 바디로 `accessToken` 을 내려주고 `Authorization: Bearer` 헤더로만 검증했다.

다만 이 리포는 *API 템플릿*이라 브라우저 외 클라이언트(모바일 앱·서버 간 호출)도 명시 범위에
포함된다. 쿠키 전용으로 바꾸면 이들 클라이언트가 곤란해진다.

## 결정

쿠키를 **1차 수단으로 채택하되 Bearer 헤더 폴백을 유지**한다.

- 로그인 시 `access_token` 을 `httpOnly` · `SameSite=Strict` 쿠키로 설정한다.
  `Secure` 는 production 에서만 켠다(로컬 http 개발에서도 쿠키가 설정되도록).
- `jwt.strategy` 는 **쿠키 우선 → Bearer 헤더 폴백** 순서로 토큰을 추출한다.
- 쿠키 `maxAge` 는 토큰의 `exp/iat` 차이로 산출한다(별도 env 도입 없이 `JWT_EXPIRES_IN` 과 동기화).
- `POST /auth/logout` 으로 쿠키를 만료시킨다.
- **CSRF**: `SameSite=Strict` 로 크로스사이트 쿠키 전송을 차단한다. Bearer 클라이언트는 자격증명을
  자동 전송하지 않으므로 CSRF 무관. 따라서 `csurf`(deprecated) 없이 체크리스트의 CSRF(🟡) 항목을
  충족한다.

## 결과

- 트레이드오프:
  - 로그인 응답 바디에 여전히 `accessToken` 을 포함한다(폴백 클라이언트용). 브라우저 클라이언트는
    이를 무시하고 쿠키를 쓴다. httpOnly 의 이점은 쿠키 사본에만 적용된다.
  - `Secure` 쿠키가 리버스 프록시 뒤에서 동작하려면 `trust proxy` 가 필요하다(`main.ts` 에서 설정).
- 재검토 트리거:
  - 쿠키 인증 + 상태 변경 API(폼 기반 POST 등)가 늘어나면 `SameSite` 만으로 부족할 수 있다 →
    double-submit 토큰 또는 커스텀 헤더 검증을 추가한다.
  - 토큰 폐기·회전이 필요해지면 refresh 토큰을 도입한다([0006](0006-refresh-토큰-회전-보류.md)).
