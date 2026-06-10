/** Conventional Commits 강제. CONTRIBUTING.md 의 커밋 규약을 머신이 검증한다. */
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // 한국어·영문 혼용 subject 를 쓰는 프로젝트라 영문 소문자 시작 강제(subject-case)는 비활성.
    // type/scope·header 길이 등 핵심 규약은 그대로 유지한다.
    'subject-case': [0],
  },
};
