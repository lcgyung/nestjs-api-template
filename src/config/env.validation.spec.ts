import { NodeEnv, validate } from '@/config/env.validation';

describe('env validate()', () => {
  // process.env 처럼 모든 값이 문자열인 상태를 모사한다.
  const baseEnv = {
    DB_HOST: 'localhost',
    DB_PORT: '3306',
    DB_NAME: 'app',
    DB_USERNAME: 'root',
    DB_PASSWORD: 'password',
    JWT_SECRET: 'a-sufficiently-long-secret-1234',
    JWT_EXPIRES_IN: '1d',
    PORT: '3000',
  };

  it('유효한 env 는 통과하고 숫자 필드를 number 로 변환한다', () => {
    const config = validate(baseEnv);
    expect(config.PORT).toBe(3000);
    expect(typeof config.PORT).toBe('number');
    expect(config.DB_PORT).toBe(3306);
    expect(typeof config.DB_PORT).toBe('number');
    expect(config.NODE_ENV).toBe(NodeEnv.Development);
  });

  it('JWT_SECRET 이 16자 미만이면 throw 한다', () => {
    expect(() => validate({ ...baseEnv, JWT_SECRET: 'too-short' })).toThrow(/JWT_SECRET/);
  });

  it('필수 변수(DB_HOST)가 없으면 throw 한다', () => {
    const { DB_HOST: _omitted, ...withoutDbHost } = baseEnv;
    expect(() => validate(withoutDbHost)).toThrow(/환경 변수 검증 실패/);
  });

  it('PORT 범위를 벗어나면 throw 한다', () => {
    expect(() => validate({ ...baseEnv, PORT: '70000' })).toThrow(/PORT/);
  });
});
