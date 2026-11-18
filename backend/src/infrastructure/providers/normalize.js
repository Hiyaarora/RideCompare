import { PRICE_TYPE } from '../../domain/rideTypes.js';

const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);

/**
 * Builds the one option shape the app understands, from fields a live API returned.
 * Returns null when the API gave no price, because a price is never invented.
 *
 * { id, provider, providerName, productCode, productName, description, category, capacity,
 *   priceType: 'upfront'|'estimate',
 *   fare: { min, max, upfront, currency },   // upfront: number when priceType=upfront, else null
 *   pickupEtaMin, tripDurationMin, distanceKm, available, surgeMultiplier,
 *   dataSource: 'live', fetchedAt }
 */
export function liveOption({
  provider,
  productCode,
  productName,
  description = '',
  category,
  capacity = null,
  upfront = null,
  low = null,
  high = null,
  currency = 'INR',
  pickupEtaMin = null,
  tripDurationMin = null,
  distanceKm = null,
  available = true,
  surgeMultiplier = 1,
  fetchedAt,
}) {
  const up = num(upfront);
  let min = num(low);
  let max = num(high);
  if (up == null && min == null && max == null) return null;
  if (up != null) min = max = up;
  else {
    min ??= max;
    max ??= min;
  }
  return {
    id: `${provider.id}:${productCode}`,
    provider: provider.id,
    providerName: provider.name,
    productCode: String(productCode),
    productName: productName || String(productCode),
    description,
    category,
    capacity: num(capacity),
    priceType: up != null ? PRICE_TYPE.UPFRONT : PRICE_TYPE.ESTIMATE,
    fare: { min: Math.round(min), max: Math.round(Math.max(min, max)), upfront: up == null ? null : Math.round(up), currency },
    pickupEtaMin: num(pickupEtaMin) == null ? null : Math.max(0, Math.round(pickupEtaMin)),
    tripDurationMin: num(tripDurationMin) == null ? null : Math.round(tripDurationMin),
    distanceKm: num(distanceKm) == null ? null : Math.round(distanceKm * 10) / 10,
    available: Boolean(available),
    surgeMultiplier: num(surgeMultiplier) ?? 1,
    dataSource: 'live',
    fetchedAt,
  };
}

/** Maps a provider's product name to our bike/auto/car buckets. */
export function categoryFromName(name = '') {
  const n = String(name).toLowerCase();
  if (/moto|bike|two.?wheeler/.test(n)) return 'bike';
  if (/auto|rickshaw|tuk/.test(n)) return 'auto';
  return 'car';
}

export const upstreamStatus = (err) => err.response?.status ?? err.code ?? 'network';
