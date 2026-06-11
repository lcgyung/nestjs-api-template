import { randomUUID } from 'node:crypto';

import { Injectable, type NestMiddleware } from '@nestjs/common';
import { type NextFunction, type Request, type Response } from 'express';

import { requestContextStorage } from '@/common/context/request-context';

export const REQUEST_ID_HEADER = 'x-request-id';

/** 인입 id 수용 조건 — 로그 인젝션·과대 길이 방지 */
const VALID_REQUEST_ID = /^[\w.-]{1,64}$/;

@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    const incoming = req.header(REQUEST_ID_HEADER);
    const requestId = incoming && VALID_REQUEST_ID.test(incoming) ? incoming : randomUUID();

    res.setHeader(REQUEST_ID_HEADER, requestId);
    requestContextStorage.run({ requestId }, next);
  }
}
