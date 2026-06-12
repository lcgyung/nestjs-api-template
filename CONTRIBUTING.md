# Contributing

이 템플릿에 기여할 때의 브랜치 전략·커밋 컨벤션·버전 규칙·로컬 게이트를 정리합니다.
환경 설정·실행 방법·스크립트는 [`README.md`](README.md)를, 코드 작업 규칙은
[`CLAUDE.md`](CLAUDE.md)를 참고하세요.

## 브랜치 전략

- `main` — 배포(릴리스) 브랜치. **직접 push 금지**, PR 으로만 병합합니다.
- `dev` — 통합 브랜치. 기능 브랜치가 모이는 곳이며 릴리스 시 `main` 으로 PR 합니다.
- `feat/*` · `fix/*` · `chore/*` 등 — 작업 브랜치. `dev` 에서 분기해 `dev` 로 PR 합니다.

```text
feat|fix|chore/* ──PR──▶ dev ──PR──▶ main(release)
```

CI(`.github/workflows/ci.yml`)는 `main`·`dev` 대상 push/PR 에서 lint·build·단위 테스트를
실행합니다(DB 의존 e2e 는 리포지토리 변수 `RUN_E2E=true` 일 때만).

## 커밋 컨벤션

[Conventional Commits](https://www.conventionalcommits.org/)를 따릅니다.

```text
<type>(<scope>): <subject>
```

- **type**: `feat`(기능) · `fix`(버그) · `chore`(빌드/설정) · `docs`(문서) ·
  `refactor` · `test` · `ci` · `style` · `perf`.
- **scope**(선택): 변경 영역 (`users`, `auth`, `ci`, `claude` 등).
- 예: `feat(users): 사용자 목록 조회 페이지네이션 도입`, `fix(ci): Node 22 정렬`.

PR 제목도 동일한 컨벤션을 따릅니다.

## 버전 규칙

[Semantic Versioning](https://semver.org/) `MAJOR.MINOR.PATCH` 를 따릅니다.

- **MAJOR** — 호환성이 깨지는 변경.
- **MINOR** — 하위 호환되는 기능 추가.
- **PATCH** — 하위 호환되는 버그 수정.

릴리스 절차:

1. `package.json` 의 `version` 갱신.
2. `CHANGELOG.md` 에 해당 버전 항목 추가(`## [x.y.z] - YYYY-MM-DD`, `### Added/Changed/Fixed`).
3. `main` 병합 후 태그 푸시 → GitHub Release 생성(노트는 CHANGELOG 항목과 일치).

```bash
git checkout main && git pull
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

> 초기 단계(`0.x`)에서는 구조/API 가 변경될 수 있습니다.

## 로컬 개발 & 게이트

```bash
pnpm install --frozen-lockfile   # 재현 설치 (CI 와 동일)
pnpm lint                        # ESLint  (pnpm lint:fix 로 자동 수정)
pnpm build                       # nest build + tsc-alias
pnpm test                        # 단위 테스트 (*.spec.ts)
```

- 커밋 시 Husky + lint-staged 가 변경 파일에 `eslint --fix` + `prettier` 를 적용합니다.
- Claude Code 세션의 **Stop 게이트**(`.claude/`)가 `tsc --noEmit` + `eslint` +
  `prettier --check` + 유닛 `jest` 를 누적 검사합니다. PR 전 위 4개를 통과시키세요.
- e2e(`*.e2e-spec.ts`)는 실제 DB 가 필요하므로 빠른 피드백 루프에서는 제외합니다
  (`pnpm test:e2e`, 사전에 `migration:run` + `seed`).

## Pull Request

- 작은 단위로, 하나의 목적에 집중해 올립니다.
- PR 본문은 `.github/PULL_REQUEST_TEMPLATE.md` 양식을 채웁니다.
- lint·build·test 통과 및 리뷰 승인 후 병합합니다.
