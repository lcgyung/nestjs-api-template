import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { type CookieOptions } from 'express';

import { LoginDto } from '@/modules/auth/dto/login.dto';
import { JwtPayload } from '@/modules/auth/types/jwt-payload.interface';
import { User } from '@/modules/users/entities/user.entity';
import { UsersService } from '@/modules/users/users.service';

/** 인증 토큰을 담는 httpOnly 쿠키 이름. jwt.strategy 추출기와 공유한다. */
export const ACCESS_TOKEN_COOKIE = 'access_token';

export interface LoginResponse {
  accessToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async validateUser(email: string, password: string): Promise<User> {
    const user = await this.usersService.findByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.password))) {
      throw new UnauthorizedException('이메일 또는 비밀번호가 올바르지 않습니다.');
    }
    return user;
  }

  async login(dto: LoginDto): Promise<LoginResponse> {
    const user = await this.validateUser(dto.email, dto.password);
    const payload: JwtPayload = { sub: user.id, email: user.email, role: user.role };
    return { accessToken: await this.jwtService.signAsync(payload) };
  }

  /**
   * access_token 쿠키 옵션. prod 에서만 `secure`(로컬 http 개발에서도 쿠키가 설정되도록).
   * maxAge 는 토큰의 exp/iat 차이로 산출하며, 디코드 실패 시 세션 쿠키로 둔다.
   */
  buildCookieOptions(token?: string): CookieOptions {
    const isProd = this.configService.get<string>('nodeEnv') === 'production';
    const maxAge = token ? this.resolveCookieMaxAge(token) : undefined;
    return {
      httpOnly: true,
      secure: isProd,
      sameSite: 'strict',
      path: '/',
      ...(maxAge !== undefined ? { maxAge } : {}),
    };
  }

  private resolveCookieMaxAge(token: string): number | undefined {
    const decoded = this.jwtService.decode<{ exp?: number; iat?: number } | null>(token);
    if (decoded?.exp !== undefined && decoded.iat !== undefined) {
      return (decoded.exp - decoded.iat) * 1000;
    }
    return undefined;
  }
}
