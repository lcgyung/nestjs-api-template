import * as bcrypt from 'bcrypt';
import { AppDataSource } from '@/database/data-source';
import { Role } from '@/common/enums/role.enum';
import { User } from '@/modules/users/entities/user.entity';

/**
 * 기본 관리자 계정을 생성한다. (admin@example.com / password)
 * 실행: npm run seed
 */
async function seed(): Promise<void> {
  const dataSource = await AppDataSource.initialize();
  try {
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
  } finally {
    await dataSource.destroy();
  }
}

seed().catch((error) => {
  console.error('시드 실패:', error);
  process.exit(1);
});
