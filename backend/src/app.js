import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import morgan from 'morgan';
import { CompareRidesService } from './application/compareRides.js';
import { PlacesService } from './application/placesService.js';
import { errorHandler, notFound } from './interfaces/http/middleware/errorHandler.js';
import { requestId } from './interfaces/http/middleware/requestId.js';
import { apiRouter } from './interfaces/http/routes/index.js';

/**
 * Builds the Express app from its dependencies (composition root lives in server.js),
 * so tests can inject fakes for maps, providers and storage.
 */
export function createApp({ config, maps, providers, searches, logger = console, now }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 'loopback');

  app.use(requestId);
  app.use(helmet());
  app.use(cors({ origin: config.corsOrigins.length ? config.corsOrigins : false }));
  app.use(express.json({ limit: '10kb' }));
  if (config.env !== 'test') {
    morgan.token('id', (req) => req.id);
    app.use(morgan(':id :method :url :status :response-time ms'));
  }

  app.use(
    '/api/',
    rateLimit({
      windowMs: 60_000,
      limit: config.env === 'test' ? 1000 : 120,
      standardHeaders: 'draft-8',
      legacyHeaders: false,
      handler: (req, res) =>
        res.status(429).json({ error: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.', requestId: req.id } }),
    }),
  );

  const compareService = new CompareRidesService({ maps, providers, searches, timeoutMs: config.upstreamTimeoutMs, logger, now });
  const placesService = new PlacesService({ maps });

  app.use('/api/v1', apiRouter({ compareService, placesService, providers, searches, startedAt: Date.now() }));
  app.use(notFound);
  app.use(errorHandler(logger, { exposeInternals: config.env === 'development' }));
  return app;
}
