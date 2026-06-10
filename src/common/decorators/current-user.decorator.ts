import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Request } from 'express';
import { User } from '@/modules/users/entities/user.entity';

/**
 * 인증된 사용자(또는 특정 필드)를 핸들러 인자로 주입한다.
 * JwtAuthGuard 가 request.user 를 채운 라우트에서만 유효하다.
 * @example getMe(@CurrentUser() user: User)
 * @example getId(@CurrentUser('id') id: number)
 */
export const CurrentUser = createParamDecorator(
  (data: keyof User | undefined, ctx: ExecutionContext): unknown => {
    const request = ctx.switchToHttp().getRequest<Request & { user?: User }>();
    const user = request.user;
    return data ? user?.[data] : user;
  },
);
