import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { loadConfig } from '../src/config/env.js';
import { createMapsClient } from '../src/infrastructure/maps/index.js';
import { GeoapifyMapsClient } from '../src/infrastructure/maps/geoapifyMapsClient.js';

const KEY = 'test-key-123';

function fakeHttp(routes) {
  const calls = [];
  return {
    calls,
    get: async (url, opts = {}) => {
      calls.push({ url, params: opts.params });
      const hit = Object.entries(routes).find(([k]) => url.includes(k));
      if (!hit) throw Object.assign(new Error('nope'), { response: { status: 401 }, config: { params: opts.params } });
      return { data: hit[1] };
    },
  };
}

describe('Geoapify search client (free plan)', () => {
  it('maps autocomplete results, biased to the user and filtered to India', async () => {
    const http = fakeHttp({
      '/v1/geocode/autocomplete': {
        results: [
          {
            name: 'Orion Mall',
            address_line1: 'Orion Mall',
            address_line2: 'Dr Rajkumar Road, Bengaluru, Karnataka 560055, India',
            lat: 13.011,
            lon: 77.555,
            place_id: 'abc123',
            distance: 6123,
          },
        ],
      },
    });
    const maps = new GeoapifyMapsClient({ apiKey: KEY, http });
    const out = await maps.autocomplete({ query: 'orion', bias: { lat: 12.97, lng: 77.59 } });
    assert.deepEqual(out, [
      { placeId: 'geo:abc123', primaryText: 'Orion Mall', secondaryText: 'Dr Rajkumar Road, Bengaluru, Karnataka 560055', distanceKm: 6.1 },
    ]);
    const { params } = http.calls[0];
    assert.equal(params.filter, 'countrycode:in');
    assert.equal(params.bias, 'proximity:77.59,12.97');
    assert.equal(params.apiKey, KEY);

    // Choosing it is served from cache: no extra credit used.
    const place = await maps.placeDetails('geo:abc123');
    assert.equal(place.lat, 13.011);
    assert.equal(http.calls.length, 1);
  });

  it('reverse geocodes and keeps the exact pin', async () => {
    const http = fakeHttp({
      '/v1/geocode/reverse': { results: [{ address_line1: '80 Feet Road', address_line2: 'Koramangala, Bengaluru, India', lat: 12.93, lon: 77.62 }] },
    });
    const p = await new GeoapifyMapsClient({ apiKey: KEY, http }).reverseGeocode({ lat: 12.93512, lng: 77.62451 });
    assert.equal(p.name, '80 Feet Road');
    assert.equal(p.address, 'Koramangala, Bengaluru');
    assert.equal(p.lat, 12.93512);
  });

  it('explains a bad key without leaking it', async () => {
    const maps = new GeoapifyMapsClient({ apiKey: KEY, http: fakeHttp({}) });
    await assert.rejects(maps.autocomplete({ query: 'orion' }), (e) => {
      assert.equal(e.code, 'UPSTREAM_ERROR');
      assert.match(e.message, /invalid API key/);
      assert.ok(!e.message.includes(KEY));
      return true;
    });
  });

  it('is used first for search when GEOAPIFY_API_KEY is set', () => {
    assert.equal(createMapsClient(loadConfig({ GEOAPIFY_API_KEY: KEY }), { warn() {} }).source, 'geoapify');
    assert.equal(createMapsClient(loadConfig({}), { warn() {} }).source, 'osm');
  });
});
