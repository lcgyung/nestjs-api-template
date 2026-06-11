import { Test, type TestingModule } from '@nestjs/testing';

import { AuthController } from '@/modules/auth/auth.controller';
import { AuthService } from '@/modules/auth/auth.service';
import { type LoginDto } from '@/modules/auth/dto/login.dto';

describe('AuthController', () => {
  let controller: AuthController;
  let login: jest.Mock;

  beforeEach(async () => {
    login = jest.fn();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: { login } }],
    }).compile();

    controller = module.get(AuthController);
  });

  describe('login', () => {
    it('authService.login 에 위임하고 accessToken 을 반환한다', async () => {
      const dto: LoginDto = { email: 'admin@example.com', password: 'password' };
      login.mockResolvedValue({ accessToken: 'signed.jwt.token' });

      await expect(controller.login(dto)).resolves.toEqual({ accessToken: 'signed.jwt.token' });
      expect(login).toHaveBeenCalledWith(dto);
    });
  });
});
