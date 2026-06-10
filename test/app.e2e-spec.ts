import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '@/app.module';

/**
 * 실제 DB(또는 테스트 컨테이너) + 시드된 admin 계정이 필요하다.
 * CI: migration:run → seed → test:e2e 순서로 실행.
 */
describe('Auth & Users (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/health (GET) → 200', () => {
    return request(app.getHttpServer()).get('/health').expect(200);
  });

  it('로그인 → accessToken → /users/me 흐름', async () => {
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
    expect(me.body.password).toBeUndefined();
  });

  it('토큰 없이 /users/me → 401', () => {
    return request(app.getHttpServer()).get('/users/me').expect(401);
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
