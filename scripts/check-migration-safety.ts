import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

/**
 * 마이그레이션 데이터 손실 가드 — DB 불필요 정적 스캔.
 *
 * 생성된 마이그레이션의 `up()` 에 데이터 손실 DDL(DROP TABLE/COLUMN, ALTER COLUMN ... TYPE,
 * DROP TYPE, TRUNCATE, DELETE FROM, enum temp-swap)이 있으면, 같은 파일에 명시적 ack 주석
 * (`// migration-safety-ack: <사유>`)이 없는 한 차단(exit 1)한다.
 *
 * `down()` 의 DROP 은 가역성을 위한 정상 동작이라 스캔 대상에서 제외한다(up() 영역만 본다).
 * FK 의 `ON DELETE/UPDATE CASCADE`·`DROP CONSTRAINT` 는 데이터 손실이 아니므로 비대상이다.
 *
 * OpenAPI 드리프트 게이트(ci.yml)와 동일한 "결정론적 정적 검사 → 차단" 철학.
 * CI·Stop 게이트·로컬에서 `pnpm check:migrations` 로 실행한다. 정책 정본: .claude/rules/migrations.md.
 */

const MIGRATIONS_DIR = resolve(__dirname, '../src/database/migrations');
const ACK_MARKER = 'migration-safety-ack:';

interface Rule {
  label: string;
  re: RegExp;
}

const DESTRUCTIVE_RULES: Rule[] = [
  { label: 'DROP TABLE', re: /\bDROP\s+TABLE\b/i },
  { label: 'DROP COLUMN', re: /\bDROP\s+COLUMN\b/i },
  { label: 'ALTER COLUMN … TYPE (컬럼 타입 변경)', re: /\bALTER\s+COLUMN\b.*\bTYPE\b/i },
  { label: 'DROP TYPE (enum 재생성/제거)', re: /\bDROP\s+TYPE\b/i },
  { label: 'TRUNCATE', re: /\bTRUNCATE\b/i },
  { label: 'DELETE FROM', re: /\bDELETE\s+FROM\b/i },
  { label: 'enum temp-swap (RENAME TO "…_old")', re: /\bRENAME\s+TO\s+"?[\w.]*_old"?/i },
];

interface Violation {
  file: string;
  line: number;
  text: string;
  rule: string;
}

/** down() 시작 전까지가 up() 영역. 없으면(=up 만 있는 파일) 전체를 보수적으로 스캔한다. */
function upRegionLineCount(lines: string[]): number {
  const downIdx = lines.findIndex((line) => /async\s+down\s*\(/.test(line));
  return downIdx === -1 ? lines.length : downIdx;
}

function scanFile(file: string, source: string): Violation[] {
  if (source.includes(ACK_MARKER)) return []; // 의식적 opt-in — 의도된 파괴적 변경 허용
  const lines = source.split('\n');
  const upEnd = upRegionLineCount(lines);
  const violations: Violation[] = [];
  for (let i = 0; i < upEnd; i++) {
    const line = lines[i];
    for (const rule of DESTRUCTIVE_RULES) {
      if (rule.re.test(line)) {
        violations.push({ file, line: i + 1, text: line.trim(), rule: rule.label });
      }
    }
  }
  return violations;
}

function main(): void {
  let files: string[];
  try {
    files = readdirSync(MIGRATIONS_DIR)
      .filter((name) => name.endsWith('.ts'))
      .sort();
  } catch {
    console.log('check-migrations: 마이그레이션 디렉터리가 없어 건너뜁니다.');
    return;
  }

  const violations: Violation[] = [];
  for (const file of files) {
    // eslint-disable-next-line security/detect-non-literal-fs-filename -- 위 readdir 로 열거된 repo 내 파일
    const source = readFileSync(join(MIGRATIONS_DIR, file), 'utf8');
    violations.push(...scanFile(file, source));
  }

  if (violations.length === 0) {
    console.log(
      `check-migrations: ${files.length}개 마이그레이션 up() 에 미승인 파괴적 DDL 없음 ✓`,
    );
    return;
  }

  console.error('check-migrations: up() 에 데이터 손실 가능 DDL 발견 (ack 없음)\n');
  for (const v of violations) {
    console.error(`  ✗ ${v.file}:${v.line}  [${v.rule}]`);
    console.error(`      ${v.text}`);
  }
  console.error(
    '\n의도된 파괴적 변경이면 해당 마이그레이션 파일에 사유와 함께 주석을 추가하세요:\n' +
      `  // ${ACK_MARKER} <왜 데이터 손실이 안전/의도된지>\n` +
      '검토 없이 적용하면 테이블 데이터가 지워질 수 있습니다. (.claude/rules/migrations.md 참고)',
  );
  process.exit(1);
}

main();
