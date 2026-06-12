# Architecture Decision Records

코드만 봐서는 알 수 없는 **결정의 근거**를 기록한다. "무엇"은 코드·CLAUDE.md 가 말해주고,
"왜 그렇게(또는 왜 안)"는 여기에 남긴다.

## 작성 규칙

- 파일명: `NNNN-kebab-case-제목.md` (번호 4자리, 한국어 허용).
- 형식: [`template.md`](template.md) (MADR-lite — 상태/날짜/맥락/결정/결과).
- 결정을 뒤집을 땐 기존 ADR 을 수정하지 말고 **폐기 상태로 바꾸고 새 ADR 로 대체**한다.
- 에이전트 가드레일(매 세션 필요한 규칙)은 `CLAUDE.md` 가 정본이다 — ADR 은 그 근거·역사를 보관한다.

## 인덱스

| 번호                                               | 제목                                                      | 상태 |
| -------------------------------------------------- | --------------------------------------------------------- | ---- |
| [0001](0001-adr-도입.md)                           | ADR 도입                                                  | 승인 |
| [0002](0002-의도적-비채택-결정.md)                 | 린트/타입 강화 옵션의 의도적 비채택                       | 승인 |
| [0003](0003-e2e-db-격리-testcontainers-비채택.md)  | e2e DB 격리에 testcontainers 비채택                       | 승인 |
| [0004](0004-openapi-export-datasource-override.md) | OpenAPI 스펙 export — DataSource 스텁 치환 방식           | 승인 |
| [0005](0005-jwt-쿠키-전환-csrf-전략.md)            | JWT httpOnly 쿠키 전환 + Bearer 폴백 + SameSite CSRF      | 승인 |
| [0006](0006-refresh-토큰-회전-보류.md)             | Refresh 토큰 회전·서버측 폐기 보류                        | 승인 |
| [0007](0007-인증-프로파일-분리-자격증명-전략.md)   | 인증 프로파일(MVP/Production) 분리 + 단계적 자격증명 전략 | 승인 |
