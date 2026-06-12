import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { SwaggerModule } from '@nestjs/swagger';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import { WinstonModule } from 'nest-winston';

import { AppModule } from '@/app.module';
import { VALIDATION_PIPE_OPTIONS } from '@/common/pipes/validation-pipe.options';
import { buildSwaggerConfig } from '@/config/swagger.config';
import { winstonConfig } from '@/logger/winston.config';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: WinstonModule.createLogger(winstonConfig),
  });

  const configService = app.get(ConfigService);
  const isProd = configService.get<string>('nodeEnv') === 'production';

  // 리버스 프록시 뒤에서 secure 쿠키·X-Forwarded-* 가 동작하도록(프록시 1단계 신뢰)
  app.set('trust proxy', 1);

  // 보안 헤더 — HSTS 명시(프록시/LB 에서 TLS 종료 시에도 브라우저에 강제)
  app.use(helmet({ hsts: { maxAge: 15_552_000, includeSubDomains: true } }));

  // httpOnly 인증 쿠키 파싱(jwt.strategy 의 cookieExtractor 가 req.cookies 에 의존)
  app.use(cookieParser());

  // 페이로드 크기 제한 — 과대 본문(DoS) 방지
  app.useBodyParser('json', { limit: '100kb' });
  app.useBodyParser('urlencoded', { limit: '100kb', extended: true });

  // CORS — CORS_ORIGIN 이 비어 있으면 개발 편의상 전체 허용(prod 는 env 검증에서 fail-fast)
  const corsOrigin = configService.get<string>('cors.origin');
  app.enableCors({
    origin: corsOrigin ? corsOrigin.split(',').map((origin) => origin.trim()) : true,
    credentials: true,
  });

  // 전역 검증 파이프 — 옵션은 e2e 와 공유 (validation-pipe.options.ts)
  app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));

  // Swagger — prod 에선 비활성(스펙 파일은 openapi:generate 로 별도 export, ADR 0004)
  if (!isProd) {
    const document = SwaggerModule.createDocument(app, buildSwaggerConfig());
    SwaggerModule.setup('api-docs', app, document);
  }

  // SIGTERM/SIGINT 시 onApplicationShutdown 훅 실행 (TypeORM 커넥션 정리 등) — 컨테이너 환경 대응
  app.enableShutdownHooks();

  const port = configService.get<number>('port') ?? 3000;
  await app.listen(port);
}

void bootstrap();
