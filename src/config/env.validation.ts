import { plainToInstance, Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
  validateSync,
} from 'class-validator';

export enum NodeEnv {
  Development = 'development',
  Production = 'production',
  Test = 'test',
}

/**
 * 부팅 시 검증되는 환경 변수 스키마.
 * 누락/형식 오류가 있으면 즉시 예외를 던져 애플리케이션 기동을 중단한다(fail-fast).
 */
export class EnvironmentVariables {
  @IsOptional()
  @IsEnum(NodeEnv)
  NODE_ENV: NodeEnv = NodeEnv.Development;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(65535)
  PORT = 3000;

  @IsString()
  @IsNotEmpty()
  DB_HOST!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(65535)
  DB_PORT = 3306;

  @IsString()
  @IsNotEmpty()
  DB_NAME!: string;

  @IsString()
  @IsNotEmpty()
  DB_USERNAME!: string;

  @IsString()
  DB_PASSWORD = '';

  @IsString()
  @MinLength(16, { message: 'JWT_SECRET 은(는) 최소 16자 이상이어야 합니다.' })
  JWT_SECRET!: string;

  @IsString()
  @IsNotEmpty()
  JWT_EXPIRES_IN = '1d';

  @IsOptional()
  @IsString()
  CORS_ORIGIN = '';

  @Type(() => Number)
  @IsInt()
  THROTTLE_TTL = 60000;

  @Type(() => Number)
  @IsInt()
  THROTTLE_LIMIT = 100;
}

export function validate(config: Record<string, unknown>): EnvironmentVariables {
  // 숫자 필드는 @Type(() => Number) 로 명시 변환한다(reflect 메타데이터 의존 제거 → 빌드/테스트 환경 무관하게 동작).
  const validatedConfig = plainToInstance(EnvironmentVariables, config);

  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    const messages = errors
      .map((error) => Object.values(error.constraints ?? {}).join(', '))
      .join('\n');
    throw new Error(`환경 변수 검증 실패:\n${messages}`);
  }

  return validatedConfig;
}
