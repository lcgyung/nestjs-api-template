import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';

import { ROLES_KEY } from '@/common/decorators/roles.decorator';
import { Role } from '@/common/enums/role.enum';
import { User } from '@/modules/users/entities/user.entity';

/**
 * @Roles 로 지정된 역할이 있으면 request.user.role 과 비교한다.
 * 반드시 JwtAuthGuard 뒤에 배치해 request.user 가 채워진 상태여야 한다.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[] | undefined>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<Request & { user?: User }>();
    const user = request.user;

    if (!user || !requiredRoles.includes(user.role)) {
      throw new ForbiddenException('이 작업을 수행할 권한이 없습니다.');
    }

    return true;
  }
}
