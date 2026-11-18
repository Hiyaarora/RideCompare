import { DemoMapsClient } from './demoMapsClient.js';
import { GeoapifyMapsClient } from './geoapifyMapsClient.js';
import { GoogleMapsClient } from './googleMapsClient.js';
import { OsmMapsClient } from './osmMapsClient.js';
import { ResilientMapsClient } from './resilientMapsClient.js';

/**
 * Chooses the maps backend from MAPS_PROVIDER:
 *   osm    (default, free) search: Geoapify (if GEOAPIFY_API_KEY) → Photon → offline landmarks
 *                          routes: OSRM → straight-line estimate
 *   google Google Maps Platform (needs GOOGLE_MAPS_API_KEY + billing)
 *   demo   offline landmark list + straight-line routes (used by tests)
 * Every client has the same methods, so switching providers needs no other code change.
 */
export function createMapsClient(config, logger = console) {
  const { provider, google, osm, geoapify } = config.maps;
  const timeoutMs = config.upstreamTimeoutMs;
  switch (provider) {
    case 'google':
      return new GoogleMapsClient({ apiKey: google.apiKey, timeoutMs });
    case 'demo':
      return new DemoMapsClient();
    default: {
      const offline = new DemoMapsClient();
      const free = new OsmMapsClient({ timeoutMs, ...osm });
      const search = [geoapify.apiKey ? new GeoapifyMapsClient({ apiKey: geoapify.apiKey, timeoutMs }) : null, free, offline].filter(
        Boolean,
      );
      return new ResilientMapsClient({ search, route: [free, offline], logger });
    }
  }
}
