import { AppError, NotFoundError } from '../../../domain/errors.js';

export function notFound(req, _res, next) {
  next(new NotFoundError(`Route not found: ${req.method} ${req.path}`));
}

/**
 * Centralised error handler. Every error leaves the API in one shape:
 *   { error: { code, message, details?, requestId } }
 * Internal details (stack traces, upstream responses, keys) are never sent to clients.
 */
// eslint-disable-next-line no-unused-vars
export function errorHandler(logger, { exposeInternals = false } = {}) {
  return (err, req, res, _next) => {
    let status = 500;
    let code = 'INTERNAL_ERROR';
    let message = 'Something went wrong. Please try again.';
    let details;

    if (err instanceof AppError) {
      ({ status, code, message, details } = err);
    } else if (err?.type === 'entity.parse.failed') {
      [status, code, message] = [400, 'INVALID_JSON', 'Request body is not valid JSON'];
    } else if (err?.type === 'entity.too.large') {
      [status, code, message] = [413, 'PAYLOAD_TOO_LARGE', 'Request body is too large'];
    }

    if (status >= 500) logger.error(`[${req.id}] ${req.method} ${req.originalUrl} -> ${status} ${err?.stack ?? err}`);

    const body = { error: { code, message, requestId: req.id } };
    if (details !== undefined) body.error.details = details;
    if (exposeInternals && status === 500) body.error.debug = String(err?.message ?? err);
    res.status(status).json(body);
  };
}
