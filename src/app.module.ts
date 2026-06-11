import {
  ClassSerializerInterceptor,
  type MiddlewareConsumer,
  Module,
  type NestModule,
} from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import { AllExceptionsFilter } from '@/common/filters/all-exceptions.filter';
import { JwtAuthGuard } from '@/common/guards/jwt-auth.guard';
import { RolesGuard } from '@/common/guards/roles.guard';
import { LoggingInterceptor } from '@/common/interceptors/logging.interceptor';
import { RequestIdMiddleware } from '@/common/middleware/request-id.middleware';
import configuration from '@/config/configuration';
import { validate } from '@/config/env.validation';
import { DatabaseModule } from '@/database/database.module';
import { LoggerModule } from '@/logger/logger.module';
import { AuthModule } from '@/modules/auth/auth.module';
import { HealthModule } from '@/modules/health/health.module';
import { UsersModule } from '@/modules/users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      load: [configuration],
      validate,
      envFilePath: [`.env.${process.env.NODE_ENV ?? 'development'}`, '.env'],
    }),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        throttlers: [
          {
            ttl: config.get<number>('throttle.ttl') ?? 60000,
            limit: config.get<number>('throttle.limit') ?? 100,
          },
        ],
      }),
    }),
    LoggerModule,
    DatabaseModule,
    AuthModule,
    UsersModule,
    HealthModule,
  ],
  providers: [
    // 가드 실행 순서: rate limiting → 인증(deny-by-default) → 역할 인가.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_INTERCEPTOR, useClass: LoggingInterceptor },
    { provide: APP_INTERCEPTOR, useClass: ClassSerializerInterceptor },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    // Express 5(Nest 11)에서는 '*' 대신 '{*splat}' 가 전체 라우트 매칭 문법이다
    consumer.apply(RequestIdMiddleware).forRoutes('{*splat}');
  }
}
