import 'reflect-metadata';

import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { SwaggerModule } from '@nestjs/swagger';
import { Test } from '@nestjs/testing';
import { getDataSourceToken } from '@nestjs/typeorm';

import { AppModule } from '@/app.module';
import { buildSwaggerConfig } from '@/config/swagger.config';

/**
 * DB 없이 OpenAPI 스펙(docs/openapi.json)을 생성한다.
 *
 * TypeOrmModule.forRootAsync 는 모듈 인스턴스화 시점에 실제 PostgreSQL 연결을 시도하므로,
 * DataSource 토큰을 스텁으로 치환해 메타데이터(컨트롤러·DTO 데코레이터)만으로 문서를 만든다.
 * 스텁은 forFeature 리포지토리 팩토리(options.type 체크 + getRepository)와
 * EntityManager 프로바이더(manager 접근)가 요구하는 표면만 충족하면 된다.
 */
const dataSourceStub = {
  options: { type: 'postgres' },
  manager: {},
  getRepository: (): object => ({}),
  entityMetadatas: [],
};

async function generate(): Promise<void> {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(getDataSourceToken())
    .useValue(dataSourceStub)
    .compile();

  // init() 은 호출하지 않는다 — onModuleInit 류 훅(실연결 전제)을 피하기 위함.
  const app = moduleRef.createNestApplication();
  const document = SwaggerModule.createDocument(app, buildSwaggerConfig());

  const outPath = resolve(__dirname, '../docs/openapi.json');
  writeFileSync(outPath, `${JSON.stringify(document, null, 2)}\n`);
  console.log(`OpenAPI 스펙 생성 완료: ${outPath}`);

  await moduleRef.close();
}

void generate();
