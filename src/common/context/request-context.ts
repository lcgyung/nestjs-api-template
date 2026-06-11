import { AsyncLocalStorage } from 'node:async_hooks';

export interface RequestContext {
  requestId: string;
}

/** 요청 단위 컨텍스트 저장소 — RequestIdMiddleware 가 요청마다 run() 으로 초기화한다 */
export const requestContextStorage = new AsyncLocalStorage<RequestContext>();

/** 현재 요청의 id — 요청 컨텍스트 밖(부팅 로그 등)에서는 undefined */
export function getRequestId(): string | undefined {
  return requestContextStorage.getStore()?.requestId;
}
