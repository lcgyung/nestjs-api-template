import { Body, Controller, HttpCode, HttpStatus, Post, Res } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';

import { ACCESS_TOKEN_COOKIE, AuthService, LoginResponse } from '@/modules/auth/auth.service';
import { LoginDto } from '@/modules/auth/dto/login.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '로그인 → access_token httpOnly 쿠키 발급(+ 폴백용 바디 반환)' })
  async login(
    @Body() dto: LoginDto,
    @Res({ passthrough: true }) res: Response,
  ): Promise<LoginResponse> {
    const result = await this.authService.login(dto);
    res.cookie(
      ACCESS_TOKEN_COOKIE,
      result.accessToken,
      this.authService.buildCookieOptions(result.accessToken),
    );
    return result;
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '로그아웃 → access_token 쿠키 제거' })
  logout(@Res({ passthrough: true }) res: Response): { success: boolean } {
    res.clearCookie(ACCESS_TOKEN_COOKIE, this.authService.buildCookieOptions());
    return { success: true };
  }
}
