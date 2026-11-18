import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { loadConfig } from '../src/config/env.js';
import { createMapsClient } from '../src/infrastructure/maps/index.js';
import { OsmMapsClient, placeFromPhotonFeature } from '../src/infrastructure/maps/osmMapsClient.js';

const photonFeature = (name, osmType, osmId, lng, lat, extra = {}) => ({
  type: 'Feature',
  geometry: { type: 'Point', coordinates: [lng, lat] },
  properties: { name, osm_type: osmType, osm_id: osmId, city: 'Bengaluru', state: 'Karnataka', ...extra },
});

/** Fake axios: records calls and answers by URL substring. */
function fakeHttp(routes) {
  const calls = [];
  return {
    calls,
    get: async (url, opts = {}) => {
      calls.push({ url, params: opts.params });
      const hit = Object.entries(routes).find(([k]) => url.includes(k));
      if (!hit) throw Object.assign(new Error('down'), { code: 'ECONNREFUSED' });
      return { data: typeof hit[1] === 'function' ? hit[1](url, opts) : hit[1] };
    },
  };
}

describe('OSM maps client (free provider)', () => {
  it('maps Photon results to suggestions, biased and limited to India', async () => {
    const http = fakeHttp({
      '/api/': {
        features: [
          photonFeature('Indiranagar Metro Station', 'W', 169717853, 77.6386, 12.9783, { district: 'Indiranagar' }),
          photonFeature('Indiranagar Metro Station', 'W', 169717853, 77.6386, 12.9783, { district: 'Indiranagar' }), // dup
        ],
      },
    });
    const maps = new OsmMapsClient({ http });
    const out = await maps.autocomplete({ query: 'indiranagar metro', bias: { lat: 12.97, lng: 77.59 } });
    assert.equal(out.length, 1, 'duplicates removed');
    assert.equal(out[0].placeId, 'osm:W169717853');
    assert.equal(out[0].primaryText, 'Indiranagar Metro Station');
    assert.equal(out[0].secondaryText, 'Indiranagar, Bengaluru, Karnataka');
    assert.ok(out[0].distanceKm > 4 && out[0].distanceKm < 7);
    assert.equal(http.calls.length, 2, 'nearby + India-wide searches');
    assert.ok(http.calls.some((c) => c.params.bbox === '68.1,6.5,97.5,35.7'), 'India-wide search');
    assert.ok(http.calls.some((c) => c.params.bbox === '77.140,12.520,78.040,13.420'), 'nearby search box');

    // Selecting it needs no further network call (served from cache).
    const place = await maps.placeDetails('osm:W169717853');
    assert.equal(place.lat, 12.9783);
    assert.equal(http.calls.length, 2);

    // Same query again is cached too.
    await maps.autocomplete({ query: 'Indiranagar Metro', bias: { lat: 12.971, lng: 77.592 } });
    assert.equal(http.calls.length, 2);
  });

  it('shows nearby destinations before far-away ones and before road segments', async () => {
    const http = fakeHttp({
      '/api/': (_url, { params }) => ({
        features: params.bbox === '68.1,6.5,97.5,35.7'
          ? [photonFeature('Phoenix Marketcity Chennai', 'W', 9, 80.2, 13.0, { osm_key: 'shop', osm_value: 'mall', city: 'Chennai' })]
          : [
              photonFeature('Phoenix Road', 'W', 1, 77.6, 12.97, { osm_key: 'highway', street: 'Phoenix Road' }),
              photonFeature('Phoenix Road', 'W', 2, 77.61, 12.97, { osm_key: 'highway', street: 'Phoenix Road' }),
              photonFeature('Phoenix Market City', 'W', 3, 77.69, 12.99, { osm_key: 'shop', osm_value: 'mall' }),
            ],
      }),
    });
    const out = await new OsmMapsClient({ http }).autocomplete({ query: 'phoenix', bias: { lat: 12.97, lng: 77.59 } });
    assert.deepEqual(out.map((o) => o.primaryText), ['Phoenix Market City', 'Phoenix Road', 'Phoenix Marketcity Chennai']);
  });

  it('falls back to Nominatim lookup for an uncached OSM id', async () => {
    const http = fakeHttp({
      '/lookup': [{ name: 'Lalbagh', display_name: 'Lalbagh, Mavalli, Bengaluru, Karnataka, India', lat: '12.95', lon: '77.58' }],
    });
    const place = await new OsmMapsClient({ http }).placeDetails('osm:R123');
    assert.deepEqual(place, { placeId: 'osm:R123', name: 'Lalbagh', address: 'Mavalli, Bengaluru, Karnataka, India', lat: 12.95, lng: 77.58 });
    assert.equal(http.calls[0].params.osm_ids, 'R123');
  });

  it('reverse geocodes but keeps the exact pin coordinates', async () => {
    const http = fakeHttp({ '/reverse': { features: [photonFeature('MG Road', 'W', 1, 77.6, 12.97, { street: 'MG Road' })] } });
    const p = await new OsmMapsClient({ http }).reverseGeocode({ lat: 12.97161, lng: 77.59461 });
    assert.equal(p.name, 'MG Road');
    assert.equal(p.lat, 12.97161);
    assert.equal(p.lng, 77.59461);
  });

  it('uses OSRM road distance and never shows less than city-traffic time', async () => {
    const http = fakeHttp({
      '/route/v1/driving/': { code: 'Ok', routes: [{ distance: 7500, duration: 720, geometry: '_p~iF~ps|U_ulLnnqC' }] },
    });
    const maps = new OsmMapsClient({ http, now: () => new Date('2026-11-13T18:00:00') }); // peak: 17 km/h
    const r = await maps.route({ lat: 12.9716, lng: 77.5946 }, { lat: 12.9352, lng: 77.6245 });
    assert.equal(r.distanceKm, 7.5);
    assert.equal(r.durationMin, 26, '7.5 km at 17 km/h, not OSRM free-flow 12 min');
    assert.equal(r.source, 'osm');
    assert.equal(r.polyline.length, 2);
    assert.match(http.calls[0].url, /77\.5946,12\.9716;77\.6245,12\.9352$/);
  });

  it('reports upstream failures as UPSTREAM_ERROR', async () => {
    const maps = new OsmMapsClient({ http: fakeHttp({}) });
    await assert.rejects(maps.autocomplete({ query: 'x y' }), (e) => e.code === 'UPSTREAM_ERROR');
  });

  it('builds a readable place when a feature has only a street', () => {
    const p = placeFromPhotonFeature(photonFeature(undefined, 'N', 5, 77, 12, { street: '80 Feet Rd', housenumber: '12' }));
    assert.equal(p.name, '12 80 Feet Rd');
  });
});

describe('maps provider selection', () => {
  it('defaults to free OSM, and google requires a key', () => {
    assert.equal(createMapsClient(loadConfig({})).source, 'osm');
    assert.equal(createMapsClient(loadConfig({ MAPS_PROVIDER: 'demo' })).source, 'demo');
    assert.throws(() => loadConfig({ MAPS_PROVIDER: 'google' }), /requires GOOGLE_MAPS_API_KEY/);
    assert.equal(createMapsClient(loadConfig({ MAPS_PROVIDER: 'google', GOOGLE_MAPS_API_KEY: 'k' })).source, 'google');
  });
});
