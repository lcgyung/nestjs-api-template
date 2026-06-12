import { type MigrationInterface, type QueryRunner } from 'typeorm';

/**
 * 초기 스키마 — users 테이블. User 엔티티와 1:1로 일치하므로
 * 엔티티 변경 없이 `migration:generate` 를 다시 돌리면 빈 마이그레이션이 생성된다.
 */
export class Init1749456000000 implements MigrationInterface {
  name = 'Init1749456000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE \`users\` (
        \`id\` int NOT NULL AUTO_INCREMENT,
        \`email\` varchar(255) NOT NULL,
        \`password\` varchar(255) NOT NULL,
        \`name\` varchar(255) NOT NULL DEFAULT '',
        \`role\` enum ('user', 'admin') NOT NULL DEFAULT 'user',
        \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        \`updatedAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
        UNIQUE INDEX \`IDX_users_email\` (\`email\`),
        PRIMARY KEY (\`id\`)
      ) ENGINE=InnoDB
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX \`IDX_users_email\` ON \`users\``);
    await queryRunner.query(`DROP TABLE \`users\``);
  }
}
