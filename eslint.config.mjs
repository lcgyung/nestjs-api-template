// @ts-check
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import eslintPluginPrettierRecommended from 'eslint-plugin-prettier/recommended';
import simpleImportSort from 'eslint-plugin-simple-import-sort';
import globals from 'globals';

export default tseslint.config(
  {
    ignores: ['eslint.config.mjs', 'dist', 'node_modules', 'coverage'],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  eslintPluginPrettierRecommended,
  {
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.jest,
      },
      sourceType: 'commonjs',
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      // warn 은 lint(--max-warnings 미설정)·게이트·CI 를 막지 못해 실질 강제력이 없다 → error 로 승격.
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      // 네이밍 컨벤션 — 기존 코드 스타일을 그대로 강제(위반 0 목표).
      // 기본 프리셋은 enumMember 를 UPPER_CASE 로 기대하나 이 리포는 PascalCase(Role.User 등) → 아래에서 명시.
      '@typescript-eslint/naming-convention': [
        'error',
        { selector: 'default', format: ['camelCase'] },
        // 변수는 camelCase 기본. PascalCase 는 데코레이터 팩토리(CurrentUser·Roles)·
        // DataSource 인스턴스(AppDataSource) 같은 관용 const 를, UPPER_CASE 는 상수를 허용.
        // 미사용 구조분해(_omitted 등)를 위해 leadingUnderscore 허용.
        {
          selector: 'variable',
          format: ['camelCase', 'UPPER_CASE', 'PascalCase'],
          leadingUnderscore: 'allow',
        },
        { selector: 'parameter', format: ['camelCase'], leadingUnderscore: 'allow' },
        {
          selector: 'memberLike',
          modifiers: ['private', 'static', 'readonly'],
          format: ['UPPER_CASE'],
        },
        { selector: 'memberLike', format: ['camelCase'] },
        // env 검증 클래스(EnvironmentVariables)는 외부 env 키(NODE_ENV·DB_HOST 등)를 그대로 미러링 → UPPER_CASE 허용.
        { selector: 'classProperty', format: ['camelCase', 'UPPER_CASE'] },
        { selector: 'typeLike', format: ['PascalCase'] },
        { selector: 'enumMember', format: ['PascalCase'] },
        // config/option 등 외부 형태 객체 키가 많아 오탐 방지 위해 비활성.
        { selector: 'objectLiteralProperty', format: null },
        { selector: 'import', format: ['camelCase', 'PascalCase'] },
      ],
      // 타입 전용 임포트는 `import type` 으로 통일(auto-fix). 빌드/번들 경계 명확화.
      '@typescript-eslint/consistent-type-imports': ['error', { fixStyle: 'inline-type-imports' }],
      // 타입 정의는 interface 로 통일(기존 JwtPayload·ErrorResponseBody 와 일치).
      '@typescript-eslint/consistent-type-definitions': ['error', 'interface'],
      // 배열 타입은 T[] 로 통일.
      '@typescript-eslint/array-type': ['error', { default: 'array' }],
      // nullish 안전 연산자 선호(기존 코드가 ??·?. 사용).
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',
      eqeqeq: ['error', 'always'],
    },
  },
  {
    // import/export 정렬 — external → node: → 패키지 → @/ 별칭 → 상대경로 순(결정적·auto-fix).
    plugins: { 'simple-import-sort': simpleImportSort },
    rules: {
      'simple-import-sort/imports': [
        'error',
        { groups: [['^\\u0000'], ['^node:'], ['^@?\\w'], ['^@/'], ['^\\.']] },
      ],
      'simple-import-sort/exports': 'error',
    },
  },
  {
    // 테스트에서는 jest 모킹 특성상 any 기반 흐름이 많아 unsafe 계열 규칙을 완화한다.
    files: ['**/*.spec.ts', 'test/**/*.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
      '@typescript-eslint/no-unsafe-return': 'off',
      '@typescript-eslint/no-unsafe-argument': 'off',
      '@typescript-eslint/unbound-method': 'off',
    },
  },
);
