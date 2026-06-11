import { type MigrationInterface, type QueryRunner } from 'typeorm';

/**
 * 초기 스키마 — users 테이블 + role enum TYPE (PostgreSQL).
 * User 엔티티와 1:1로 일치하므로 엔티티 변경 없이 `migration:generate` 를
 * 다시 돌리면 빈 마이그레이션이 생성된다.
 * down 은 테이블과 enum TYPE 을 모두 제거해 완전히 가역적이다.
 */
export class Init1781160213410 implements MigrationInterface {
  name = 'Init1781160213410';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TYPE "public"."users_role_enum" AS ENUM('user', 'admin')`);
    await queryRunner.query(
      `CREATE TABLE "users" ("id" SERIAL NOT NULL, "email" character varying NOT NULL, "password" character varying NOT NULL, "name" character varying NOT NULL DEFAULT '', "role" "public"."users_role_enum" NOT NULL DEFAULT 'user', "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_97672ac88f789774dd47f7c8be3" UNIQUE ("email"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "users"`);
    await queryRunner.query(`DROP TYPE "public"."users_role_enum"`);
  }
}
