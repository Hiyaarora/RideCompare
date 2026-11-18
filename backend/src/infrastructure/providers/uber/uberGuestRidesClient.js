import axios from 'axios';
import { PROVIDERS } from '../../../domain/rideTypes.js';
import { UpstreamError } from '../../../domain/errors.js';
import { categoryFromName, liveOption, upstreamStatus } from '../normalize.js';

const MILES_TO_KM = 1.609344;

/**
 * Uber for Business "Guest Rides" estimates (the current business API for fares + pickup ETAs):
 *   POST /v1/guests/trips/estimates   (OAuth scope guests.trips, header x-uber-organizationuuid)
 * https://developer.uber.com/docs/guest-rides/references/api/v1/guest-trips-estimates-post
 *
 * Returns an upfront `fare` (fixed price) when Uber offers one, otherwise an `estimate` range.
 * Requires an Uber for Business organisation with API access approved by Uber.
 */
export class UberGuestRidesClient {
  mode = 'guest-rides';

  constructor({ oauth, organizationUuid, baseUrl, timeoutMs, http, now = () => new Date() }) {
    this.oauth = oauth;
    this.organizationUuid = organizationUuid;
    this.http = http ?? axios.create({ baseURL: baseUrl, timeout: timeoutMs });
    this.now = now;
  }

  async getEstimates({ pickup, drop }) {
    const token = await this.oauth.token();
    let data;
    try {
      ({ data } = await this.http.post(
        '/v1/guests/trips/estimates',
        { pickup: { latitude: pickup.lat, longitude: pickup.lng }, dropoff: { latitude: drop.lat, longitude: drop.lng } },
        { headers: { Authorization: `Bearer ${token}`, 'x-uber-organizationuuid': this.organizationUuid, 'Accept-Language': 'en' } },
      ));
    } catch (err) {
      throw new UpstreamError('uber', `guest trip estimates failed (${upstreamStatus(err)})`);
    }
    const fetchedAt = this.now().toISOString();
    return (data.product_estimates ?? [])
      .map(({ product = {}, estimate_info: info = {} }) => {
        const trip = info.trip ?? {};
        const toKm = trip.distance_unit === 'km' ? 1 : MILES_TO_KM;
        const dist = trip.travel_distance_estimate ?? trip.distance_estimate;
        return liveOption({
          provider: PROVIDERS.uber,
          productCode: product.product_id,
          productName: product.display_name,
          description: product.short_description ?? product.description ?? '',
          category: categoryFromName(`${product.display_name} ${product.product_group ?? ''}`),
          capacity: product.capacity,
          upfront: info.fare?.value,
          low: info.estimate?.low_estimate,
          high: info.estimate?.high_estimate,
          currency: info.fare?.currency_code ?? info.estimate?.currency_code ?? 'INR',
          pickupEtaMin: info.pickup_estimate,
          tripDurationMin: trip.duration_estimate == null ? null : trip.duration_estimate / 60,
          distanceKm: dist == null ? null : dist * toKm,
          available: !info.no_cars_available && info.pickup_estimate != null,
          surgeMultiplier: info.estimate?.surge_multiplier ?? 1,
          fetchedAt,
        });
      })
      .filter(Boolean);
  }
}
