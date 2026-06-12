import { type ValidationPipeOptions } from '@nestjs/common';

/**
 * 전역 ValidationPipe 옵션 — main.ts(런타임)와 test/app.e2e-spec.ts 가 공유한다.
 * forbidNonWhitelisted: DTO 에 없는 속성은 조용히 제거하지 않고 400 으로 fail-loud
 * (Mass Assignment 차단, secure-harness 체크리스트 1절).
 */
export const VALIDATION_PIPE_OPTIONS: ValidationPipeOptions = {
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
  transformOptions: { enableImplicitConversion: true },
};
