import axios from 'axios';
import { PROVIDERS } from '../../../domain/rideTypes.js';
import { UpstreamError } from '../../../domain/errors.js';
import { liveOption, upstreamStatus } from '../normalize.js';

export function olaCategoryFor(categoryId = '') {
  if (categoryId === 'bike') return 'bike';
  if (categoryId === 'auto') return 'auto';
  return 'car';
}

/**
 * Ola partner API, ride availability + estimate:
 *   GET /v1/products?pickup_lat&pickup_lng&drop_lat&drop_lng&service_type=p2p   (header X-APP-TOKEN)
 * https://developers.olacabs.com/docs/ride-estimate
 *
 * `ride_estimate[].amount_min/amount_max` is the estimate range; `ride_estimate[].upfront.fare` is a
 * fixed upfront price, returned only to whitelisted partners and with a user `Authorization: Bearer` token.
 * `categories[].eta == -1` means the category is unavailable near the pickup.
 */
export class OlaLiveClient {
  mode = 'partner-api';

  constructor({ appToken, userToken = '', baseUrl, timeoutMs, http, now = () => new Date() }) {
    const headers = { 'X-APP-TOKEN': appToken };
    if (userToken) headers.Authorization = `Bearer ${userToken}`;
    this.http = http ?? axios.create({ baseURL: baseUrl, timeout: timeoutMs, headers });
    this.now = now;
  }

  async getEstimates({ pickup, drop }) {
    let data;
    try {
      ({ data } = await this.http.get('/v1/products', {
        params: { pickup_lat: pickup.lat, pickup_lng: pickup.lng, drop_lat: drop.lat, drop_lng: drop.lng, service_type: 'p2p' },
      }));
    } catch (err) {
      throw new UpstreamError('ola', `ride estimate failed (${upstreamStatus(err)})`);
    }
    const categories = new Map((data.categories ?? []).map((c) => [c.id, c]));
    const fetchedAt = this.now().toISOString();
    return (data.ride_estimate ?? [])
      .map((e) => {
        const c = categories.get(e.category) ?? {};
        const up = e.upfront?.is_upfront_applicable ? e.upfront.fare : null;
        const eta = typeof c.eta === 'number' && c.eta >= 0 ? c.eta : null;
        return liveOption({
          provider: PROVIDERS.ola,
          productCode: e.category,
          productName: c.display_name ?? e.category,
          category: olaCategoryFor(e.category),
          upfront: up,
          low: e.amount_min,
          high: e.amount_max,
          currency: c.currency ?? 'INR',
          pickupEtaMin: eta,
          tripDurationMin: e.travel_time_in_minutes,
          distanceKm: e.distance,
          available: c.eta !== -1,
          fetchedAt,
        });
      })
      .filter(Boolean);
  }
}
