import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import {
  HealthCheck,
  HealthCheckResult,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';

import { Public } from '@/common/decorators/public.decorator';

@ApiTags('health')
@Public()
@Controller('health')
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly db: TypeOrmHealthIndicator,
  ) {}

  /** 종합 헬스체크 — readiness 와 동일 동작 (기존 모니터링 호환용 유지) */
  @Get()
  @HealthCheck()
  check(): Promise<HealthCheckResult> {
    return this.readiness();
  }

  /** 프로세스 생존만 확인 — DB 장애로 오케스트레이터가 재시작 루프를 돌지 않도록 무의존 */
  @Get('liveness')
  @HealthCheck()
  liveness(): Promise<HealthCheckResult> {
    return this.health.check([]);
  }

  /** 트래픽 수용 가능 여부 — DB 연결 확인 */
  @Get('readiness')
  @HealthCheck()
  readiness(): Promise<HealthCheckResult> {
    return this.health.check([() => this.db.pingCheck('database')]);
  }
}
