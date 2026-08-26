import { HttpException, HttpStatus } from '@nestjs/common';
import type { ArgumentsHost } from '@nestjs/common';
import { ApiError } from '../errors/api-error';
import { AllExceptionsFilter } from './all-exceptions.filter';

interface Captured {
  status: number;
  body: { error: Record<string, unknown> };
}

function hostFor(query: Record<string, unknown> = {}): {
  host: ArgumentsHost;
  captured: () => Captured;
} {
  let status = 0;
  let body: { error: Record<string, unknown> } = { error: {} };
  const response = {
    status(code: number) {
      status = code;
      return this;
    },
    json(payload: { error: Record<string, unknown> }) {
      body = payload;
    },
  };
  const request = { method: 'GET', path: '/v1/x', query };
  const host = {
    switchToHttp: () => ({
      getResponse: () => response,
      getRequest: () => request,
    }),
  } as unknown as ArgumentsHost;
  return { host, captured: () => ({ status, body }) };
}

describe('AllExceptionsFilter', () => {
  it('passes an ApiError through unchanged, plus a correlation id', () => {
    const { host, captured } = hostFor();
    new AllExceptionsFilter().catch(new ApiError('ROOM_NOT_FOUND', 'de'), host);

    const { status, body } = captured();
    expect(status).toBe(404);
    expect(body.error).toMatchObject({ code: 'ROOM_NOT_FOUND' });
    expect(typeof body.error.requestId).toBe('string');
  });

  it('answers an unknown route with a neutral NOT_FOUND, not a post-specific text', () => {
    const { host, captured } = hostFor();
    new AllExceptionsFilter().catch(new HttpException('Not Found', HttpStatus.NOT_FOUND), host);

    const { status, body } = captured();
    expect(status).toBe(404);
    expect(body.error.code).toBe('NOT_FOUND');
    // Asking for an image or a missing route is not a statement about posts.
    expect(String(body.error.message)).not.toContain('Beitrag');
  });

  it('does not label a server-side HttpException as a validation problem', () => {
    const { host, captured } = hostFor();
    new AllExceptionsFilter().catch(
      new HttpException('upstream said no', HttpStatus.SERVICE_UNAVAILABLE),
      host,
    );

    const { status, body } = captured();
    expect(status).toBe(503);
    expect(body.error.code).not.toBe('VALIDATION_FAILED');
    expect(body.error.code).toBe('INTERNAL_ERROR');
  });

  it('still reports a 4xx below 404 as a validation problem, with its details', () => {
    const { host, captured } = hostFor();
    new AllExceptionsFilter().catch(
      new HttpException({ message: ['pageSize must be <= 50'] }, HttpStatus.BAD_REQUEST),
      host,
    );

    const { status, body } = captured();
    expect(status).toBe(400);
    expect(body.error.code).toBe('VALIDATION_FAILED');
    expect(body.error.details).toEqual(['pageSize must be <= 50']);
  });

  it('answers an unexpected exception generically and never leaks the cause', () => {
    const { host, captured } = hostFor();
    new AllExceptionsFilter().catch(new Error('connection string user:pw@db'), host);

    const { status, body } = captured();
    expect(status).toBe(500);
    expect(body.error.code).toBe('INTERNAL_ERROR');
    expect(JSON.stringify(body.error)).not.toContain('user:pw@db');
  });
});
