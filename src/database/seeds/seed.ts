import * as bcrypt from 'bcrypt';
import { type DataSource } from 'typeorm';

import { Role } from '@/common/enums/role.enum';
import { User } from '@/modules/users/entities/user.entity';

/**
 * 기본 관리자 계정을 생성한다. (admin@example.com / password)
 * CLI(`pnpm seed`)와 e2e globalSetup(testcontainers)이 공유하는 단일 시드 로직.
 */
export async function seedAdmin(dataSource: DataSource): Promise<void> {
  const repo = dataSource.getRepository(User);
  const email = 'admin@example.com';

  const existing = await repo.findOne({ where: { email } });
  if (existing) {
    console.log(`이미 존재하는 계정입니다: ${email}`);
    return;
  }

  const user = repo.create({
    email,
    password: await bcrypt.hash('password', 10),
    name: 'Administrator',
    role: Role.Admin,
  });
  await repo.save(user);
  console.log(`시드 계정 생성 완료: ${email} / password`);
}

// CLI 엔트리 — 직접 실행 시에만 AppDataSource 를 초기화한다. 실행: pnpm seed
if (require.main === module) {
  void (async () => {
    // 동적 import 로 CLI 경로에서만 .env 로드(데이터소스 모듈 사이드이펙트)를 발생시킨다.
    const { AppDataSource } = await import('@/database/data-source');
    const dataSource = await AppDataSource.initialize();
    try {
      await seedAdmin(dataSource);
    } finally {
      await dataSource.destroy();
    }
  })().catch((error) => {
    console.error('시드 실패:', error);
    process.exit(1);
  });
}
