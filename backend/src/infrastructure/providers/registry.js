import { OlaProvider } from './ola/OlaProvider.js';
import { RapidoProvider } from './rapido/RapidoProvider.js';
import { UberProvider } from './uber/UberProvider.js';

/** Builds the providers. Adding one = add a RideProvider subclass + register it here. */
export function createProviderRegistry(config) {
  const t = config.upstreamTimeoutMs;
  const providers = [new UberProvider(config.providers.uber, t), new OlaProvider(config.providers.ola, t), new RapidoProvider()];
  return new Map(providers.map((p) => [p.id, p]));
}
