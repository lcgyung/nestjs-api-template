import { type NextFunction, type Request, type Response } from 'express';

import { getRequestId } from '@/common/context/request-context';
import { REQUEST_ID_HEADER, RequestIdMiddleware } from '@/common/middleware/request-id.middleware';

describe('RequestIdMiddleware', () => {
  let middleware: RequestIdMiddleware;
  let setHeader: jest.Mock;

  const buildReq = (incoming?: string): Request =>
    ({ header: jest.fn().mockReturnValue(incoming) }) as unknown as Request;

  const buildRes = (): Response => {
    setHeader = jest.fn();
    return { setHeader } as unknown as Response;
  };

  beforeEach(() => {
    middleware = new RequestIdMiddleware();
  });

  it('헤더가 없으면 UUID 를 생성해 컨텍스트·응답 헤더에 싣는다', () => {
    let insideId: string | undefined;
    const next: NextFunction = () => {
      insideId = getRequestId();
    };

    middleware.use(buildReq(undefined), buildRes(), next);

    expect(insideId).toMatch(/^[0-9a-f-]{36}$/);
    expect(setHeader).toHaveBeenCalledWith(REQUEST_ID_HEADER, insideId);
  });

  it('유효한 인입 x-request-id 는 그대로 수용한다', () => {
    let insideId: string | undefined;
    const next: NextFunction = () => {
      insideId = getRequestId();
    };

    middleware.use(buildReq('client-trace.001'), buildRes(), next);

    expect(insideId).toBe('client-trace.001');
    expect(setHeader).toHaveBeenCalledWith(REQUEST_ID_HEADER, 'client-trace.001');
  });

  it('형식 위반(64자 초과·허용 외 문자) id 는 버리고 새로 생성한다', () => {
    let insideId: string | undefined;
    const next: NextFunction = () => {
      insideId = getRequestId();
    };

    middleware.use(buildReq('bad id\nwith newline'), buildRes(), next);

    expect(insideId).toBeDefined();
    expect(insideId).not.toBe('bad id\nwith newline');
    expect(insideId).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('요청 컨텍스트 밖에서는 getRequestId 가 undefined 다', () => {
    expect(getRequestId()).toBeUndefined();
  });
});
