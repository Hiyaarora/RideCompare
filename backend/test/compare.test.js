import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import request from 'supertest';
import { buildTestApp, KORAMANGALA, MG_ROAD } from './helpers.js';
import { fakeLiveProvider, opt, providersMap, RapidoProvider } from './fakes.js';

const trip = { pickup: MG_ROAD, drop: KORAMANGALA };

describe('POST /api/v1/compare (live only, no demo prices)', () => {
  it('without credentials returns NO prices and says "Live pricing unavailable" for every provider', async () => {
    const { app } = buildTestApp();
    const { body } = await request(app).post('/api/v1/compare').send(trip).expect(200);
    assert.equal(body.dataMode, 'unavailable');
    assert.deepEqual(body.options, []);
    assert.equal(body.cheapestOptionId, null);
    assert.deepEqual(body.providers.map((p) => p.id), ['uber', 'ola', 'rapido']);
    for (const p of body.providers) {
      assert.equal(p.status, 'unavailable');
      assert.equal(p.message, 'Live pricing unavailable');
      assert.ok(p.reason.length > 5);
    }
    assert.ok(body.route.distanceKm > 4, 'the route itself is still shown');
  });

  it('returns normalised live options, cheapest first, upfront and estimate kept apart', async () => {
    const providers = providersMap(
      fakeLiveProvider('uber', async () => [opt('uber', 'go', 'car', { upfront: 212 }), opt('uber', 'moto', 'bike', { upfront: 74, eta: 3 })]),
      fakeLiveProvider('ola', async () => [opt('ola', 'mini', 'car', { low: 190, high: 230, eta: 6 }), opt('ola', 'auto', 'auto', { low: 120, high: 140, available: false })]),
      new RapidoProvider(),
    );
    const { app } = buildTestApp({ providers });
    const { body } = await request(app).post('/api/v1/compare').send(trip).expect(200);
    assert.equal(body.dataMode, 'live');
    assert.deepEqual(body.options.map((o) => o.id), ['uber:moto', 'ola:mini', 'uber:go', 'ola:auto'], 'available first, then cheapest');
    const go = body.options.find((o) => o.id === 'uber:go');
    assert.equal(go.priceType, 'upfront');
    assert.deepEqual(go.fare, { min: 212, max: 212, upfront: 212, currency: 'INR' });
    const mini = body.options.find((o) => o.id === 'ola:mini');
    assert.equal(mini.priceType, 'estimate');
    assert.equal(mini.fare.upfront, null);
    for (const o of body.options) {
      assert.equal(o.dataSource, 'live');
      for (const k of ['provider', 'providerName', 'category', 'pickupEtaMin', 'tripDurationMin', 'distanceKm', 'available', 'priceType', 'fetchedAt']) assert.ok(k in o, k);
    }
    assert.equal(body.cheapestOptionId, 'uber:moto');
    assert.equal(body.fastestOptionId, 'uber:moto');
    assert.equal(body.providers.find((p) => p.id === 'rapido').message, 'Live pricing unavailable');
  });

  it('one provider failing never affects the others (Promise.allSettled)', async () => {
    const providers = providersMap(
      fakeLiveProvider('uber', async () => { throw new Error('uber: price estimates failed (401)'); }),
      fakeLiveProvider('ola', async () => [opt('ola', 'mini', 'car', { low: 190, high: 230 })]),
    );
    const { app } = buildTestApp({ providers });
    const { body } = await request(app).post('/api/v1/compare').send(trip).expect(200);
    const uber = body.providers.find((p) => p.id === 'uber');
    assert.equal(uber.status, 'error');
    assert.match(uber.reason, /401/);
    assert.deepEqual(body.options.map((o) => o.id), ['ola:mini']);
  });

  it('a hung provider times out without blocking the rest', async () => {
    const providers = providersMap(
      fakeLiveProvider('uber', () => new Promise(() => {})),
      fakeLiveProvider('ola', async () => [opt('ola', 'bike', 'bike', { low: 60, high: 70 })]),
    );
    const { app } = buildTestApp({ providers, env: { UPSTREAM_TIMEOUT_MS: '500' } });
    const { body } = await request(app).post('/api/v1/compare').send(trip).expect(200);
    assert.equal(body.providers.find((p) => p.id === 'uber').status, 'error');
    assert.equal(body.options.length, 1);
  });

  it('all configured providers failing is still a 200 with clear statuses, not fake data', async () => {
    const providers = providersMap(fakeLiveProvider('ola', async () => { throw new Error('down'); }), new RapidoProvider());
    const { app } = buildTestApp({ providers });
    const { body } = await request(app).post('/api/v1/compare').send(trip).expect(200);
    assert.equal(body.dataMode, 'unavailable');
    assert.deepEqual(body.options, []);
    assert.deepEqual(body.providers.map((p) => p.status), ['error', 'unavailable']);
  });

  it('filters by provider and category', async () => {
    const providers = providersMap(
      fakeLiveProvider('ola', async () => [opt('ola', 'mini', 'car', { low: 190, high: 230 }), opt('ola', 'bike', 'bike', { low: 60, high: 70 })]),
      fakeLiveProvider('uber', async () => [opt('uber', 'go', 'car', { upfront: 212 })]),
    );
    const { app } = buildTestApp({ providers });
    const { body } = await request(app).post('/api/v1/compare').send({ ...trip, providers: ['ola'], categories: ['bike'] }).expect(200);
    assert.deepEqual(body.providers.map((p) => p.id), ['ola']);
    assert.deepEqual(body.options.map((o) => o.id), ['ola:bike']);
  });

  it('rejects identical pickup and drop', async () => {
    const { app } = buildTestApp();
    const res = await request(app).post('/api/v1/compare').send({ pickup: MG_ROAD, drop: MG_ROAD }).expect(400);
    assert.equal(res.body.error.details.reason, 'SAME_LOCATION');
  });

  it('explains a too-far trip with the real distance', async () => {
    const { app } = buildTestApp();
    const delhi = { name: 'South Extension Flyover', lat: 28.5707, lng: 77.2186 };
    const res = await request(app).post('/api/v1/compare').send({ pickup: MG_ROAD, drop: delhi }).expect(400);
    assert.equal(res.body.error.details.reason, 'TOO_FAR');
    assert.match(res.body.error.message, /1,7\d\d km apart/);
  });

  it('validates the body', async () => {
    const { app } = buildTestApp();
    const res = await request(app).post('/api/v1/compare').send({ pickup: { name: 'x', lat: 200, lng: 0 }, providers: ['lyft'] }).expect(400);
    const fields = res.body.error.details.map((d) => d.field);
    assert.ok(fields.includes('pickup.lat') && fields.includes('drop') && fields.some((f) => f.startsWith('providers')));
  });

  it('returns 400 for malformed JSON', async () => {
    const { app } = buildTestApp();
    const res = await request(app).post('/api/v1/compare').set('Content-Type', 'application/json').send('{bad').expect(400);
    assert.equal(res.body.error.code, 'INVALID_JSON');
  });

  it('records searches (once per trip) even without prices', async () => {
    const { app } = buildTestApp();
    for (let i = 0; i < 3; i++) await request(app).post('/api/v1/compare').send(trip);
    await request(app).post('/api/v1/compare').send({ pickup: KORAMANGALA, drop: MG_ROAD });
    const { body } = await request(app).get('/api/v1/searches/recent').expect(200);
    assert.equal(body.searches.length, 2);
    assert.equal(body.searches[0].pickup.name, KORAMANGALA.name);
  });
});
