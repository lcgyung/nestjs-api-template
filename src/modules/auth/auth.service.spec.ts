import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test, type TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';

import { Role } from '@/common/enums/role.enum';
import { AuthService, maskEmail } from '@/modules/auth/auth.service';
import { type User } from '@/modules/users/entities/user.entity';
import { UsersService } from '@/modules/users/users.service';

describe('AuthService', () => {
  let service: AuthService;
  let findByEmail: jest.Mock;
  let signAsync: jest.Mock;
  let decode: jest.Mock;
  let configGet: jest.Mock;
  let userRecord: User;

  beforeEach(async () => {
    findByEmail = jest.fn();
    signAsync = jest.fn();
    decode = jest.fn();
    configGet = jest.fn();

    userRecord = {
      id: 1,
      email: 'admin@example.com',
      password: await bcrypt.hash('password', 10),
      name: 'Admin',
      role: Role.Admin,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: { findByEmail } },
        { provide: JwtService, useValue: { signAsync, decode } },
        { provide: ConfigService, useValue: { get: configGet } },
      ],
    }).compile();

    service = module.get(AuthService);
  });

  describe('login', () => {
    it('자격 증명이 유효하면 accessToken 을 반환한다', async () => {
      findByEmail.mockResolvedValue(userRecord);
      signAsync.mockResolvedValue('signed.jwt.token');

      const result = await service.login({ email: 'admin@example.com', password: 'password' });

      expect(result).toEqual({ accessToken: 'signed.jwt.token' });
      expect(signAsync).toHaveBeenCalledWith({
        sub: 1,
        email: 'admin@example.com',
        role: Role.Admin,
      });
    });

    it('사용자가 없으면 UnauthorizedException 을 던진다', async () => {
      findByEmail.mockResolvedValue(null);

      await expect(
        service.login({ email: 'nope@example.com', password: 'password' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('비밀번호가 일치하지 않으면 UnauthorizedException 을 던진다', async () => {
      findByEmail.mockResolvedValue(userRecord);

      await expect(
        service.login({ email: 'admin@example.com', password: 'wrong-password' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('buildCookieOptions', () => {
    it('개발 환경에서는 secure=false, maxAge 는 토큰 exp/iat 차이로 산출한다', () => {
      configGet.mockReturnValue('development');
      decode.mockReturnValue({ iat: 1_000, exp: 1_000 + 3_600 });

      const opts = service.buildCookieOptions('signed.jwt.token');

      expect(opts).toMatchObject({
        httpOnly: true,
        secure: false,
        sameSite: 'strict',
        path: '/',
        maxAge: 3_600_000,
      });
    });

    it('production 환경에서는 secure=true, 토큰이 없으면 세션 쿠키(maxAge 없음)', () => {
      configGet.mockReturnValue('production');

      const opts = service.buildCookieOptions();

      expect(opts.secure).toBe(true);
      expect(opts.maxAge).toBeUndefined();
    });

    it('토큰 디코드에 실패하면 maxAge 없이(세션 쿠키) 반환한다', () => {
      configGet.mockReturnValue('development');
      decode.mockReturnValue(null);

      const opts = service.buildCookieOptions('bad.token');

      expect(opts.maxAge).toBeUndefined();
    });
  });

  describe('maskEmail', () => {
    it('로컬파트를 가리고 도메인은 유지한다', () => {
      expect(maskEmail('admin@example.com')).toBe('a***@example.com');
    });

    it('@ 가 없는 값은 전체를 가린다', () => {
      expect(maskEmail('not-an-email')).toBe('***');
    });
  });
});
