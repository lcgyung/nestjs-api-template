#!/usr/bin/env bash
# SessionStart: 현재 브랜치/규칙을 컨텍스트로 주입
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
jq -n --arg b "$BRANCH" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("현재 브랜치: \($b)\nNestJS 규칙: 컨트롤러엔 라우팅만, 로직은 서비스로. DTO엔 class-validator. ConfigService 사용. any 금지.")
  }
}'
