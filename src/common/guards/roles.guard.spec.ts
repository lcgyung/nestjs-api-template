import { type ExecutionContext, ForbiddenException } from '@nestjs/common';
import { type Reflector } from '@nestjs/core';

import { Role } from '@/common/enums/role.enum';
import { RolesGuard } from '@/common/guards/roles.guard';
import { type User } from '@/modules/users/entities/user.entity';

describe('RolesGuard', () => {
  let guard: RolesGuard;
  let getAllAndOverride: jest.Mock;

  const buildContext = (user?: Partial<User>): ExecutionContext =>
    ({
      getHandler: () => undefined,
      getClass: () => undefined,
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
    }) as unknown as ExecutionContext;

  beforeEach(() => {
    getAllAndOverride = jest.fn();
    guard = new RolesGuard({ getAllAndOverride } as unknown as Reflector);
  });

  it('필요 역할 메타데이터가 없으면 통과한다', () => {
    getAllAndOverride.mockReturnValue(undefined);
    expect(guard.canActivate(buildContext({ role: Role.User }))).toBe(true);
  });

  it('필요 역할이 빈 배열이면 통과한다', () => {
    getAllAndOverride.mockReturnValue([]);
    expect(guard.canActivate(buildContext({ role: Role.User }))).toBe(true);
  });

  it('사용자가 없으면 ForbiddenException 을 던진다', () => {
    getAllAndOverride.mockReturnValue([Role.Admin]);
    expect(() => guard.canActivate(buildContext(undefined))).toThrow(ForbiddenException);
  });

  it('역할이 일치하지 않으면 ForbiddenException 을 던진다', () => {
    getAllAndOverride.mockReturnValue([Role.Admin]);
    expect(() => guard.canActivate(buildContext({ role: Role.User }))).toThrow(ForbiddenException);
  });

  it('역할이 일치하면 통과한다', () => {
    getAllAndOverride.mockReturnValue([Role.Admin]);
    expect(guard.canActivate(buildContext({ role: Role.Admin }))).toBe(true);
  });
});
