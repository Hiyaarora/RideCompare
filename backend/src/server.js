import { createApp } from './app.js';
import { loadConfig } from './config/env.js';
import { connectMongo, disconnectMongo } from './infrastructure/db/mongo.js';
import { MongoSearchRepository } from './infrastructure/db/searchRepository.js';
import { createMapsClient } from './infrastructure/maps/index.js';
import { createProviderRegistry } from './infrastructure/providers/registry.js';

const logger = console;
const config = loadConfig();

await connectMongo(config.mongoUri, logger);

const maps = createMapsClient(config, logger);
const providers = createProviderRegistry(config);
const app = createApp({ config, maps, providers, searches: new MongoSearchRepository(logger), logger });

// Listen on all interfaces so the Android emulator (10.0.2.2) and devices on the LAN can reach it.
const server = app.listen(config.port, '0.0.0.0', () => {
  logger.info(`RideCompare API listening on http://localhost:${config.port}/api/v1`);
  logger.info(`  maps: ${maps.source}`);
  for (const p of providers.values()) logger.info(`  ${p.name.padEnd(7)} ${p.isConfigured ? `LIVE (${p.client.mode})` : `no live pricing: ${p.unavailableReason}`}`);
});

const shutdown = (signal) => {
  logger.info(`${signal} received, shutting down`);
  server.close(async () => {
    await disconnectMongo().catch(() => {});
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 5000).unref();
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
