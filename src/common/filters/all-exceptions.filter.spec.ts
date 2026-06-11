import {
  type ArgumentsHost,
  BadRequestException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';

import { AllExceptionsFilter } from '@/common/filters/all-exceptions.filter';

describe('AllExceptionsFilter', () => {
  let filter: AllExceptionsFilter;
  let status: jest.Mock;
  let json: jest.Mock;
  let errorSpy: jest.SpyInstance;

  const buildHost = (): ArgumentsHost =>
    ({
      switchToHttp: () => ({
        getResponse: () => ({ status, json }),
        getRequest: () => ({ url: '/test', method: 'GET' }),
      }),
    }) as unknown as ArgumentsHost;

  beforeEach(() => {
    filter = new AllExceptionsFilter();
    json = jest.fn();
    status = jest.fn().mockReturnValue({ json });
    errorSpy = jest.spyOn(Logger.prototype, 'error').mockImplementation();
  });

  afterEach(() => {
    errorSpy.mockRestore();
  });

  it('HttpException(문자열 응답)을 상태코드·메시지로 매핑한다', () => {
    filter.catch(new HttpException('forbidden', HttpStatus.FORBIDDEN), buildHost());

    expect(status).toHaveBeenCalledWith(HttpStatus.FORBIDDEN);
    const body = json.mock.calls[0][0];
    expect(body).toMatchObject({
      statusCode: HttpStatus.FORBIDDEN,
      message: 'forbidden',
      path: '/test',
    });
    expect(body.timestamp).toBeDefined();
  });

  it('HttpException(객체 응답)의 message/error 를 사용한다', () => {
    filter.catch(new BadRequestException(['email must be an email']), buildHost());

    expect(status).toHaveBeenCalledWith(HttpStatus.BAD_REQUEST);
    const body = json.mock.calls[0][0];
    expect(body.message).toEqual(['email must be an email']);
    expect(body.error).toBe('Bad Request');
  });

  it('일반 Error 는 500 과 에러 메시지로 매핑한다', () => {
    filter.catch(new Error('boom'), buildHost());

    expect(status).toHaveBeenCalledWith(HttpStatus.INTERNAL_SERVER_ERROR);
    const body = json.mock.calls[0][0];
    expect(body.message).toBe('boom');
    expect(body.error).toBe('Internal Server Error');
  });

  it('알 수 없는 예외는 기본 500 본문으로 매핑한다', () => {
    filter.catch('weird', buildHost());

    expect(status).toHaveBeenCalledWith(HttpStatus.INTERNAL_SERVER_ERROR);
    const body = json.mock.calls[0][0];
    expect(body.message).toBe('Internal server error');
    expect(body.error).toBe('Internal Server Error');
  });

  it('5xx 응답은 logger.error 로 기록한다', () => {
    filter.catch(new Error('boom'), buildHost());

    expect(errorSpy).toHaveBeenCalled();
  });
});
