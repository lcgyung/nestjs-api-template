import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, type TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';

import { Role } from '@/common/enums/role.enum';
import { User } from '@/modules/users/entities/user.entity';
import { UsersService } from '@/modules/users/users.service';

describe('UsersService', () => {
  let service: UsersService;
  let findOne: jest.Mock;
  let findAndCount: jest.Mock;
  let create: jest.Mock;
  let save: jest.Mock;

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
    findOne = jest.fn();
    findAndCount = jest.fn();
    create = jest.fn();
    save = jest.fn();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: { findOne, findAndCount, create, save, remove: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(UsersService);
  });

  it('정의되어 있어야 한다', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('이메일이 중복되면 ConflictException 을 던진다', async () => {
      findOne.mockResolvedValue(mockUser);

      await expect(
        service.create({ email: mockUser.email, password: 'password123' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('비밀번호를 bcrypt 로 해싱하여 저장한다', async () => {
      findOne.mockResolvedValue(null);
      create.mockImplementation((dto) => dto);
      save.mockImplementation((entity) => Promise.resolve(entity));

      await service.create({ email: 'new@example.com', password: 'password123' });

      expect(create).toHaveBeenCalledTimes(1);
      const savedArg = create.mock.calls[0][0];
      expect(savedArg.password).not.toBe('password123');
      expect(await bcrypt.compare('password123', savedArg.password)).toBe(true);
      expect(save).toHaveBeenCalled();
    });
  });

  describe('findAll', () => {
    it('findAndCount 로 페이지네이션하여 { items, meta } 형태로 반환한다', async () => {
      findAndCount.mockResolvedValue([[mockUser], 1]);

      const result = await service.findAll({ page: 2, limit: 10 });

      expect(findAndCount).toHaveBeenCalledWith({
        skip: 10,
        take: 10,
        order: { id: 'DESC' },
      });
      expect(result.items).toEqual([mockUser]);
      expect(result.meta).toEqual({ page: 2, limit: 10, total: 1, totalPages: 1 });
    });
  });

  describe('findOne', () => {
    it('사용자가 없으면 NotFoundException 을 던진다', async () => {
      findOne.mockResolvedValue(null);
      await expect(service.findOne(999)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('사용자가 있으면 반환한다', async () => {
      findOne.mockResolvedValue(mockUser);
      await expect(service.findOne(1)).resolves.toEqual(mockUser);
    });
  });
});
