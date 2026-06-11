import { type INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, type TestingModule } from '@nestjs/testing';
import { ThrottlerGuard } from '@nestjs/throttler';
import cookieParser from 'cookie-parser';
import request from 'supertest';

import { AppModule } from '@/app.module';
import { VALIDATION_PIPE_OPTIONS } from '@/common/pipes/validation-pipe.options';

/**
 * 실제 DB(또는 테스트 컨테이너) + 시드된 admin 계정이 필요하다.
 * CI: migration:run → seed → test:e2e 순서로 실행.
 */
describe('Auth & Users (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      // 한 IP 에서 다수 로그인 호출이 일어나 로그인 throttle(분당 5)에 걸리므로 e2e 에선 비활성.
      .overrideGuard(ThrottlerGuard)
      .useValue({ canActivate: () => true })
      .compile();

    app = moduleFixture.createNestApplication();
    app.use(cookieParser());
    app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/health (GET) → 200', () => {
    return request(app.getHttpServer()).get('/health').expect(200);
  });

  it('/health/liveness (GET) → 200 (무의존)', () => {
    return request(app.getHttpServer()).get('/health/liveness').expect(200);
  });

  it('/health/readiness (GET) → 200 (DB ping)', () => {
    return request(app.getHttpServer()).get('/health/readiness').expect(200);
  });

  it('로그인 → httpOnly 쿠키 발급 → 쿠키로 /users/me 접근', async () => {
    const login = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'admin@example.com', password: 'password' })
      .expect(200);

    const cookies = login.headers['set-cookie'] as unknown as string[];
    const accessCookie = cookies.find((cookie) => cookie.startsWith('access_token='));
    expect(accessCookie).toBeDefined();
    expect(accessCookie).toMatch(/HttpOnly/i);
    expect(accessCookie).toMatch(/SameSite=Strict/i);

    const me = await request(app.getHttpServer())
      .get('/users/me')
      .set('Cookie', cookies)
      .expect(200);

    expect(me.body.email).toBe('admin@example.com');
    expect(me.body.password).toBeUndefined();
  });

  it('로그인 바디의 accessToken 으로 Bearer 폴백 접근', async () => {
    const login = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'admin@example.com', password: 'password' })
      .expect(200);

    const token = login.body.accessToken as string;
    expect(token).toBeDefined();

    const me = await request(app.getHttpServer())
      .get('/users/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(me.body.email).toBe('admin@example.com');
  });

  it('로그아웃 → 쿠키 만료 처리', async () => {
    const res = await request(app.getHttpServer()).post('/auth/logout').expect(200);

    const cookies = res.headers['set-cookie'] as unknown as string[];
    const cleared = cookies.find((cookie) => cookie.startsWith('access_token='));
    expect(cleared).toBeDefined();
    expect(res.body).toEqual({ success: true });
  });

  it('토큰 없이 /users/me → 401', () => {
    return request(app.getHttpServer()).get('/users/me').expect(401);
  });

  it('일반 사용자 토큰 → admin 라우트 403, 본인 /users/me 200', async () => {
    const userEmail = 'e2e-user@example.com';
    const userPassword = 'password1234';

    const adminLogin = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'admin@example.com', password: 'password' })
      .expect(200);
    const adminToken = adminLogin.body.accessToken as string;

    // admin 으로 일반 사용자 생성 — 이미 존재하면(반복 실행) 409 이며 아래 로그인이 핵심이라 무시.
    await request(app.getHttpServer())
      .post('/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ email: userEmail, password: userPassword, role: 'user' });

    const userLogin = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: userEmail, password: userPassword })
      .expect(200);
    const userToken = userLogin.body.accessToken as string;

    // admin 전용 목록 라우트 → 403
    await request(app.getHttpServer())
      .get('/users')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(403);

    // 본인 정보는 인증만 있으면 200
    const me = await request(app.getHttpServer())
      .get('/users/me')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);
    expect(me.body.email).toBe(userEmail);
  });

  it('DTO 에 없는 여분 필드 → 400 (forbidNonWhitelisted)', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'admin@example.com', password: 'password', isAdmin: true })
      .expect(400);

    expect(res.body).toMatchObject({
      statusCode: 400,
      error: 'Bad Request',
      path: '/auth/login',
    });
  });

  it('검증 실패한 로그인 바디 → 400 (표준 에러 형식)', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: 'not-an-email', password: '1' })
      .expect(400);

    expect(res.body).toMatchObject({
      statusCode: 400,
      error: 'Bad Request',
      path: '/auth/login',
    });
    expect(res.body.timestamp).toBeDefined();
  });
});
