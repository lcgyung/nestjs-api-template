import { Exclude } from 'class-transformer';
import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Role } from '@/common/enums/role.enum';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ unique: true })
  email!: string;

  /** bcrypt 해시. 직렬화 시 응답에서 제외된다(ClassSerializerInterceptor). */
  @Exclude()
  @Column()
  password!: string;

  @Column({ default: '' })
  name!: string;

  @Column({ type: 'enum', enum: Role, default: Role.User })
  role!: Role;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
