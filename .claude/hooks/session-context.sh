#!/usr/bin/env bash
# SessionStart: 현재 브랜치를 컨텍스트로 주입 (규칙 요약은 항상 로드되는 CLAUDE.md 와 중복이라 제외)
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
jq -n --arg b "$BRANCH" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("현재 브랜치: \($b)")
  }
}'
