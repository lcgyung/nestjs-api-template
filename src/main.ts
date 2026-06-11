import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { WinstonModule } from 'nest-winston';

import { AppModule } from '@/app.module';
import { buildSwaggerConfig } from '@/config/swagger.config';
import { winstonConfig } from '@/logger/winston.config';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    logger: WinstonModule.createLogger(winstonConfig),
  });

  const configService = app.get(ConfigService);

  // 보안 헤더
  app.use(helmet());

  // CORS — CORS_ORIGIN 이 비어 있으면 전체 허용
  const corsOrigin = configService.get<string>('cors.origin');
  app.enableCors({
    origin: corsOrigin ? corsOrigin.split(',').map((origin) => origin.trim()) : true,
    credentials: true,
  });

  // 전역 검증 파이프 (정의되지 않은 속성 제거 + 타입 변환)
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // Swagger — 설정은 scripts/generate-openapi.ts 와 공유 (swagger.config.ts)
  const document = SwaggerModule.createDocument(app, buildSwaggerConfig());
  SwaggerModule.setup('api-docs', app, document);

  // SIGTERM/SIGINT 시 onApplicationShutdown 훅 실행 (TypeORM 커넥션 정리 등) — 컨테이너 환경 대응
  app.enableShutdownHooks();

  const port = configService.get<number>('port') ?? 3000;
  await app.listen(port);
}

void bootstrap();
