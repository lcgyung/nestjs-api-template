#!/usr/bin/env bash
# SessionStart: 현재 브랜치를 컨텍스트로 주입 (규칙 요약은 항상 로드되는 CLAUDE.md 와 중복이라 제외)
# 공용 헬퍼(emit_session_context) — 단일 정본 .claude/hooks/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
emit_session_context "현재 브랜치: $BRANCH"
