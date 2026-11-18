import axios from 'axios';
import { NotFoundError, UpstreamError } from '../../domain/errors.js';
import { citySpeedKmh } from './demoMapsClient.js';
import { decodePolyline, haversineKm, round } from './geo.js';

// India bounding box (minLon, minLat, maxLon, maxLat) to keep search results in-country.
const INDIA_BBOX = '68.1,6.5,97.5,35.7';

/** Small TTL cache so repeated keystrokes / selections don't hit the free public servers again. */
class TtlCache {
  constructor(max = 500, ttlMs = 10 * 60_000) {
    this.max = max;
    this.ttlMs = ttlMs;
    this.map = new Map();
  }
  get(k) {
    const e = this.map.get(k);
    if (!e) return undefined;
    if (e.exp < Date.now()) {
      this.map.delete(k);
      return undefined;
    }
    return e.v;
  }
  set(k, v) {
    if (this.map.size >= this.max) this.map.delete(this.map.keys().next().value);
    this.map.set(k, { v, exp: Date.now() + this.ttlMs });
  }
}

const uniq = (parts) => [...new Set(parts.filter(Boolean))];

/** Degrees around the user searched first (~50 km), so nearby places beat famous far-away ones. */
const LOCAL_RADIUS_DEG = 0.45;

/**
 * Lower = shown first among nearby results. Real destinations (airports, stations, malls,
 * colleges, parks) beat individual shops and road segments.
 */
export function placeRank(props = {}) {
  const k = props.osm_key;
  const v = props.osm_value;
  if (k === 'aeroway' || k === 'railway' || k === 'public_transport' || (k === 'shop' && v === 'mall')) return 0;
  if (['amenity', 'tourism', 'leisure', 'place', 'historic'].includes(k)) return 1;
  if (['building', 'office', 'landuse', 'shop', 'craft', 'boundary'].includes(k)) return 2;
  if (k === 'highway') return 3;
  return 2;
}

/** Turns a Photon (GeoJSON) feature into our place shape. */
export function placeFromPhotonFeature(f) {
  const p = f.properties ?? {};
  const [lng, lat] = f.geometry.coordinates;
  const street = [p.housenumber, p.street].filter(Boolean).join(' ');
  const name = p.name || street || p.district || p.locality || p.city || 'Unnamed place';
  const address = uniq([p.name ? street : null, p.locality, p.district, p.city ?? p.county, p.state])
    .filter((x) => x !== name)
    .join(', ');
  const placeId = p.osm_type && p.osm_id ? `osm:${p.osm_type}${p.osm_id}` : `osm:@${lat.toFixed(6)},${lng.toFixed(6)}`;
  return { placeId, name, address, lat, lng };
}

/**
 * FREE maps client built on OpenStreetMap services (no API key, no billing):
 *   - Photon (https://photon.komoot.io): search-as-you-type + reverse geocoding
 *   - Nominatim (https://nominatim.openstreetmap.org): place lookup by OSM id (cache miss only)
 *   - OSRM (https://router.project-osrm.org): driving distance, time and route geometry
 *
 * The public instances are "fair use" demo servers: fine for development, not for production
 * traffic. For launch, switch MAPS_PROVIDER=google (or self-host these services and point the
 * *_URL settings at your own servers). See docs/MAPS.md.
 */
export class OsmMapsClient {
  source = 'osm';

  constructor({
    timeoutMs = 6000,
    userAgent = 'RideCompare/1.0 (development)',
    photonUrl = 'https://photon.komoot.io',
    nominatimUrl = 'https://nominatim.openstreetmap.org',
    osrmUrl = 'https://router.project-osrm.org',
    now = () => new Date(),
    http,
  } = {}) {
    this.http = http ?? axios.create({ timeout: timeoutMs, headers: { 'User-Agent': userAgent, 'Accept-Language': 'en' } });
    this.urls = { photon: photonUrl, nominatim: nominatimUrl, osrm: osrmUrl };
    this.now = now;
    this.places = new TtlCache(2000, 60 * 60_000);
    this.searches = new TtlCache(500, 5 * 60_000);
  }

  async #call(label, fn) {
    try {
      return await fn();
    } catch (err) {
      if (err instanceof NotFoundError) throw err;
      throw new UpstreamError('osm', `${label} failed (${err.response?.status ?? err.code ?? 'network'})`);
    }
  }

  async autocomplete({ query, bias }) {
    const key = `${query.toLowerCase()}|${bias ? `${bias.lat.toFixed(2)},${bias.lng.toFixed(2)}` : ''}`;
    const cached = this.searches.get(key);
    if (cached) return cached;

    return this.#call('search', async () => {
      const search = (params) =>
        this.http.get(`${this.urls.photon}/api/`, { params: { q: query, lang: 'en', ...params } }).then((r) => r.data.features ?? []);

      // Nearby first (ranked by place type); only go India-wide when there aren't enough nearby
      // results. Usually one request per search, which keeps us within the free servers' fair use.
      let local = [];
      let national = [];
      if (bias) {
        const r = LOCAL_RADIUS_DEG;
        const box = [bias.lng - r, bias.lat - r, bias.lng + r, bias.lat + r].map((n) => n.toFixed(3)).join(',');
        local = await search({ lat: bias.lat, lon: bias.lng, limit: 12, bbox: box });
        local = local
          .map((f, i) => ({ f, i }))
          .sort((a, b) => placeRank(a.f.properties) - placeRank(b.f.properties) || a.i - b.i)
          .map((x) => x.f);
        if (local.length < 4) national = await search({ lat: bias.lat, lon: bias.lng, limit: 6, bbox: INDIA_BBOX });
      } else {
        national = await search({ limit: 8, bbox: INDIA_BBOX });
      }

      const seen = new Set();
      const out = [];
      for (const f of [...local, ...national]) {
        if (out.length >= 8) break;
        const place = placeFromPhotonFeature(f);
        // Roads come back as many segments: show each street name once.
        const dedupe = f.properties?.osm_key === 'highway' ? `road|${place.name}|${f.properties?.city ?? ''}` : `${place.name}|${place.address}`;
        if (seen.has(dedupe) || seen.has(place.placeId)) continue;
        seen.add(dedupe);
        seen.add(place.placeId);
        this.places.set(place.placeId, place);
        out.push({
          placeId: place.placeId,
          primaryText: place.name,
          secondaryText: place.address,
          distanceKm: bias ? round(haversineKm(bias, place), 1) : null,
        });
      }
      this.searches.set(key, out);
      return out;
    });
  }

  async placeDetails(placeId) {
    const cached = this.places.get(placeId);
    if (cached) return { ...cached };

    const coord = /^osm:@(-?\d+\.\d+),(-?\d+\.\d+)$/.exec(placeId);
    if (coord) return this.reverseGeocode({ lat: Number(coord[1]), lng: Number(coord[2]) });

    const m = /^osm:([NWR])(\d+)$/.exec(placeId);
    if (!m) throw new NotFoundError(`Unknown place: ${placeId}`);
    return this.#call('place lookup', async () => {
      const { data } = await this.http.get(`${this.urls.nominatim}/lookup`, {
        params: { osm_ids: `${m[1]}${m[2]}`, format: 'jsonv2' },
      });
      const r = data?.[0];
      if (!r) throw new NotFoundError(`Unknown place: ${placeId}`);
      const [first, ...rest] = r.display_name.split(',').map((s) => s.trim());
      const place = { placeId, name: r.name || first, address: rest.slice(0, 4).join(', '), lat: Number(r.lat), lng: Number(r.lon) };
      this.places.set(placeId, place);
      return place;
    });
  }

  async reverseGeocode({ lat, lng }) {
    const fallback = { placeId: null, name: 'Pinned location', address: `${lat.toFixed(5)}, ${lng.toFixed(5)}`, lat, lng };
    return this.#call('reverse geocode', async () => {
      const { data } = await this.http.get(`${this.urls.photon}/reverse`, { params: { lat, lon: lng, lang: 'en', limit: 1 } });
      const f = data.features?.[0];
      if (!f) return fallback;
      const place = placeFromPhotonFeature(f);
      // Keep the exact pin coordinates; the feature's centroid may be some distance away.
      return { ...place, placeId: null, lat, lng };
    });
  }

  async route(origin, destination) {
    return this.#call('route', async () => {
      const coords = `${origin.lng},${origin.lat};${destination.lng},${destination.lat}`;
      const { data } = await this.http.get(`${this.urls.osrm}/route/v1/driving/${coords}`, {
        params: { overview: 'full', geometries: 'polyline' },
      });
      const r = data.routes?.[0];
      if (data.code !== 'Ok' || !r) throw new NotFoundError('No drivable route between these points');
      const distanceKm = r.distance / 1000;
      // OSRM's public server has no live traffic, so its times are free-flow. Never show less
      // than typical Indian city traffic for this time of day.
      const trafficMin = (distanceKm / citySpeedKmh(this.now().getHours())) * 60;
      return {
        distanceKm: round(distanceKm, 1),
        durationMin: Math.max(1, Math.round(Math.max(r.duration / 60, trafficMin))),
        polyline: r.geometry ? decodePolyline(r.geometry) : [origin, destination],
        source: this.source,
      };
    });
  }
}
