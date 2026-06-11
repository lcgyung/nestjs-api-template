import { utilities as nestWinstonModuleUtilities, type WinstonModuleOptions } from 'nest-winston';
import * as winston from 'winston';

import { getRequestId } from '@/common/context/request-context';

const isProduction = process.env.NODE_ENV === 'production';

/** 요청 컨텍스트의 request id 를 모든 로그 엔트리에 주입 (컨텍스트 밖 로그는 그대로) */
const requestIdFormat = winston.format((info) => {
  const requestId = getRequestId();
  if (requestId) {
    info.requestId = requestId;
  }
  return info;
});

export const winstonConfig: WinstonModuleOptions = {
  level: isProduction ? 'info' : 'debug',
  transports: [
    new winston.transports.Console({
      format: isProduction
        ? winston.format.combine(
            requestIdFormat(),
            winston.format.timestamp(),
            winston.format.json(),
          )
        : winston.format.combine(
            requestIdFormat(),
            winston.format.timestamp(),
            winston.format.ms(),
            nestWinstonModuleUtilities.format.nestLike('App', {
              colors: true,
              prettyPrint: true,
            }),
          ),
    }),
  ],
};
