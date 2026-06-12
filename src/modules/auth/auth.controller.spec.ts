import { Test, type TestingModule } from '@nestjs/testing';
import { type Response } from 'express';

import { AuthController } from '@/modules/auth/auth.controller';
import { ACCESS_TOKEN_COOKIE, AuthService } from '@/modules/auth/auth.service';
import { type LoginDto } from '@/modules/auth/dto/login.dto';

describe('AuthController', () => {
  let controller: AuthController;
  let login: jest.Mock;
  let buildCookieOptions: jest.Mock;

  beforeEach(async () => {
    login = jest.fn();
    buildCookieOptions = jest.fn();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: { login, buildCookieOptions } }],
    }).compile();

    controller = module.get(AuthController);
  });

  describe('login', () => {
    it('authService.login 에 위임하고 토큰을 httpOnly 쿠키로 설정한다', async () => {
      const dto: LoginDto = { email: 'admin@example.com', password: 'password' };
      login.mockResolvedValue({ accessToken: 'signed.jwt.token' });
      buildCookieOptions.mockReturnValue({ httpOnly: true });
      const res = { cookie: jest.fn(), clearCookie: jest.fn() } as unknown as Response;

      await expect(controller.login(dto, res)).resolves.toEqual({
        accessToken: 'signed.jwt.token',
      });
      expect(login).toHaveBeenCalledWith(dto);
      expect(res.cookie).toHaveBeenCalledWith(ACCESS_TOKEN_COOKIE, 'signed.jwt.token', {
        httpOnly: true,
      });
    });
  });

  describe('logout', () => {
    it('쿠키를 제거하고 success 를 반환한다', () => {
      buildCookieOptions.mockReturnValue({ httpOnly: true });
      const res = { cookie: jest.fn(), clearCookie: jest.fn() } as unknown as Response;

      expect(controller.logout(res)).toEqual({ success: true });
      expect(res.clearCookie).toHaveBeenCalledWith(ACCESS_TOKEN_COOKIE, { httpOnly: true });
    });
  });
});
