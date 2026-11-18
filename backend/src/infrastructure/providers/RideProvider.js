import { LIVE_PRICING_UNAVAILABLE } from '../../domain/rideTypes.js';

/**
 * Base class for UberProvider, OlaProvider and RapidoProvider.
 *
 * A provider is either *configured* (it has an authorised live client) or not. There is NO demo/fake
 * fallback: an unconfigured provider returns nothing and reports `unavailableReason`.
 *
 * getEstimates(ctx) resolves to normalised options (see normalize.js), only from the live API.
 */
export class RideProvider {
  constructor({ provider, client = null, unavailableReason, setupHint }) {
    this.id = provider.id;
    this.name = provider.name;
    this.client = client;
    this.unavailableReason = unavailableReason;
    this.setupHint = setupHint;
  }

  get isConfigured() {
    return this.client != null;
  }

  /** Safe to expose to the app (never contains credentials). */
  describe() {
    return this.isConfigured
      ? { id: this.id, name: this.name, live: true, mode: this.client.mode, note: `Live prices from the official ${this.name} API` }
      : { id: this.id, name: this.name, live: false, note: `${LIVE_PRICING_UNAVAILABLE}: ${this.unavailableReason}` };
  }

  async getEstimates(ctx) {
    if (!this.client) return [];
    const options = await this.client.getEstimates(ctx);
    return options.filter((o) => ctx.categories.includes(o.category));
  }
}
