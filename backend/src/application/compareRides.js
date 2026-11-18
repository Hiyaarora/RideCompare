import { randomUUID } from 'node:crypto';
import { UpstreamError, ValidationError } from '../domain/errors.js';
import { CATEGORIES, LIVE_PRICING_UNAVAILABLE, PROVIDER_IDS, PROVIDER_STATUS } from '../domain/rideTypes.js';
import { DemoMapsClient } from '../infrastructure/maps/demoMapsClient.js';
import { haversineKm } from '../infrastructure/maps/geo.js';

const MIN_TRIP_KM = 0.1;
const MAX_TRIP_KM = 150;

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new UpstreamError(label, `timed out after ${ms} ms`, { status: 504 })), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

const totalTripMinutes = (o) => (o.pickupEtaMin ?? 0) + (o.tripDurationMin ?? 0);

/**
 * Use case: compare ride options for one trip across all requested providers.
 * Only authorised live APIs are queried (in parallel). Nothing is estimated or invented: a provider
 * without a live integration is reported as "Live pricing unavailable".
 */
export class CompareRidesService {
  constructor({ maps, providers, searches, timeoutMs = 6000, logger = console, now = () => new Date() }) {
    this.maps = maps;
    this.providers = providers;
    this.searches = searches;
    this.timeoutMs = timeoutMs;
    this.logger = logger;
    this.now = now;
    this.fallbackMaps = new DemoMapsClient({ now });
  }

  async #route(pickup, drop) {
    try {
      return await withTimeout(this.maps.route(pickup, drop), this.timeoutMs, 'maps');
    } catch (err) {
      if (!(err instanceof UpstreamError)) throw err;
      this.logger.warn(`[compare] routing failed, using estimated route: ${err.message}`);
      return this.fallbackMaps.route(pickup, drop);
    }
  }

  async compare({ pickup, drop, providers = PROVIDER_IDS, categories = CATEGORIES }) {
    const straightKm = haversineKm(pickup, drop);
    if (straightKm < MIN_TRIP_KM) {
      throw new ValidationError('Pickup and destination are the same place', { reason: 'SAME_LOCATION' });
    }
    if (straightKm > MAX_TRIP_KM) {
      const km = Math.round(straightKm).toLocaleString('en-IN');
      throw new ValidationError(
        `Your pickup and destination are about ${km} km apart. RideCompare compares city rides up to ${MAX_TRIP_KM} km. ` +
          `If your pickup says "Current location", check that your device location is correct, or choose a different pickup.`,
        { reason: 'TOO_FAR', distanceKm: Number(straightKm.toFixed(1)), maxKm: MAX_TRIP_KM },
      );
    }

    const now = this.now();
    const route = await this.#route(pickup, drop);
    const ctx = { pickup, drop, route, categories, now };

    const selected = providers.map((id) => this.providers.get(id)).filter(Boolean);
    const live = selected.filter((p) => p.isConfigured);
    // Every configured provider is asked at the same time; one failing never affects the others.
    const settled = await Promise.allSettled(live.map((p) => withTimeout(p.getEstimates(ctx), this.timeoutMs, p.id)));
    const results = new Map(live.map((p, i) => [p.id, settled[i]]));
    const fetchedAt = new Date().toISOString();

    const providerStatus = [];
    const options = [];
    for (const p of selected) {
      const base = { id: p.id, name: p.name, live: p.isConfigured, fetchedAt };
      const r = results.get(p.id);
      if (!r) {
        providerStatus.push({ ...base, status: PROVIDER_STATUS.UNAVAILABLE, optionCount: 0, message: LIVE_PRICING_UNAVAILABLE, reason: p.unavailableReason });
      } else if (r.status === 'fulfilled') {
        options.push(...r.value);
        providerStatus.push({
          ...base,
          status: r.value.length ? PROVIDER_STATUS.OK : PROVIDER_STATUS.NO_SERVICE,
          optionCount: r.value.length,
          message: r.value.length ? null : 'No rides available for this trip right now',
        });
      } else {
        this.logger.warn(`[compare] ${p.id} failed: ${r.reason?.message}`);
        providerStatus.push({
          ...base,
          status: PROVIDER_STATUS.ERROR,
          optionCount: 0,
          message: 'Could not get live prices. Try refreshing.',
          reason: r.reason?.message?.replace(/^\w+: /, '') ?? 'unknown error',
        });
      }
    }

    // Bookable options first, then cheapest, then quickest overall.
    options.sort(
      (a, b) => Number(b.available) - Number(a.available) || a.fare.min - b.fare.min || a.fare.max - b.fare.max || totalTripMinutes(a) - totalTripMinutes(b),
    );
    const bookable = options.filter((o) => o.available);
    const fastest = bookable.reduce((best, o) => (!best || totalTripMinutes(o) < totalTripMinutes(best) ? o : best), null);

    const comparison = {
      requestId: randomUUID(),
      generatedAt: now.toISOString(),
      // 'live' = at least one real price; 'unavailable' = no authorised source returned prices.
      dataMode: options.length ? 'live' : 'unavailable',
      pickup,
      drop,
      route,
      providers: providerStatus,
      options,
      cheapestOptionId: bookable[0]?.id ?? null,
      fastestOptionId: fastest?.id ?? null,
    };

    // History is best-effort and must never slow down or fail the response.
    this.searches?.save(comparison).catch(() => {});
    return comparison;
  }
}
