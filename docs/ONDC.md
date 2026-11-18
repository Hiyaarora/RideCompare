# ONDC as a live price source (research, Nov 2026)

ONDC (Open Network for Digital Commerce) is a government-backed open network built on the beckn protocol.
Its mobility spec lets a **buyer app (BAP)** like RideCompare legally ask every ride **seller app (BPP)** on the
network for quotes with no scraping and no per-provider contract. This is the official equivalent of what
"bob" (justbobit.com) advertises as "deep integration into open mobility networks and ONDC protocols".

## Who is on it (verify before relying on this)
| Provider | Ride hailing on ONDC? | Evidence |
|---|---|---|
| Namma Yatri / Yatri | **Yes**, the main ride seller (autos, cabs; Bengaluru, Delhi NCR, more) | press since 2023 |
| Yaary (Hyderabad drivers' association) | Yes | press |
| Rapido | Metro **tickets** on ONDC; ride hailing **not confirmed** | Chennai Metro news |
| Uber | MoU signed; only Uber Direct (logistics) and metro tickets seen; **no rides** | Uber newsroom |
| Ola | **No evidence** | none |

**Conclusion:** ONDC can add real prices for Namma Yatri and others soon. It does **not** replace direct approval from Uber, Ola or Rapido.

## Spec
* Repo: https://github.com/ONDC-Official/mobility-specification, domain **TRV10** (on-demand ride hailing), latest
  branch `release-TRV10-2.1.0`. Swagger: https://ondc-official.github.io/mobility-specification/
* Modes: car, auto-rickshaw, motorcycle (matches our car/auto/bike).
* Flow (async, callbacks): `search → on_search` (catalogue with **prices and ETAs per seller**) →
  `select/init/confirm` (booking; **we stop after on_search**, because there is no booking per our rules).
* Reference buyer app: `ONDC-Official/Mobility-BAP-Reference-App`; mock server, sandbox and log validator in the org.
* Known rough edges: open issues on TRV10 v2.1.0 (payment `collected_by`, missing ride states, rating schema).

> Open question to confirm with ONDC: is a **search-only** buyer app (price display, no booking) allowed on the
> network? Sellers bear search cost, so ONDC may require a booking flow. This decides whether ONDC fits our "no booking" rule.

## Onboarding (from developer-docs/registry/"Onboarding of Participants.md")
1. Register on https://portal.ondc.org, complete the profile 100%, and request environment whitelisting (6–48 h).
   A registered business entity is generally expected (confirm with ONDC).
2. Own a domain (the subscriber_id, e.g. `ondc.ridecompare.in`) with a valid SSL certificate. Requires a public server, so this means **cost**.
3. Generate an Ed25519 signing key pair and an X25519 encryption key pair (keep them in a secrets manager, never in git).
4. Host `https://<subscriber_id>/ondc-site-verification.html` (signed request id) and a `/on_subscribe` endpoint that
   decrypts the registry's challenge.
5. Call `/subscribe` on pre-prod (`preprod.registry.ondc.org/ondc/subscribe`) with `ops_no: 1` (buyer app).
   The staging registry is retired.
6. Implement the TRV10 calls with signed headers, pass ONDC's flow tests/log verification, then repeat for production.
Support: techsupport@ondc.org.

## How it would fit RideCompare
A new `OndcAdapter` in `backend/src/infrastructure/providers/ondc/` that sends `search`, collects `on_search` callbacks
for about 3 s, and maps each seller's items to our `RideOption` (`dataSource: 'live'`, provider = the seller's name).
It needs a public HTTPS callback URL, so it can't run on localhost only. Nothing has been built yet: we wait for ONDC's answer on search-only use.
