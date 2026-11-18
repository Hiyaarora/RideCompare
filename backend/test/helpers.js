import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config/env.js';
import { InMemorySearchRepository } from '../src/infrastructure/db/searchRepository.js';
import { DemoMapsClient } from '../src/infrastructure/maps/demoMapsClient.js';
import { createProviderRegistry } from '../src/infrastructure/providers/registry.js';

export const FIXED_NOW = new Date('2026-11-13T14:30:00+05:30');

export const MG_ROAD = { name: 'MG Road Metro Station', address: 'Bengaluru', lat: 12.9755, lng: 77.6068 };
export const KORAMANGALA = { name: 'Koramangala 5th Block', address: 'Bengaluru', lat: 12.9352, lng: 77.6245 };
export const BLR_AIRPORT = { name: 'Kempegowda International Airport', address: 'Bengaluru', lat: 13.1986, lng: 77.7066 };

export function buildTestApp({ providers, maps, env = {} } = {}) {
  const config = loadConfig({ NODE_ENV: 'test', MAPS_PROVIDER: 'demo', ...env });
  const searches = new InMemorySearchRepository();
  const app = createApp({
    config,
    maps: maps ?? new DemoMapsClient({ now: () => FIXED_NOW }),
    providers: providers ?? createProviderRegistry(config),
    searches,
    logger: { info() {}, warn() {}, error() {} },
    now: () => FIXED_NOW,
  });
  return { app, searches, config };
}
