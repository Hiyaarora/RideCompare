/** Core vocabulary shared by every layer. */

export const PROVIDERS = Object.freeze({
  uber: { id: 'uber', name: 'Uber' },
  ola: { id: 'ola', name: 'Ola' },
  rapido: { id: 'rapido', name: 'Rapido' },
});
export const PROVIDER_IDS = Object.freeze(Object.keys(PROVIDERS));

export const CATEGORIES = Object.freeze(['bike', 'auto', 'car']);

/**
 * How firm a price is.
 *  upfront  = the provider quoted one fixed price for this trip (e.g. Uber `fare.value`, Ola `upfront.fare`)
 *  estimate = the provider returned a low/high range
 */
export const PRICE_TYPE = Object.freeze({ UPFRONT: 'upfront', ESTIMATE: 'estimate' });

/**
 * ok          = live prices returned
 * no_service  = the provider answered but has no rides for this trip
 * error       = the provider is configured but the call failed
 * unavailable = no authorised live integration is configured, so there are no prices at all
 */
export const PROVIDER_STATUS = Object.freeze({ OK: 'ok', ERROR: 'error', NO_SERVICE: 'no_service', UNAVAILABLE: 'unavailable' });

export const LIVE_PRICING_UNAVAILABLE = 'Live pricing unavailable';
