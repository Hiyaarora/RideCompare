import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { NotFoundError, UpstreamError } from '../src/domain/errors.js';
import { DemoMapsClient } from '../src/infrastructure/maps/demoMapsClient.js';
import { ResilientMapsClient } from '../src/infrastructure/maps/resilientMapsClient.js';

const quiet = { warn() {} };

function fakeClient(source, { down = false, prefix = source } = {}) {
  const calls = { autocomplete: 0, route: 0 };
  return {
    calls,
    source,
    async autocomplete() {
      calls.autocomplete++;
      if (down) throw new UpstreamError(source, 'search failed (ECONNREFUSED)');
      return [{ placeId: `${prefix}:1`, primaryText: `${source} result`, secondaryText: '' }];
    },
    async reverseGeocode() {
      if (down) throw new UpstreamError(source, 'down');
      return { name: `${source} street` };
    },
    async route() {
      calls.route++;
      if (down) throw new UpstreamError(source, 'route failed');
      return { distanceKm: 7.5, durationMin: 20, polyline: [], source };
    },
    async placeDetails(id) {
      if (id.endsWith(':missing')) throw new NotFoundError('nope');
      return { placeId: id, name: `${source} place`, lat: 1, lng: 2 };
    },
  };
}

describe('ResilientMapsClient (fallback chains)', () => {
  it('uses the first client while it works', async () => {
    const maps = new ResilientMapsClient({ search: [fakeClient('geoapify', { prefix: 'geo' }), fakeClient('osm'), new DemoMapsClient()], route: [fakeClient('osm')], logger: quiet });
    assert.equal((await maps.autocomplete({ query: 'x' }))[0].primaryText, 'geoapify result');
    assert.equal(maps.source, 'geoapify');
  });

  it('falls through the chain and pauses failed clients for the cooldown', async () => {
    let now = 0;
    const geo = fakeClient('geoapify', { down: true, prefix: 'geo' });
    const osm = fakeClient('osm', { down: true });
    const maps = new ResilientMapsClient({ search: [geo, osm, new DemoMapsClient()], route: [osm], logger: quiet, clock: () => now });
    const first = await maps.autocomplete({ query: 'airport' });
    assert.ok(first.length > 0 && first.every((s) => s.placeId.startsWith('demo:')));
    assert.equal(maps.source, 'demo');
    await maps.autocomplete({ query: 'airport' });
    assert.equal(geo.calls.autocomplete, 1, 'not retried during cooldown');
    assert.equal(osm.calls.autocomplete, 1);
    now = 61_000;
    await maps.autocomplete({ query: 'airport' });
    assert.equal(geo.calls.autocomplete, 2, 'retried after cooldown');
  });

  it('keeps routing working when only search is down', async () => {
    const osmSearchDown = fakeClient('osm', { down: true });
    const osrm = fakeClient('osm');
    const maps = new ResilientMapsClient({ search: [osmSearchDown, new DemoMapsClient()], route: [osrm, new DemoMapsClient()], logger: quiet });
    await maps.autocomplete({ query: 'airport' });
    assert.equal((await maps.route({ lat: 12.97, lng: 77.59 }, { lat: 12.93, lng: 77.62 })).source, 'osm');
  });

  it('resolves place ids with the client that issued them, and passes NotFound through', async () => {
    const maps = new ResilientMapsClient({
      search: [fakeClient('geoapify', { prefix: 'geo' }), fakeClient('osm'), new DemoMapsClient()],
      route: [new DemoMapsClient()],
      logger: quiet,
    });
    assert.equal((await maps.placeDetails('demo:blr-mg-road')).name, 'MG Road Metro Station');
    assert.equal((await maps.placeDetails('geo:abc')).name, 'geoapify place');
    assert.equal((await maps.placeDetails('osm:W1')).name, 'osm place');
    await assert.rejects(maps.placeDetails('osm:missing'), NotFoundError);
  });

  it('asks the next service when one finds nothing', async () => {
    const empty = { ...fakeClient('geoapify', { prefix: 'geo' }), autocomplete: async () => [] };
    const maps = new ResilientMapsClient({ search: [empty, fakeClient('osm'), new DemoMapsClient()], route: [], logger: quiet });
    assert.equal((await maps.autocomplete({ query: 'phoenix' }))[0].primaryText, 'osm result');
    const allEmpty = new ResilientMapsClient({ search: [empty, new DemoMapsClient()], route: [], logger: quiet });
    assert.deepEqual(await allEmpty.autocomplete({ query: 'zzqx' }), []);
  });

  it('merges results from several services when one finds only a few, without duplicates', async () => {
    const few = {
      ...fakeClient('geoapify', { prefix: 'geo' }),
      autocomplete: async () => [{ placeId: 'geo:1', primaryText: 'Huddle Stays Cosmo', secondaryText: 'Delhi', distanceKm: 9.3 }],
    };
    const more = {
      ...fakeClient('osm'),
      autocomplete: async () => [
        { placeId: 'osm:W1', primaryText: 'huddle stays cosmo', secondaryText: 'Delhi', distanceKm: 9.3 },
        { placeId: 'osm:W2', primaryText: 'Zeta 1 Market', secondaryText: 'Greater Noida', distanceKm: 4.1 },
      ],
    };
    const maps = new ResilientMapsClient({ search: [few, more, new DemoMapsClient()], route: [], logger: quiet });
    const out = await maps.autocomplete({ query: 'huddle stays' });
    assert.deepEqual(out.map((o) => o.primaryText).slice(0, 2), ['Huddle Stays Cosmo', 'Zeta 1 Market']);
    assert.equal(out.filter((o) => /huddle stays cosmo/i.test(o.primaryText)).length, 1, 'duplicate removed');
  });
});
