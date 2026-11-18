# RideCompare backend

Express 5 REST API that compares ride estimates across provider adapters. See
[../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) for the layer diagram and full API reference.

```zsh
mongo-start                 # MongoDB (optional: the API works without it, minus search history)
cp -n .env.example .env     # then edit if needed
npm install
npm run dev                 # restarts on file changes
npm start                   # production-style
npm test                    # 22 tests, no database or network needed
```

## Configuration (`.env`)

| Variable | Default | Notes |
|---|---|---|
| `PORT` | 4000 | Listens on all interfaces so emulators/devices can reach it |
| `MONGODB_URI` | `mongodb://127.0.0.1:27017/ridecompare` | |
| `GOOGLE_MAPS_API_KEY` | _(empty)_ | Empty = demo places + estimated routes. Enable Places API (New), Geocoding API and Routes API, and restrict the key |
| `UBER_CLIENT_ID`, `UBER_CLIENT_SECRET`, `UBER_ORG_UUID` or `UBER_SERVER_TOKEN` | empty | Uber goes live when set. **Read docs/PROVIDER_APIS.md first.** Needs Uber's approval |
| `OLA_APP_TOKEN` (+ `OLA_USER_TOKEN`) | empty | Ola goes live when set. Invite-only partner API |
| `UPSTREAM_TIMEOUT_MS` | 6000 | Per provider/maps call |
| `CORS_ORIGINS` | `http://localhost:3000` | Browser origins only; mobile apps don't use CORS |

## Try it

```zsh
curl -s localhost:4000/api/v1/health
curl -s 'localhost:4000/api/v1/places/autocomplete?q=airport&lat=12.97&lng=77.59'
curl -s -X POST localhost:4000/api/v1/compare -H 'Content-Type: application/json' \
  -d '{"pickup":{"name":"MG Road","lat":12.9755,"lng":77.6068},"drop":{"name":"HSR Layout","lat":12.9121,"lng":77.6446}}'
```

## Adding a provider

1. Only with an official, authorised API: create `src/infrastructure/providers/<name>/` with a live client
   exposing `getEstimates({ pickup, drop, route, categories, now })` that returns `liveOption(...)` items (`normalize.js`).
2. Add a `<Name>Provider extends RideProvider` that passes the client when its credentials are set.
3. Register it in `providers/registry.js` and add the id to `domain/rideTypes.js`.
