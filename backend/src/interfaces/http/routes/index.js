import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import {
  autocompleteQuery,
  compareBody,
  placeParams,
  placeQuery,
  recentQuery,
  reverseQuery,
} from '../schemas.js';

/** Version 1 of the REST API. Handlers stay thin: parse, call a use case, respond. */
export function apiRouter({ compareService, placesService, providers, searches, startedAt }) {
  const r = Router();

  const providerList = () => [...providers.values()].map((p) => p.describe());

  r.get('/health', (_req, res) => {
    res.json({
      status: 'ok',
      uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
      database: searches.available ? 'up' : 'down',
      maps: placesService.source,
      providers: providerList(),
    });
  });

  r.get('/providers', (_req, res) => res.json({ providers: providerList() }));

  r.get('/places/autocomplete', validate(autocompleteQuery, 'query'), async (req, res) => {
    const suggestions = await placesService.autocomplete(req.valid.query);
    res.json({ source: placesService.source, suggestions });
  });

  r.get('/places/reverse', validate(reverseQuery, 'query'), async (req, res) => {
    res.json({ source: placesService.source, place: await placesService.reverse(req.valid.query) });
  });

  r.get('/places/:placeId', validate(placeParams, 'params'), validate(placeQuery, 'query'), async (req, res) => {
    const place = await placesService.details(req.valid.params.placeId, req.valid.query.sessionToken);
    res.json({ source: placesService.source, place });
  });

  r.post('/compare', validate(compareBody), async (req, res) => {
    res.json(await compareService.compare(req.valid.body));
  });

  r.get('/searches/recent', validate(recentQuery, 'query'), async (req, res) => {
    res.json({ available: searches.available, searches: await searches.recent(req.valid.query.limit) });
  });

  return r;
}
