import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import { WinstonModule } from 'nest-winston';

import { AppModule } from '@/app.module';
import { VALIDATION_PIPE_OPTIONS } from '@/common/pipes/validation-pipe.options';
import { buildSwaggerConfig } from '@/config/swagger.config';
import { winstonConfig } from '@/logger/winston.config';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    logger: WinstonModule.createLogger(winstonConfig),
  });

  const configService = app.get(ConfigService);

  // 보안 헤더
  app.use(helmet());

  // httpOnly 인증 쿠키 파싱(jwt.strategy 의 cookieExtractor 가 req.cookies 에 의존)
  app.use(cookieParser());

  // CORS — CORS_ORIGIN 이 비어 있으면 전체 허용
  const corsOrigin = configService.get<string>('cors.origin');
  app.enableCors({
    origin: corsOrigin ? corsOrigin.split(',').map((origin) => origin.trim()) : true,
    credentials: true,
  });

  // 전역 검증 파이프 — 옵션은 e2e 와 공유 (validation-pipe.options.ts)
  app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));

  // Swagger — 설정은 scripts/generate-openapi.ts 와 공유 (swagger.config.ts)
  const document = SwaggerModule.createDocument(app, buildSwaggerConfig());
  SwaggerModule.setup('api-docs', app, document);

  // SIGTERM/SIGINT 시 onApplicationShutdown 훅 실행 (TypeORM 커넥션 정리 등) — 컨테이너 환경 대응
  app.enableShutdownHooks();

  const port = configService.get<number>('port') ?? 3000;
  await app.listen(port);
}

void bootstrap();
