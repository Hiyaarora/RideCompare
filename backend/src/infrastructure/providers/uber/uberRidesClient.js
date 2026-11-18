import axios from 'axios';
import { PROVIDERS } from '../../../domain/rideTypes.js';
import { UpstreamError } from '../../../domain/errors.js';
import { categoryFromName, liveOption, upstreamStatus } from '../normalize.js';

const MILES_TO_KM = 1.609344;

/**
 * Uber Riders API (older, approval-only):
 *   GET /v1.2/estimates/price  +  GET /v1.2/estimates/time   (Authorization: Token <server token>)
 * https://developer.uber.com/docs/riders/references/api/v1.2/estimates-price-get
 * Uber's docs: access requires approval, and price comparison with competitors violates § II B of the
 * API Terms unless Uber permits it in writing.
 */
export class UberRidesClient {
  mode = 'riders-api';

  constructor({ serverToken, baseUrl, timeoutMs, http, now = () => new Date() }) {
    this.http =
      http ?? axios.create({ baseURL: baseUrl, timeout: timeoutMs, headers: { Authorization: `Token ${serverToken}`, 'Accept-Language': 'en_US' } });
    this.now = now;
  }

  async getEstimates({ pickup, drop }) {
    let priceRes, timeRes;
    try {
      [priceRes, timeRes] = await Promise.all([
        this.http.get('/v1.2/estimates/price', {
          params: { start_latitude: pickup.lat, start_longitude: pickup.lng, end_latitude: drop.lat, end_longitude: drop.lng },
        }),
        // ETAs are optional: a failure here must not lose the prices.
        this.http.get('/v1.2/estimates/time', { params: { start_latitude: pickup.lat, start_longitude: pickup.lng } }).catch(() => ({ data: {} })),
      ]);
    } catch (err) {
      throw new UpstreamError('uber', `price estimates failed (${upstreamStatus(err)})`);
    }
    const eta = new Map((timeRes.data.times ?? []).map((t) => [t.product_id, t.estimate]));
    const fetchedAt = this.now().toISOString();
    return (priceRes.data.prices ?? [])
      .map((p) =>
        liveOption({
          provider: PROVIDERS.uber,
          productCode: p.product_id,
          productName: p.localized_display_name ?? p.display_name,
          category: categoryFromName(p.display_name),
          low: p.low_estimate,
          high: p.high_estimate,
          currency: p.currency_code ?? 'INR',
          pickupEtaMin: eta.has(p.product_id) ? eta.get(p.product_id) / 60 : null,
          tripDurationMin: p.duration == null ? null : p.duration / 60,
          distanceKm: p.distance == null ? null : p.distance * MILES_TO_KM,
          available: eta.size === 0 || eta.has(p.product_id),
          surgeMultiplier: p.surge_multiplier ?? 1,
          fetchedAt,
        }),
      )
      .filter(Boolean);
  }
}
