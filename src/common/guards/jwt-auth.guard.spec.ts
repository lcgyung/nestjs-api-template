import { type ExecutionContext } from '@nestjs/common';
import { type Reflector } from '@nestjs/core';

import { JwtAuthGuard } from '@/common/guards/jwt-auth.guard';

describe('JwtAuthGuard', () => {
  const context = {
    getHandler: () => ({}),
    getClass: () => ({}),
  } as unknown as ExecutionContext;

  it('@Public 핸들러면 인증을 건너뛰고 true 를 반환한다', () => {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue(true),
    } as unknown as Reflector;
    const guard = new JwtAuthGuard(reflector);

    expect(guard.canActivate(context)).toBe(true);
  });

  it('@Public 이 아니면 부모 AuthGuard 의 canActivate 에 위임한다', () => {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue(false),
    } as unknown as Reflector;
    const guard = new JwtAuthGuard(reflector);

    // AuthGuard('jwt') 믹스인 프로토타입의 canActivate 를 스텁(passport 실제 동작 회피).
    const parentProto = Object.getPrototypeOf(JwtAuthGuard.prototype);
    const spy = jest.spyOn(parentProto, 'canActivate').mockReturnValue('delegated');

    expect(guard.canActivate(context)).toBe('delegated');
    expect(spy).toHaveBeenCalledWith(context);

    spy.mockRestore();
  });
});
