# Live fare integrations: research and status (verified 17 Nov 2026)

RideCompare shows **only prices returned by an authorised provider API**. There is no demo fare model, no
rate card and no per-km calculation. A provider without a working authorised integration shows
**"Live pricing unavailable"** with the reason. Scraping, WebViews, accessibility-service screen reading and
reverse-engineered private endpoints are deliberately not used.

## Summary

| | Uber | Ola | Rapido |
|---|---|---|---|
| Official fare API | **Yes**: Guest Rides `POST /v1/guests/trips/estimates` (Uber for Business) and Riders `GET /v1.2/estimates/price` | **Yes**: partner `GET /v1/products` (ride estimate) | **No public or partner API found** |
| Categories / pickup ETA | Yes / yes (`pickup_estimate`; Riders API via `/v1.2/estimates/time`) | Yes / yes (`categories[].eta`, -1 = unavailable) | n/a |
| Upfront vs range | Upfront `fare.value` or `estimate.low/high_estimate` | `amount_min/max`; `upfront.fare` for whitelisted partners with a user token | n/a |
| Personal-use access | No self-serve key. Riders estimates "require approval from Uber"; Guest Rides needs an approved U4B organisation | No self-serve key. `X-APP-TOKEN` is issued to partners only; no public sandbox | No |
| Approval needed | Yes (Uber Business Development / U4B API access) | Yes (Ola affiliate/partner programme) | Partnership |
| Pricing | Not published; commercial terms with Uber | Not published | n/a |
| Comparison with competitors | **Forbidden** by Uber API Terms § II B unless Uber permits it in writing | Not addressed publicly; ask in the application | n/a |
| Endpoint check (no credentials) | `401 unauthorized` from both endpoints, so they are live | `401 invalid_partner_key`, so it is live | n/a |

### Third-party aggregators
Commercial "Uber/Ola/Rapido fare APIs" (e.g. scraping agencies, Apify "Rapido ride scraper" actors) obtain data
by scraping or by private-API reverse-engineering. **None is authorised by the providers, so none is used.**
Aggregator consumer apps (bob, Comparoo) publish no developer API. ONDC (open network) is legitimate but carries
Namma Yatri and other small sellers, not Uber, Ola or Rapido rides (see [ONDC.md](ONDC.md)).

## What is implemented (backend `src/infrastructure/providers/`)
* `UberProvider`: picks the integration from the credentials Uber issues.
  * `uberGuestRidesClient.js` + `uberOAuth.js` (client-credentials token, scope `guests.trips`, header `x-uber-organizationuuid`), preferred.
  * `uberRidesClient.js`: server token, price + time estimates (prices survive an ETA failure).
* `OlaProvider` → `olaLiveClient.js`: `X-APP-TOKEN`, optional user Bearer token for upfront fares.
* `RapidoProvider`: always unavailable until Rapido offers an API.
* `normalize.js` `liveOption()`: one shape for all providers, and returns nothing if the API gave no price:
  `provider, providerName, productName, category, priceType (upfront|estimate), fare {min, max, upfront, currency},
  pickupEtaMin, tripDurationMin, distanceKm, available, surgeMultiplier, dataSource:'live', fetchedAt`.
* `CompareRidesService`: queries configured providers with `Promise.allSettled` plus a per-provider timeout. Statuses
  are `ok | no_service | error | unavailable`; `dataMode` is `live | unavailable`. Available options are sorted
  first, then cheapest.
* Credentials are read only from `backend/.env` (git-ignored) and never returned by the API (tested).

## Turning a provider on
| Provider | Put in `backend/.env` | Where to get it |
|---|---|---|
| Uber (preferred) | `UBER_CLIENT_ID`, `UBER_CLIENT_SECRET`, `UBER_ORG_UUID` | Uber for Business account → request API access (Guest Rides) via https://developer.uber.com / your Uber BD contact; ask for **written permission for price comparison** |
| Uber (alt.) | `UBER_SERVER_TOKEN` | Same approval; Riders API estimates |
| Ola | `OLA_APP_TOKEN` (+ optional `OLA_USER_TOKEN`) | affiliates@olacabs.com; https://developers.olacabs.com |
| Rapido | (no setting yet) | Rapido partnerships; send their API docs to add `rapidoLiveClient.js` |

Restart the backend. The startup log and `GET /api/v1/providers` show `live: true` for each enabled provider.
Draft request emails: [PARTNERSHIP_EMAILS.md](PARTNERSHIP_EMAILS.md).

## Sources
* Uber Riders price estimates: https://developer.uber.com/docs/riders/references/api/v1.2/estimates-price-get
* Uber Guest Rides estimates: https://developer.uber.com/docs/guest-rides/references/api/v1/guest-trips-estimates-post
* Ola ride estimate: https://developers.olacabs.com/docs/ride-estimate
* ONDC mobility spec: https://github.com/ONDC-Official/mobility-specification
