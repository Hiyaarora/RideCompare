import { ValidationError } from '../../../domain/errors.js';

/**
 * Validates req[part] with a zod schema and stores the parsed value on req.valid[part].
 * (Express 5 makes req.query read-only, so we never overwrite it.)
 */
export const validate = (schema, part = 'body') => (req, _res, next) => {
  const result = schema.safeParse(req[part] ?? {});
  if (!result.success) {
    const details = result.error.issues.map((i) => ({ field: i.path.join('.') || part, message: i.message }));
    return next(new ValidationError('Invalid request', details));
  }
  req.valid = { ...(req.valid ?? {}), [part]: result.data };
  next();
};
