import { PROVIDERS } from '../../../domain/rideTypes.js';
import { RideProvider } from '../RideProvider.js';

/**
 * Rapido publishes no developer or partner fare API (verified Nov 2026). Unofficial or
 * reverse-engineered endpoints are deliberately NOT used. When Rapido grants partner access,
 * add rapidoLiveClient.js with a getEstimates() that returns liveOption(...) items and pass it as `client`.
 */
export class RapidoProvider extends RideProvider {
  constructor() {
    super({
      provider: PROVIDERS.rapido,
      client: null,
      unavailableReason: 'Rapido has no official fare API',
      setupHint: 'Requires a partnership with Rapido; see docs/PARTNERSHIP_EMAILS.md.',
    });
  }
}
