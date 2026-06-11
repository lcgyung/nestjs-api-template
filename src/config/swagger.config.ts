import { DocumentBuilder, type OpenAPIObject } from '@nestjs/swagger';

/**
 * Swagger 문서 설정 — main.ts(런타임 UI)와 scripts/generate-openapi.ts(스펙 파일 export)가
 * 공유한다. 설정이 한쪽에만 반영되는 드리프트를 막기 위해 함수로 추출.
 */
export function buildSwaggerConfig(): Omit<OpenAPIObject, 'paths'> {
  return new DocumentBuilder()
    .setTitle('NestJS API Template')
    .setDescription('JWT 인증·TypeORM·Swagger 기반 프로덕션 지향 API 템플릿')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
}
