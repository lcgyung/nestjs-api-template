# 0006. Refresh 토큰 회전·서버측 폐기 보류

- 상태: 승인
- 날짜: 2026-06-11

## 맥락

시큐어 코딩 체크리스트(`docs/secure-harness-nestjs.md` §2)는 짧은 access 토큰 + refresh 토큰
회전(rotation) + 서버측 폐기(블랙리스트/세션 무효화)를 🔴 필수로 제시한다. 현재 구현은
access 토큰 단일(기본 `JWT_EXPIRES_IN=1d`)이며 서버측 폐기 수단이 없다.

## 결정

이번 보안 강화 작업에서는 refresh 토큰 회전·폐기를 **도입하지 않는다.**

- refresh 토큰은 저장소(엔티티 + 마이그레이션), 회전·재사용 감지(reuse detection), 폐기 목록,
  `/auth/refresh`·`/auth/logout-all` 엔드포인트까지 **별도 기능 규모**의 작업이다. 쿠키 전환·
  deny-by-default·CI 게이트 등 이번 범위와 묶으면 리뷰 단위가 비대해진다.
- 현재는 access 토큰 만료를 짧게 가져가는 운영 정책(`JWT_EXPIRES_IN` 단축)으로 위험을 일부 완화할
  수 있다.

## 결과

- 트레이드오프: 탈취된 access 토큰을 만료 전 강제 폐기할 수 없다. 로그아웃은 쿠키 삭제일 뿐
  토큰 자체는 만료까지 유효하다.
- 재검토 트리거: 토큰 강제 폐기/세션 관리 요구가 생기거나, access 토큰 수명을 길게 가져가야 할 때.
  로드맵의 **Refresh Token** 항목으로 추적한다(`README.md` / `CLAUDE.md`).
