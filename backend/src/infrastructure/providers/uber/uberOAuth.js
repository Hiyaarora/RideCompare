import axios from 'axios';
import { UpstreamError } from '../../../domain/errors.js';
import { upstreamStatus } from '../normalize.js';

/**
 * OAuth 2.0 client-credentials token for Uber's business APIs (e.g. scope `guests.trips`).
 * https://developer.uber.com/docs/guest-rides/guides/authentication
 * Tokens are cached in memory until shortly before they expire. Secrets never leave the backend.
 */
export class UberOAuth {
  constructor({ clientId, clientSecret, scope, tokenUrl, timeoutMs, http, clock = () => Date.now() }) {
    this.form = { client_id: clientId, client_secret: clientSecret, grant_type: 'client_credentials', scope };
    this.tokenUrl = tokenUrl;
    this.http = http ?? axios.create({ timeout: timeoutMs });
    this.clock = clock;
    this.cached = null; // { token, expiresAt }
  }

  async token() {
    if (this.cached && this.cached.expiresAt > this.clock()) return this.cached.token;
    try {
      const { data } = await this.http.post(this.tokenUrl, new URLSearchParams(this.form).toString(), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      });
      const ttlMs = Math.max(60, (data.expires_in ?? 3600) - 60) * 1000;
      this.cached = { token: data.access_token, expiresAt: this.clock() + ttlMs };
      return this.cached.token;
    } catch (err) {
      throw new UpstreamError('uber', `OAuth token request failed (${upstreamStatus(err)})`);
    }
  }
}
