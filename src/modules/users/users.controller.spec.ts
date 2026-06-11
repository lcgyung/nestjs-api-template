import { Test, type TestingModule } from '@nestjs/testing';

import { PaginatedResponseDto } from '@/common/dto/paginated-response.dto';
import { Role } from '@/common/enums/role.enum';
import { type CreateUserDto } from '@/modules/users/dto/create-user.dto';
import { type UpdateUserDto } from '@/modules/users/dto/update-user.dto';
import { type User } from '@/modules/users/entities/user.entity';
import { UsersController } from '@/modules/users/users.controller';
import { UsersService } from '@/modules/users/users.service';

describe('UsersController', () => {
  let controller: UsersController;
  let create: jest.Mock;
  let findAll: jest.Mock;
  let findOne: jest.Mock;
  let update: jest.Mock;
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
    create = jest.fn();
    findAll = jest.fn();
    findOne = jest.fn();
    update = jest.fn();
    remove = jest.fn();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: { create, findAll, findOne, update, remove },
        },
      ],
    }).compile();

    controller = module.get(UsersController);
  });

  describe('getMe', () => {
    it('주입된 현재 사용자를 그대로 반환한다', () => {
      expect(controller.getMe(mockUser)).toBe(mockUser);
    });
  });

  describe('create', () => {
    it('DTO 를 usersService.create 에 위임하고 결과를 반환한다', async () => {
      const dto: CreateUserDto = { email: 'new@example.com', password: 'password123' };
      create.mockResolvedValue(mockUser);

      await expect(controller.create(dto)).resolves.toBe(mockUser);
      expect(create).toHaveBeenCalledWith(dto);
    });
  });

  describe('findAll', () => {
    it('페이지네이션 쿼리를 usersService.findAll 에 전달한다', async () => {
      const query = { page: 2, limit: 10 };
      const response = new PaginatedResponseDto([mockUser], 1, query);
      findAll.mockResolvedValue(response);

      await expect(controller.findAll(query)).resolves.toBe(response);
      expect(findAll).toHaveBeenCalledWith(query);
    });
  });

  describe('findOne', () => {
    it('id 를 usersService.findOne 에 위임한다', async () => {
      findOne.mockResolvedValue(mockUser);

      await expect(controller.findOne(1)).resolves.toBe(mockUser);
      expect(findOne).toHaveBeenCalledWith(1);
    });
  });

  describe('update', () => {
    it('id 와 DTO 를 usersService.update 에 위임한다', async () => {
      const dto: UpdateUserDto = { name: 'Updated' };
      update.mockResolvedValue(mockUser);

      await expect(controller.update(1, dto)).resolves.toBe(mockUser);
      expect(update).toHaveBeenCalledWith(1, dto);
    });
  });

  describe('remove', () => {
    it('id 를 usersService.remove 에 위임한다', async () => {
      remove.mockResolvedValue(undefined);

      await controller.remove(1);
      expect(remove).toHaveBeenCalledWith(1);
    });
  });
});
