import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * 전역 JwtAuthGuard 를 우회해 인증 없이 접근을 허용한다(deny-by-default 의 명시적 예외).
 * @example @Public()
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
