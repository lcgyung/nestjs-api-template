import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, type TestingModule } from '@nestjs/testing';

import { Role } from '@/common/enums/role.enum';
import { JwtStrategy } from '@/modules/auth/strategies/jwt.strategy';
import { type JwtPayload } from '@/modules/auth/types/jwt-payload.interface';
import { type User } from '@/modules/users/entities/user.entity';
import { UsersService } from '@/modules/users/users.service';

describe('JwtStrategy', () => {
  let strategy: JwtStrategy;
  let findByEmail: jest.Mock;

  const payload: JwtPayload = { sub: 1, email: 'user@example.com', role: Role.User };
  const mockUser: User = {
    id: 1,
    email: 'user@example.com',
    password: 'hashed',
    name: 'User',
    role: Role.User,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    findByEmail = jest.fn();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JwtStrategy,
        { provide: UsersService, useValue: { findByEmail } },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('test-secret') } },
      ],
    }).compile();

    strategy = module.get(JwtStrategy);
  });

  describe('validate', () => {
    it('payload 의 이메일로 조회된 사용자를 반환한다', async () => {
      findByEmail.mockResolvedValue(mockUser);

      await expect(strategy.validate(payload)).resolves.toBe(mockUser);
      expect(findByEmail).toHaveBeenCalledWith(payload.email);
    });

    it('사용자가 없으면 UnauthorizedException 을 던진다', async () => {
      findByEmail.mockResolvedValue(null);

      await expect(strategy.validate(payload)).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });
});
