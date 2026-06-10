import 'reflect-metadata';

import { config as loadEnv } from 'dotenv';
import { join } from 'path';
import { DataSource } from 'typeorm';

// CLI(마이그레이션/시드)는 Nest 컨텍스트 밖에서 실행되므로 직접 .env 를 로드한다.
const nodeEnv = process.env.NODE_ENV ?? 'development';
loadEnv({ path: `.env.${nodeEnv}` });
loadEnv(); // .env 폴백 (위에서 채워지지 않은 값 보충)

/**
 * 앱(TypeOrmModule)과 분리된 standalone DataSource.
 * `migration:generate`/`migration:run` 및 seed 스크립트가 이 설정을 기준으로 동작한다.
 */
export const AppDataSource = new DataSource({
  type: 'mysql',
  host: process.env.DB_HOST ?? 'localhost',
  port: parseInt(process.env.DB_PORT ?? '3306', 10),
  username: process.env.DB_USERNAME ?? 'root',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'app',
  entities: [join(__dirname, '..', '**', '*.entity.{ts,js}')],
  migrations: [join(__dirname, 'migrations', '*.{ts,js}')],
  synchronize: false,
  logging: nodeEnv === 'development',
});
