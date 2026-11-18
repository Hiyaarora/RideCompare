import { PROVIDERS } from '../../../domain/rideTypes.js';
import { RideProvider } from '../RideProvider.js';
import { OlaLiveClient } from './olaLiveClient.js';

export class OlaProvider extends RideProvider {
  constructor(config, timeoutMs) {
    const { appToken, userToken, baseUrl } = config;
    super({
      provider: PROVIDERS.ola,
      client: appToken ? new OlaLiveClient({ appToken, userToken, baseUrl, timeoutMs }) : null,
      unavailableReason: 'Ola partner access (X-APP-TOKEN) has not been granted yet',
      setupHint: 'Set OLA_APP_TOKEN (and optionally OLA_USER_TOKEN for upfront fares).',
    });
  }
}
