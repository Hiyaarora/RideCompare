import { NotFoundError } from '../../domain/errors.js';
import { DEMO_PLACES } from './demoPlaces.js';
import { haversineKm, round } from './geo.js';

const ROAD_FACTOR = 1.35; // typical ratio of road distance to straight-line distance in Indian cities

/** Average city speed (km/h) for the given local hour. */
export function citySpeedKmh(hour) {
  if ((hour >= 8 && hour < 11) || (hour >= 17 && hour < 21)) return 17; // peak
  if (hour >= 23 || hour < 6) return 32; // night
  return 24;
}

function interpolate(a, b, steps = 24) {
  return Array.from({ length: steps + 1 }, (_, i) => ({
    lat: round(a.lat + ((b.lat - a.lat) * i) / steps, 6),
    lng: round(a.lng + ((b.lng - a.lng) * i) / steps, 6),
  }));
}

/**
 * Maps client that needs no API key: searches a fixed landmark list and estimates routes
 * from straight-line distance. Used whenever GOOGLE_MAPS_API_KEY is not set.
 */
export class DemoMapsClient {
  source = 'demo';

  constructor({ now = () => new Date() } = {}) {
    this.now = now;
  }

  async autocomplete({ query, bias }) {
    const q = query.trim().toLowerCase();
    const tokens = q.split(/\s+/).filter(Boolean);
    return DEMO_PLACES.filter((p) => {
      const hay = `${p.name} ${p.address}`.toLowerCase();
      return tokens.every((t) => hay.includes(t));
    })
      .map((p) => ({
        placeId: p.placeId,
        primaryText: p.name,
        secondaryText: p.address,
        distanceKm: bias ? round(haversineKm(bias, p), 1) : null,
        // Prefer prefix matches on the name, then nearest.
        _score: (p.name.toLowerCase().startsWith(q) ? 0 : 1) * 10000 + (bias ? haversineKm(bias, p) : 0),
      }))
      .sort((a, b) => a._score - b._score)
      .slice(0, 8)
      .map(({ _score, ...rest }) => rest);
  }

  async placeDetails(placeId) {
    const p = DEMO_PLACES.find((x) => x.placeId === placeId);
    if (!p) throw new NotFoundError(`Unknown place: ${placeId}`);
    return { ...p };
  }

  async reverseGeocode({ lat, lng }) {
    let nearest = null;
    let best = Infinity;
    for (const p of DEMO_PLACES) {
      const d = haversineKm({ lat, lng }, p);
      if (d < best) [best, nearest] = [d, p];
    }
    if (nearest && best <= 1.5) {
      return { placeId: null, name: `Near ${nearest.name}`, address: nearest.address, lat, lng };
    }
    return { placeId: null, name: 'Pinned location', address: `${lat.toFixed(5)}, ${lng.toFixed(5)}`, lat, lng };
  }

  async route(origin, destination) {
    const distanceKm = Math.max(0.3, haversineKm(origin, destination) * ROAD_FACTOR);
    const speed = citySpeedKmh(this.now().getHours());
    return {
      distanceKm: round(distanceKm, 1),
      durationMin: Math.max(2, Math.round((distanceKm / speed) * 60)),
      polyline: interpolate(origin, destination),
      source: this.source,
    };
  }
}
