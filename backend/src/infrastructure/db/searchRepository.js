import { isMongoUp } from './mongo.js';
import { Search } from './models/Search.js';

const pickPlace = ({ name, address, lat, lng }) => ({ name, address, lat, lng });

/** MongoDB-backed search history. Silently no-ops while the database is unavailable. */
export class MongoSearchRepository {
  constructor(logger = console) {
    this.logger = logger;
  }

  get available() {
    return isMongoUp();
  }

  async save(comparison) {
    if (!this.available) return;
    const cheapest = comparison.options.find((o) => o.id === comparison.cheapestOptionId);
    try {
      await Search.create({
        pickup: pickPlace(comparison.pickup),
        drop: pickPlace(comparison.drop),
        distanceKm: comparison.route.distanceKm,
        durationMin: comparison.route.durationMin,
        optionCount: comparison.options.length,
        cheapest: cheapest
          ? { provider: cheapest.provider, productName: cheapest.productName, fareMin: cheapest.fare.min }
          : undefined,
        dataMode: comparison.dataMode,
      });
    } catch (err) {
      this.logger.warn(`[searches] could not save: ${err.message}`);
    }
  }

  /** Most recent searches, one entry per distinct pickup → drop pair. */
  async recent(limit = 10) {
    if (!this.available) return [];
    const docs = await Search.find().sort({ createdAt: -1 }).limit(limit * 10).lean();
    return dedupeTrips(docs.map(({ _id, ...d }) => ({ id: String(_id), ...d }))).slice(0, limit);
  }
}

const tripKey = (s) => `${s.pickup.name}|${s.pickup.lat.toFixed(3)},${s.pickup.lng.toFixed(3)}>${s.drop.name}|${s.drop.lat.toFixed(3)},${s.drop.lng.toFixed(3)}`;

/** Keeps the first (newest) search for each trip. */
export function dedupeTrips(searches) {
  const seen = new Set();
  return searches.filter((s) => !seen.has(tripKey(s)) && seen.add(tripKey(s)));
}

/** In-memory implementation, used by tests. */
export class InMemorySearchRepository {
  items = [];
  available = true;
  async save(c) {
    this.items.unshift({ id: String(this.items.length + 1), pickup: pickPlace(c.pickup), drop: pickPlace(c.drop), createdAt: new Date() });
  }
  async recent(limit = 10) {
    return dedupeTrips(this.items).slice(0, limit);
  }
}
