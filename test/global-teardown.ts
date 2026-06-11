import { type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

interface GlobalWithPgContainer {
  pgE2eContainer?: StartedPostgreSqlContainer;
}

/** globalSetup 이 띄운 e2e 전용 PostgreSQL 컨테이너를 정지한다. */
export default async function globalTeardown(): Promise<void> {
  const container = (globalThis as GlobalWithPgContainer).pgE2eContainer;
  await container?.stop();
}
