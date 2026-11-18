import { PROVIDERS } from '../../../domain/rideTypes.js';
import { RideProvider } from '../RideProvider.js';
import { UberGuestRidesClient } from './uberGuestRidesClient.js';
import { UberOAuth } from './uberOAuth.js';
import { UberRidesClient } from './uberRidesClient.js';

/** Picks the Uber integration from whichever credentials Uber issued (Guest Rides preferred). */
export class UberProvider extends RideProvider {
  constructor(config, timeoutMs) {
    const { clientId, clientSecret, organizationUuid, serverToken, baseUrl, tokenUrl } = config;
    let client = null;
    if (clientId && clientSecret && organizationUuid) {
      const oauth = new UberOAuth({ clientId, clientSecret, scope: 'guests.trips', tokenUrl, timeoutMs });
      client = new UberGuestRidesClient({ oauth, organizationUuid, baseUrl, timeoutMs });
    } else if (serverToken) {
      client = new UberRidesClient({ serverToken, baseUrl, timeoutMs });
    }
    super({
      provider: PROVIDERS.uber,
      client,
      unavailableReason: 'Uber API access has not been approved yet',
      setupHint: 'Set UBER_CLIENT_ID, UBER_CLIENT_SECRET and UBER_ORG_UUID (Guest Rides) or UBER_SERVER_TOKEN (Riders API).',
    });
  }
}
