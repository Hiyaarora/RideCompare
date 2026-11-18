import { UpstreamError } from '../../domain/errors.js';

const MIN_SUGGESTIONS = 5;
const MAX_SUGGESTIONS = 8;

/** Same place from two services shows the same name at (almost) the same distance. */
const suggestionKey = (s) => `${s.primaryText.trim().toLowerCase()}|${s.distanceKm == null ? '' : Math.round(s.distanceKm)}`;

export function mergeSuggestions(existing, incoming) {
  const seen = new Set(existing.map(suggestionKey));
  const out = [...existing];
  for (const s of incoming) {
    if (out.length >= MAX_SUGGESTIONS) break;
    if (!seen.has(suggestionKey(s))) {
      seen.add(suggestionKey(s));
      out.push(s);
    }
  }
  return out;
}

/**
 * Combines several maps clients into fallback chains, e.g.
 *   search: Geoapify → Photon (free OSM) → offline landmarks
 *   route:  OSRM (free OSM)              → straight-line estimate
 *
 * If a client fails with an UpstreamError (outage, rate limit, IP block, bad key), the next one
 * answers instead, and the failed client is skipped for `cooldownMs` so it isn't hammered.
 * The last client in each chain should be the offline DemoMapsClient, which never fails.
 */
export class ResilientMapsClient {
  constructor({ search, route, cooldownMs = 60_000, logger = console, clock = () => Date.now() }) {
    this.chains = { search, route };
    this.cooldownMs = cooldownMs;
    this.logger = logger;
    this.clock = clock;
    this.downUntil = new Map(); // `${group}:${source}` -> timestamp
  }

  #available(group) {
    const now = this.clock();
    return this.chains[group].filter((c) => !(this.downUntil.get(`${group}:${c.source}`) > now));
  }

  /** Where search results currently come from (shown by /health and /places responses). */
  get source() {
    const [first] = this.#available('search');
    return (first ?? this.chains.search.at(-1)).source;
  }

  async #try(group, method, args) {
    const candidates = this.#available(group);
    const chain = candidates.length ? candidates : [this.chains[group].at(-1)];
    let lastError;
    let merged = null; // autocomplete only: results gathered so far
    for (const client of chain) {
      try {
        const result = await client[method](...args);
        if (method !== 'autocomplete') return result;
        // One service may know a place another doesn't. Keep asking the next service until we
        // have a reasonable list, merging and removing duplicates.
        merged = mergeSuggestions(merged ?? [], result);
        if (merged.length >= MIN_SUGGESTIONS) return merged;
      } catch (err) {
        if (!(err instanceof UpstreamError)) throw err; // e.g. NotFound is a real answer, not an outage
        lastError = err;
        this.downUntil.set(`${group}:${client.source}`, this.clock() + this.cooldownMs);
        this.logger.warn(`[maps] ${client.source} ${group} unavailable (${err.message}); trying next for ${this.cooldownMs / 1000}s`);
      }
    }
    if (merged) return merged;
    throw lastError;
  }

  autocomplete(args) {
    return this.#try('search', 'autocomplete', [args]);
  }

  reverseGeocode(args) {
    return this.#try('search', 'reverseGeocode', [args]);
  }

  route(origin, destination) {
    return this.#try('route', 'route', [origin, destination]);
  }

  /** Place ids carry their origin ("geo:", "osm:", "demo:"), so each is resolved by its issuer. */
  placeDetails(placeId, sessionToken) {
    const prefix = placeId.split(':')[0];
    const owner =
      this.chains.search.find((c) => ({ geoapify: 'geo', osm: 'osm', demo: 'demo', google: 'google' })[c.source] === prefix) ??
      this.chains.search[0];
    return owner.placeDetails(placeId, sessionToken);
  }
}
