import { Role } from '@/common/enums/role.enum';

export interface JwtPayload {
  /** subject — 사용자 ID */
  sub: number;
  email: string;
  role: Role;
}
