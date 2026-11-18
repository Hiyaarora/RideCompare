import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { loadConfig } from '../src/config/env.js';
import { decodePolyline } from '../src/infrastructure/maps/geo.js';
import { createProviderRegistry } from '../src/infrastructure/providers/registry.js';
import { OlaLiveClient } from '../src/infrastructure/providers/ola/olaLiveClient.js';
import { UberGuestRidesClient } from '../src/infrastructure/providers/uber/uberGuestRidesClient.js';
import { UberOAuth } from '../src/infrastructure/providers/uber/uberOAuth.js';
import { UberRidesClient } from '../src/infrastructure/providers/uber/uberRidesClient.js';
import { KORAMANGALA, MG_ROAD } from './helpers.js';

const now = () => new Date('2026-11-13T09:00:00Z');
const trip = { pickup: MG_ROAD, drop: KORAMANGALA };
const fail = (status) => Object.assign(new Error('nope'), { response: { status } });

/** Fake axios instance answering per path, recording requests. */
function fakeHttp(routes) {
  const calls = [];
  const answer = async (method, path, body, opts) => {
    calls.push({ method, path, body, opts });
    const r = routes[path];
    if (r === undefined) throw fail(404);
    if (r instanceof Error) throw r;
    return { data: typeof r === 'function' ? r(body, opts) : r };
  };
  return { calls, get: (p, o) => answer('GET', p, null, o), post: (p, b, o) => answer('POST', p, b, o) };
}

describe('Uber Guest Rides client (POST /v1/guests/trips/estimates)', () => {
  const oauthHttp = fakeHttp({ 'https://auth.uber.com/oauth/v2/token': { access_token: 'tok-123', expires_in: 2592000 } });
  const oauth = new UberOAuth({ clientId: 'id', clientSecret: 'shh', scope: 'guests.trips', tokenUrl: 'https://auth.uber.com/oauth/v2/token', http: oauthHttp });

  it('maps upfront fares, estimate ranges, ETAs, availability and sends the org header', async () => {
    const http = fakeHttp({
      '/v1/guests/trips/estimates': {
        product_estimates: [
          { product: { product_id: 'p-go', display_name: 'Uber Go', capacity: 4, short_description: 'Affordable cars' },
            estimate_info: { pickup_estimate: 4, no_cars_available: false, fare: { value: 212.4, currency_code: 'INR' },
              trip: { travel_distance_estimate: 3.8, distance_unit: 'mile', duration_estimate: 1260 } } },
          { product: { product_id: 'p-moto', display_name: 'Moto' },
            estimate_info: { pickup_estimate: null, no_cars_available: true, estimate: { low_estimate: 70, high_estimate: 85, currency_code: 'INR', surge_multiplier: 1.2 },
              trip: { distance_estimate: 6.1, distance_unit: 'km', duration_estimate: 900 } } },
          { product: { product_id: 'p-x', display_name: 'Uber Auto' }, estimate_info: { pickup_estimate: 5, fare: null, estimate: null } },
        ],
      },
    });
    const client = new UberGuestRidesClient({ oauth, organizationUuid: 'org-1', http, now });
    const out = await client.getEstimates(trip);
    assert.equal(out.length, 2, 'products without any fare are dropped, never invented');
    const [go, moto] = out;
    assert.deepEqual([go.priceType, go.fare.upfront, go.fare.min, go.fare.max], ['upfront', 212, 212, 212]);
    assert.deepEqual([go.category, go.pickupEtaMin, go.tripDurationMin, go.distanceKm, go.available], ['car', 4, 21, 6.1, true]);
    assert.deepEqual([moto.priceType, moto.fare.min, moto.fare.max, moto.fare.upfront], ['estimate', 70, 85, null]);
    assert.deepEqual([moto.category, moto.available, moto.surgeMultiplier, moto.distanceKm], ['bike', false, 1.2, 6.1]);
    assert.equal(go.fetchedAt, '2026-11-13T09:00:00.000Z');
    const headers = http.calls[0].opts.headers;
    assert.equal(headers.Authorization, 'Bearer tok-123');
    assert.equal(headers['x-uber-organizationuuid'], 'org-1');
    assert.deepEqual(http.calls[0].body.pickup, { latitude: MG_ROAD.lat, longitude: MG_ROAD.lng });
  });

  it('caches the OAuth token and requests the guests.trips scope', async () => {
    await oauth.token();
    await oauth.token();
    const tokenCalls = oauthHttp.calls.filter((c) => c.method === 'POST');
    assert.equal(tokenCalls.length, 1);
    assert.match(tokenCalls[0].body, /grant_type=client_credentials/);
    assert.match(tokenCalls[0].body, /scope=guests.trips/);
  });

  it('reports auth failures as upstream errors without leaking the secret', async () => {
    const bad = new UberOAuth({ clientId: 'id', clientSecret: 'super-secret', scope: 'guests.trips', tokenUrl: 'https://auth.uber.com/oauth/v2/token', http: fakeHttp({ 'https://auth.uber.com/oauth/v2/token': fail(401) }) });
    const client = new UberGuestRidesClient({ oauth: bad, organizationUuid: 'org', http: fakeHttp({}), now });
    await assert.rejects(client.getEstimates(trip), (e) => e.code === 'UPSTREAM_ERROR' && /401/.test(e.message) && !e.message.includes('super-secret'));
  });
});

describe('Uber Riders API client (GET /v1.2/estimates/price + /time)', () => {
  it('maps ranges and ETAs; still returns prices if the ETA call fails', async () => {
    const prices = { prices: [
      { product_id: 'p1', display_name: 'Moto', currency_code: 'INR', low_estimate: 60, high_estimate: 75, surge_multiplier: 1, duration: 900, distance: 3.1 },
      { product_id: 'p2', display_name: 'Go', currency_code: 'INR', low_estimate: 180, high_estimate: 220, duration: 1200, distance: 3.1 },
      { product_id: 'p3', display_name: 'Taxi', currency_code: 'INR', estimate: 'Metered', low_estimate: null, high_estimate: null },
    ] };
    const out = await new UberRidesClient({ now, http: fakeHttp({ '/v1.2/estimates/price': prices, '/v1.2/estimates/time': { times: [{ product_id: 'p1', estimate: 240 }] } }) }).getEstimates(trip);
    assert.deepEqual(out.map((o) => [o.category, o.priceType, o.fare.min, o.fare.max]), [['bike', 'estimate', 60, 75], ['car', 'estimate', 180, 220]]);
    assert.equal(out[0].pickupEtaMin, 4);
    assert.equal(out[0].distanceKm, 5);
    assert.equal(out[1].available, false, 'no ETA for this product = not available right now');
    const noEta = await new UberRidesClient({ now, http: fakeHttp({ '/v1.2/estimates/price': prices, '/v1.2/estimates/time': fail(500) }) }).getEstimates(trip);
    assert.equal(noEta.length, 2);
    assert.equal(noEta[0].pickupEtaMin, null);
  });
});

describe('Ola partner client (GET /v1/products)', () => {
  it('maps estimate ranges, upfront fares and unavailable categories', async () => {
    const http = fakeHttp({ '/v1/products': {
      categories: [
        { id: 'mini', display_name: 'Mini', currency: 'INR', eta: 5 },
        { id: 'auto', display_name: 'Auto', currency: 'INR', eta: 3 },
        { id: 'bike', display_name: 'Bike', currency: 'INR', eta: -1 },
      ],
      ride_estimate: [
        { category: 'mini', distance: 6.2, travel_time_in_minutes: 22, amount_min: 170, amount_max: 190 },
        { category: 'auto', distance: 6.2, travel_time_in_minutes: 20, amount_min: 110, amount_max: 125, upfront: { fare: 118, fare_id: 'f1', is_upfront_applicable: true } },
        { category: 'bike', distance: 6.2, travel_time_in_minutes: 18, amount_min: 60, amount_max: 70 },
      ],
    } });
    const out = await new OlaLiveClient({ http, now }).getEstimates(trip);
    const by = Object.fromEntries(out.map((o) => [o.productCode, o]));
    assert.deepEqual([by.mini.priceType, by.mini.fare.min, by.mini.fare.max, by.mini.pickupEtaMin], ['estimate', 170, 190, 5]);
    assert.deepEqual([by.auto.priceType, by.auto.fare.upfront], ['upfront', 118]);
    assert.deepEqual([by.bike.available, by.bike.pickupEtaMin], [false, null]);
    assert.equal(http.calls[0].opts.params.service_type, 'p2p');
  });

  it('wraps upstream failures', async () => {
    await assert.rejects(new OlaLiveClient({ http: fakeHttp({}), now }).getEstimates(trip), (e) => e.code === 'UPSTREAM_ERROR');
  });
});

describe('provider registry', () => {
  it('no credentials = not configured; Rapido never configured', () => {
    const reg = createProviderRegistry(loadConfig({ NODE_ENV: 'test' }));
    assert.deepEqual([...reg.values()].map((p) => p.isConfigured), [false, false, false]);
  });

  it('picks the Uber integration from the credentials provided', () => {
    const guest = createProviderRegistry(loadConfig({ NODE_ENV: 'test', UBER_CLIENT_ID: 'a', UBER_CLIENT_SECRET: 'b', UBER_ORG_UUID: 'c', UBER_SERVER_TOKEN: 'd' }));
    assert.equal(guest.get('uber').client.mode, 'guest-rides');
    const riders = createProviderRegistry(loadConfig({ NODE_ENV: 'test', UBER_SERVER_TOKEN: 'd' }));
    assert.equal(riders.get('uber').client.mode, 'riders-api');
    const ola = createProviderRegistry(loadConfig({ NODE_ENV: 'test', OLA_APP_TOKEN: 'x' }));
    assert.equal(ola.get('ola').client.mode, 'partner-api');
  });
});

describe('maps helpers', () => {
  it('decodes Google encoded polylines', () => {
    assert.deepEqual(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), [
      { lat: 38.5, lng: -120.2 },
      { lat: 40.7, lng: -120.95 },
      { lat: 43.252, lng: -126.453 },
    ]);
  });
});
