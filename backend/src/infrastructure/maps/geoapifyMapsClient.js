import axios from 'axios';
import { NotFoundError, UpstreamError } from '../../domain/errors.js';
import { round } from './geo.js';

/**
 * Search + reverse geocoding via Geoapify (OpenStreetMap-based).
 * Free plan: 3,000 credits/day, 5 req/s, no card, commercial use allowed with a
 * "Powered by Geoapify" credit near the results (the app shows it).
 * https://apidocs.geoapify.com/docs/geocoding/address-autocomplete/
 *
 * Routing is NOT done here: free OSRM handles routes, so Geoapify credits go to search only.
 * The API key is sent as a query parameter; error messages never include the request URL.
 */
export class GeoapifyMapsClient {
  source = 'geoapify';

  constructor({ apiKey, timeoutMs = 6000, baseUrl = 'https://api.geoapify.com', http } = {}) {
    if (!apiKey) throw new Error('GeoapifyMapsClient requires an API key');
    this.http = http ?? axios.create({ baseURL: baseUrl, timeout: timeoutMs });
    this.apiKey = apiKey;
    this.places = new Map(); // placeId -> place (bounded below)
  }

  async #get(label, path, params) {
    try {
      const { data } = await this.http.get(path, { params: { ...params, format: 'json', apiKey: this.apiKey } });
      return data;
    } catch (err) {
      const status = err.response?.status;
      const hint = status === 401 || status === 403 ? 'invalid API key' : status === 429 ? 'daily/rate limit reached' : '';
      throw new UpstreamError('geoapify', `${label} failed (${status ?? err.code ?? 'network'}${hint ? `: ${hint}` : ''})`);
    }
  }

  #remember(place) {
    if (this.places.size > 2000) this.places.delete(this.places.keys().next().value);
    this.places.set(place.placeId, place);
  }

  static toPlace(r) {
    const name = r.name || r.address_line1 || r.formatted?.split(',')[0] || 'Unnamed place';
    const line2 = r.address_line2 ?? r.formatted ?? '';
    const address = line2
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s && s !== name && s !== 'India')
      .join(', ');
    const placeId = r.place_id ? `geo:${r.place_id}` : `geo:@${Number(r.lat).toFixed(6)},${Number(r.lon).toFixed(6)}`;
    return { placeId, name, address, lat: Number(r.lat), lng: Number(r.lon) };
  }

  async autocomplete({ query, bias }) {
    const params = { text: query, lang: 'en', limit: 8, filter: 'countrycode:in' };
    if (bias) params.bias = `proximity:${bias.lng},${bias.lat}`;
    const data = await this.#get('autocomplete', '/v1/geocode/autocomplete', params);
    const seen = new Set();
    const out = [];
    for (const r of data.results ?? []) {
      const place = GeoapifyMapsClient.toPlace(r);
      const key = `${place.name}|${place.address}`;
      if (seen.has(key)) continue;
      seen.add(key);
      this.#remember(place);
      out.push({
        placeId: place.placeId,
        primaryText: place.name,
        secondaryText: place.address,
        distanceKm: typeof r.distance === 'number' ? round(r.distance / 1000, 1) : null,
      });
    }
    return out;
  }

  async placeDetails(placeId) {
    const cached = this.places.get(placeId);
    if (cached) return { ...cached };
    const coord = /^geo:@(-?\d+\.\d+),(-?\d+\.\d+)$/.exec(placeId);
    if (coord) return this.reverseGeocode({ lat: Number(coord[1]), lng: Number(coord[2]) });
    if (!placeId.startsWith('geo:')) throw new NotFoundError(`Unknown place: ${placeId}`);
    // Cache miss (e.g. after a restart): Place Details API returns GeoJSON features.
    let data;
    try {
      ({ data } = await this.http.get('/v2/place-details', { params: { id: placeId.slice(4), apiKey: this.apiKey } }));
    } catch (err) {
      throw new UpstreamError('geoapify', `place details failed (${err.response?.status ?? err.code ?? 'network'})`);
    }
    const p = data?.features?.[0]?.properties;
    if (!p) throw new NotFoundError(`Unknown place: ${placeId}`);
    return { ...GeoapifyMapsClient.toPlace(p), placeId };
  }

  async reverseGeocode({ lat, lng }) {
    const data = await this.#get('reverse geocode', '/v1/geocode/reverse', { lat, lon: lng, lang: 'en', limit: 1 });
    const r = data.results?.[0];
    if (!r) return { placeId: null, name: 'Pinned location', address: `${lat.toFixed(5)}, ${lng.toFixed(5)}`, lat, lng };
    const place = GeoapifyMapsClient.toPlace(r);
    return { ...place, placeId: null, lat, lng }; // keep the exact pin
  }

  async route() {
    throw new UpstreamError('geoapify', 'routing is handled by OSRM');
  }
}
