import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import request from 'supertest';
import { buildTestApp } from './helpers.js';

describe('places endpoints (demo maps)', () => {
  it('autocompletes landmarks, nearest first when a bias is given', async () => {
    const { app } = buildTestApp();
    const { body } = await request(app).get('/api/v1/places/autocomplete').query({ q: 'airport', lat: 12.97, lng: 77.6 }).expect(200);
    assert.equal(body.source, 'demo');
    assert.ok(body.suggestions.length >= 3);
    assert.match(body.suggestions[0].primaryText, /Kempegowda/);
  });

  it('requires at least 2 characters', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/api/v1/places/autocomplete').query({ q: 'a' }).expect(400);
    assert.equal(res.body.error.code, 'VALIDATION_ERROR');
  });

  it('returns details for a place id and 404 for an unknown one', async () => {
    const { app } = buildTestApp();
    const ok = await request(app).get(`/api/v1/places/${encodeURIComponent('demo:blr-mg-road')}`).expect(200);
    assert.equal(ok.body.place.name, 'MG Road Metro Station');
    const missing = await request(app).get('/api/v1/places/demo:nope').expect(404);
    assert.equal(missing.body.error.code, 'NOT_FOUND');
  });

  it('reverse geocodes to a nearby landmark or a pinned location', async () => {
    const { app } = buildTestApp();
    const near = await request(app).get('/api/v1/places/reverse').query({ lat: 12.9757, lng: 77.6070 }).expect(200);
    assert.match(near.body.place.name, /Near MG Road/);
    const far = await request(app).get('/api/v1/places/reverse').query({ lat: 10, lng: 76 }).expect(200);
    assert.equal(far.body.place.name, 'Pinned location');
  });
});

describe('meta endpoints', () => {
  it('health reports that no provider has live pricing without credentials', async () => {
    const { app } = buildTestApp();
    const { body } = await request(app).get('/api/v1/health').expect(200);
    assert.equal(body.status, 'ok');
    assert.deepEqual(body.providers.map((p) => p.live), [false, false, false]);
    assert.ok(body.providers.every((p) => p.note.startsWith('Live pricing unavailable')));
  });

  it('unknown routes return a JSON 404', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/api/v1/nope').expect(404);
    assert.equal(res.body.error.code, 'NOT_FOUND');
    assert.ok(res.headers['x-request-id']);
  });

  it('a provider goes live when its credentials are set, and secrets are never returned', async () => {
    const { app } = buildTestApp({ env: { OLA_APP_TOKEN: 'secret-token' } });
    const { body } = await request(app).get('/api/v1/providers').expect(200);
    assert.equal(body.providers.find((p) => p.id === 'ola').live, true);
    assert.ok(!JSON.stringify(body).includes('secret-token'), 'credentials must never be returned');
  });
});
