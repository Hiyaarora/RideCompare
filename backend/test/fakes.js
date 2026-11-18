import { PROVIDERS } from '../src/domain/rideTypes.js';
import { RideProvider } from '../src/infrastructure/providers/RideProvider.js';
import { RapidoProvider } from '../src/infrastructure/providers/rapido/RapidoProvider.js';
import { liveOption } from '../src/infrastructure/providers/normalize.js';

/** A configured provider whose "live API" is a function (for compare-service tests). */
export function fakeLiveProvider(id, getEstimates) {
  return new RideProvider({ provider: PROVIDERS[id], client: { mode: 'fake', getEstimates }, unavailableReason: 'n/a' });
}

export const opt = (id, code, category, { low, high, upfront, eta = 4, trip = 20, available = true } = {}) =>
  liveOption({ provider: PROVIDERS[id], productCode: code, productName: `${PROVIDERS[id].name} ${code}`, category, low, high, upfront,
    pickupEtaMin: eta, tripDurationMin: trip, distanceKm: 6.1, available, fetchedAt: '2026-11-13T09:00:00.000Z' });

export function providersMap(...list) {
  return new Map(list.map((p) => [p.id, p]));
}

export { RapidoProvider };
