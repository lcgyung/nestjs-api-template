import { SetMetadata } from '@nestjs/common';

import { type Role } from '@/common/enums/role.enum';

export const ROLES_KEY = 'roles';

/**
 * 핸들러/컨트롤러에 허용 역할을 지정한다. RolesGuard 와 함께 사용.
 * @example @Roles(Role.Admin)
 */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
