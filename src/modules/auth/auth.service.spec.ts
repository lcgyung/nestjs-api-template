import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import { Role } from '@/common/enums/role.enum';
import { User } from '@/modules/users/entities/user.entity';
import { UsersService } from '@/modules/users/users.service';
import { AuthService } from '@/modules/auth/auth.service';

describe('AuthService', () => {
  let service: AuthService;
  let findByEmail: jest.Mock;
  let signAsync: jest.Mock;
  let userRecord: User;

  beforeEach(async () => {
    findByEmail = jest.fn();
    signAsync = jest.fn();

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
        { provide: JwtService, useValue: { signAsync } },
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
});
