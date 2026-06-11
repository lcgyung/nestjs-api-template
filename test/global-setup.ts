import { execSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

interface GlobalWithPgContainer {
  pgE2eContainer?: StartedPostgreSqlContainer;
}

/**
 * e2e 전용 PostgreSQL 을 testcontainers 로 기동한다 (ADR 0009).
 * Jest globalSetup 은 워커 fork 전에 실행되므로 여기서 주입한 process.env 가
 * 모든 e2e 워커(AppModule 의 ConfigModule)에 전파된다.
 * 마이그레이션·시드는 CI 와 동일한 CLI 경로(pnpm migration:run / pnpm seed)로 실행해
 * 각 실행마다 "깨끗한 DB + admin 시드" 를 보장한다.
 * (TypeORM 글롭의 .ts 런타임 로딩을 globalSetup 프로세스에서 직접 하지 않는 이유:
 *  ts-node require 훅이 Jest 트랜스포머와 겹쳐 이중 컴파일을 유발한다.)
 */
export default async function globalSetup(): Promise<void> {
  // colima(로컬 macOS) 폴백 — 표준 소켓 경로를 자동 인식한다. Docker Desktop·CI 에선 no-op.
  // ryuk 가 소켓을 컨테이너에 마운트할 땐 VM 내부 경로(/var/run/docker.sock)를 써야 한다.
  const colimaSock = join(homedir(), '.colima', 'default', 'docker.sock');
  if (
    !process.env.DOCKER_HOST &&
    !process.env.TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE &&
    // eslint-disable-next-line security/detect-non-literal-fs-filename -- 고정 상수(homedir 기반) 경로
    existsSync(colimaSock)
  ) {
    process.env.DOCKER_HOST = `unix://${colimaSock}`;
    process.env.TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = '/var/run/docker.sock';
  }

  const container: StartedPostgreSqlContainer = await new PostgreSqlContainer('postgres:17-alpine')
    .withDatabase('app')
    .start();

  process.env.DB_HOST = container.getHost();
  process.env.DB_PORT = String(container.getPort());
  process.env.DB_NAME = container.getDatabase();
  process.env.DB_USERNAME = container.getUsername();
  process.env.DB_PASSWORD = container.getPassword();
  process.env.JWT_SECRET ??= 'e2e-test-secret-at-least-16-chars';
  process.env.JWT_EXPIRES_IN ??= '1d';

  execSync('pnpm migration:run', { stdio: 'inherit', env: process.env });
  execSync('pnpm seed', { stdio: 'inherit', env: process.env });

  // teardown 에서 정지할 수 있도록 핸들 보관
  (globalThis as GlobalWithPgContainer).pgE2eContainer = container;
}
