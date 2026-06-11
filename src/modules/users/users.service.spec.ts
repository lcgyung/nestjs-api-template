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
  let remove: jest.Mock;

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
    remove = jest.fn();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: { findOne, findAndCount, create, save, remove },
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

  describe('update', () => {
    it('비밀번호가 없으면 재해시 없이 병합하여 저장한다', async () => {
      findOne.mockResolvedValue({ ...mockUser });
      save.mockImplementation((entity) => Promise.resolve(entity));

      const result = await service.update(1, { name: 'Updated' });

      expect(result.name).toBe('Updated');
      expect(result.password).toBe('hashed');
      expect(save).toHaveBeenCalled();
    });

    it('비밀번호가 있으면 bcrypt 로 재해시하여 저장한다', async () => {
      findOne.mockResolvedValue({ ...mockUser });
      save.mockImplementation((entity) => Promise.resolve(entity));

      const result = await service.update(1, { password: 'newpassword123' });

      expect(result.password).not.toBe('newpassword123');
      expect(await bcrypt.compare('newpassword123', result.password)).toBe(true);
    });

    it('대상이 없으면 NotFoundException 을 던진다', async () => {
      findOne.mockResolvedValue(null);
      await expect(service.update(999, { name: 'X' })).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('remove', () => {
    it('대상을 찾아 repository.remove 로 삭제한다', async () => {
      const target = { ...mockUser };
      findOne.mockResolvedValue(target);
      remove.mockResolvedValue(target);

      await service.remove(1);

      expect(remove).toHaveBeenCalledWith(target);
    });

    it('대상이 없으면 NotFoundException 을 던진다', async () => {
      findOne.mockResolvedValue(null);
      await expect(service.remove(999)).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
