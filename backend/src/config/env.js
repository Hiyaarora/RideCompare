import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  CORS_ORIGINS: z.string().optional().default(''),
  MONGODB_URI: z.string().default('mongodb://127.0.0.1:27017/ridecompare'),
  MAPS_PROVIDER: z.enum(['osm', 'google', 'demo']).default('osm'),
  GOOGLE_MAPS_API_KEY: z.string().optional().default(''),
  GEOAPIFY_API_KEY: z.string().optional().default(''),
  OSM_PHOTON_URL: z.url().default('https://photon.komoot.io'),
  OSM_NOMINATIM_URL: z.url().default('https://nominatim.openstreetmap.org'),
  OSM_OSRM_URL: z.url().default('https://router.project-osrm.org'),
  OSM_USER_AGENT: z.string().min(3).default('RideCompare/1.0 (development)'),
  // Uber: Guest Rides (Uber for Business) OAuth credentials, or a legacy Riders API server token.
  UBER_CLIENT_ID: z.string().optional().default(''),
  UBER_CLIENT_SECRET: z.string().optional().default(''),
  UBER_ORG_UUID: z.string().optional().default(''),
  UBER_SERVER_TOKEN: z.string().optional().default(''),
  UBER_API_BASE_URL: z.url().default('https://api.uber.com'),
  UBER_TOKEN_URL: z.url().default('https://auth.uber.com/oauth/v2/token'),
  OLA_APP_TOKEN: z.string().optional().default(''),
  OLA_USER_TOKEN: z.string().optional().default(''),
  OLA_API_BASE_URL: z.url().default('https://devapi.olacabs.com'),
  UPSTREAM_TIMEOUT_MS: z.coerce.number().int().min(500).max(30000).default(6000),
});

/**
 * Parses configuration from an env-like object. Exported separately so tests can
 * build configs without touching process.env.
 */
export function loadConfig(source = process.env) {
  const parsed = schema.safeParse(source);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid configuration: ${issues}`);
  }
  const e = parsed.data;
  if (e.MAPS_PROVIDER === 'google' && !e.GOOGLE_MAPS_API_KEY.trim()) {
    throw new Error('Invalid configuration: MAPS_PROVIDER=google requires GOOGLE_MAPS_API_KEY');
  }
  return Object.freeze({
    env: e.NODE_ENV,
    port: e.PORT,
    corsOrigins: e.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean),
    mongoUri: e.MONGODB_URI,
    upstreamTimeoutMs: e.UPSTREAM_TIMEOUT_MS,
    maps: {
      provider: e.MAPS_PROVIDER,
      google: { apiKey: e.GOOGLE_MAPS_API_KEY.trim() },
      geoapify: { apiKey: e.GEOAPIFY_API_KEY.trim() },
      osm: { photonUrl: e.OSM_PHOTON_URL, nominatimUrl: e.OSM_NOMINATIM_URL, osrmUrl: e.OSM_OSRM_URL, userAgent: e.OSM_USER_AGENT },
    },
    providers: {
      uber: {
        clientId: e.UBER_CLIENT_ID.trim(),
        clientSecret: e.UBER_CLIENT_SECRET.trim(),
        organizationUuid: e.UBER_ORG_UUID.trim(),
        serverToken: e.UBER_SERVER_TOKEN.trim(),
        baseUrl: e.UBER_API_BASE_URL,
        tokenUrl: e.UBER_TOKEN_URL,
      },
      ola: { appToken: e.OLA_APP_TOKEN.trim(), userToken: e.OLA_USER_TOKEN.trim(), baseUrl: e.OLA_API_BASE_URL },
      rapido: {},
    },
  });
}
