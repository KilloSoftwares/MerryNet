import winston from 'winston';
import { config } from '../config';

const { combine, timestamp, printf, colorize, json } = winston.format;

const devFormat = printf(({ level, message, timestamp, ...meta }) => {
  const metaStr = Object.keys(meta).length ? `\n${JSON.stringify(meta, null, 2)}` : '';
  return `${timestamp} [${level}]: ${message}${metaStr}`;
});

export const logger = winston.createLogger({
  level: config.logging.level,
  defaultMeta: { service: 'maranet-api' },
  transports: [
    new winston.transports.Console({
      format: config.env === 'development'
        ? combine(colorize(), timestamp({ format: 'HH:mm:ss' }), devFormat)
        : combine(timestamp(), json()),
    }),
    // File transport for production
    ...(config.env === 'production'
      ? [
          new winston.transports.File({
            filename: 'logs/error.log',
            level: 'error',
            format: combine(timestamp(), json()),
            maxsize: 10 * 1024 * 1024, // 10MB
            maxFiles: 5,
          }),
          new winston.transports.File({
            filename: 'logs/combined.log',
            format: combine(timestamp(), json()),
            maxsize: 10 * 1024 * 1024,
            maxFiles: 10,
          }),
        ]
      : []),
  ],
});
