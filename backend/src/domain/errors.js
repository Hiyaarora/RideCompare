/** Application errors. The HTTP error handler maps these to JSON responses. */
export class AppError extends Error {
  constructor(message, { status = 500, code = 'INTERNAL_ERROR', details, cause } = {}) {
    super(message, { cause });
    this.name = this.constructor.name;
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export class ValidationError extends AppError {
  constructor(message = 'Invalid request', details) {
    super(message, { status: 400, code: 'VALIDATION_ERROR', details });
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Not found') {
    super(message, { status: 404, code: 'NOT_FOUND' });
  }
}

/** A third-party service (provider or maps) failed or timed out. */
export class UpstreamError extends AppError {
  constructor(service, message, { cause, status = 502 } = {}) {
    super(`${service}: ${message}`, { status, code: 'UPSTREAM_ERROR', cause, details: { service } });
    this.service = service;
  }
}

export class NoProvidersAvailableError extends AppError {
  constructor(details) {
    super('No ride provider could return estimates for this trip', {
      status: 502,
      code: 'NO_PROVIDERS_AVAILABLE',
      details,
    });
  }
}
