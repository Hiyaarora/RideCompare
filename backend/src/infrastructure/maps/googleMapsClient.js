import axios from 'axios';
import { NotFoundError, UpstreamError } from '../../domain/errors.js';
import { decodePolyline, round } from './geo.js';

/**
 * Google Maps Platform client (Places API (New), Geocoding API, Routes API).
 * The key stays on the server; the mobile app never sees it.
 */
export class GoogleMapsClient {
  source = 'google';

  constructor({ apiKey, timeoutMs = 6000, http } = {}) {
    if (!apiKey) throw new Error('GoogleMapsClient requires an API key');
    this.http =
      http ??
      axios.create({
        timeout: timeoutMs,
        headers: { 'X-Goog-Api-Key': apiKey, 'Content-Type': 'application/json' },
      });
    this.apiKey = apiKey;
  }

  async #call(label, fn) {
    try {
      return await fn();
    } catch (err) {
      if (err instanceof NotFoundError) throw err;
      const status = err.response?.status;
      if (status === 404) throw new NotFoundError(`${label}: not found`);
      // Never include the request config in the message: it contains the API key header.
      const msg = err.response?.data?.error?.message ?? err.code ?? 'request failed';
      throw new UpstreamError('google-maps', `${label} failed (${status ?? 'network'}): ${msg}`);
    }
  }

  async autocomplete({ query, bias, sessionToken }) {
    return this.#call('autocomplete', async () => {
      const body = { input: query, includedRegionCodes: ['in'], languageCode: 'en' };
      if (sessionToken) body.sessionToken = sessionToken;
      if (bias) {
        body.locationBias = { circle: { center: { latitude: bias.lat, longitude: bias.lng }, radius: 50000 } };
        body.origin = { latitude: bias.lat, longitude: bias.lng };
      }
      const { data } = await this.http.post('https://places.googleapis.com/v1/places:autocomplete', body);
      return (data.suggestions ?? [])
        .filter((s) => s.placePrediction)
        .map(({ placePrediction: p }) => ({
          placeId: p.placeId,
          primaryText: p.structuredFormat?.mainText?.text ?? p.text?.text ?? '',
          secondaryText: p.structuredFormat?.secondaryText?.text ?? '',
          distanceKm: typeof p.distanceMeters === 'number' ? round(p.distanceMeters / 1000, 1) : null,
        }));
    });
  }

  async placeDetails(placeId, sessionToken) {
    return this.#call('place details', async () => {
      const { data } = await this.http.get(`https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`, {
        params: sessionToken ? { sessionToken } : undefined,
        headers: { 'X-Goog-FieldMask': 'id,displayName,formattedAddress,location' },
      });
      return {
        placeId: data.id,
        name: data.displayName?.text ?? data.formattedAddress,
        address: data.formattedAddress ?? '',
        lat: data.location.latitude,
        lng: data.location.longitude,
      };
    });
  }

  async reverseGeocode({ lat, lng }) {
    return this.#call('reverse geocode', async () => {
      const { data } = await this.http.get('https://maps.googleapis.com/maps/api/geocode/json', {
        params: { latlng: `${lat},${lng}`, key: this.apiKey },
      });
      if (data.status !== 'OK' || !data.results?.length) {
        return { placeId: null, name: 'Pinned location', address: `${lat.toFixed(5)}, ${lng.toFixed(5)}`, lat, lng };
      }
      const r = data.results[0];
      const parts = r.formatted_address.split(',');
      return { placeId: r.place_id, name: parts[0].trim(), address: r.formatted_address, lat, lng };
    });
  }

  async route(origin, destination) {
    return this.#call('route', async () => {
      const { data } = await this.http.post(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
        {
          origin: { location: { latLng: { latitude: origin.lat, longitude: origin.lng } } },
          destination: { location: { latLng: { latitude: destination.lat, longitude: destination.lng } } },
          travelMode: 'DRIVE',
          routingPreference: 'TRAFFIC_AWARE',
          regionCode: 'IN',
        },
        { headers: { 'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline' } },
      );
      const r = data.routes?.[0];
      if (!r) throw new NotFoundError('No drivable route between these points');
      return {
        distanceKm: round(r.distanceMeters / 1000, 1),
        durationMin: Math.max(1, Math.round(parseInt(r.duration, 10) / 60)),
        polyline: r.polyline?.encodedPolyline ? decodePolyline(r.polyline.encodedPolyline) : [origin, destination],
        source: this.source,
      };
    });
  }
}
