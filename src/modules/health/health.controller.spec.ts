import {
  type HealthCheckResult,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';
import { Test, type TestingModule } from '@nestjs/testing';

import { HealthController } from '@/modules/health/health.controller';

describe('HealthController', () => {
  let controller: HealthController;
  let check: jest.Mock;
  let pingCheck: jest.Mock;

  const okResult: HealthCheckResult = {
    status: 'ok',
    info: {},
    error: {},
    details: {},
  };

  beforeEach(async () => {
    // health.check 는 전달받은 인디케이터들을 실행한 뒤 결과를 반환한다 — 실제 동작을 모사
    check = jest.fn(async (indicators: (() => Promise<unknown>)[]) => {
      await Promise.all(indicators.map((indicator) => indicator()));
      return okResult;
    });
    pingCheck = jest.fn().mockResolvedValue({ database: { status: 'up' } });

    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        { provide: HealthCheckService, useValue: { check } },
        { provide: TypeOrmHealthIndicator, useValue: { pingCheck } },
      ],
    }).compile();

    controller = module.get(HealthController);
  });

  describe('liveness', () => {
    it('의존성 검사 없이 통과한다', async () => {
      await expect(controller.liveness()).resolves.toBe(okResult);
      expect(check).toHaveBeenCalledWith([]);
      expect(pingCheck).not.toHaveBeenCalled();
    });
  });

  describe('readiness', () => {
    it('DB ping 인디케이터를 실행한다', async () => {
      await expect(controller.readiness()).resolves.toBe(okResult);
      expect(pingCheck).toHaveBeenCalledWith('database');
    });
  });

  describe('check', () => {
    it('readiness 와 동일하게 DB ping 을 수행한다', async () => {
      await expect(controller.check()).resolves.toBe(okResult);
      expect(pingCheck).toHaveBeenCalledWith('database');
    });
  });
});
