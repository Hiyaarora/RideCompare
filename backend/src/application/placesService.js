/** Use cases for location search. Thin by design: the maps client does the real work. */
export class PlacesService {
  constructor({ maps }) {
    this.maps = maps;
  }

  get source() {
    return this.maps.source;
  }

  autocomplete({ q, lat, lng, sessionToken }) {
    const bias = lat != null && lng != null ? { lat, lng } : null;
    return this.maps.autocomplete({ query: q, bias, sessionToken });
  }

  details(placeId, sessionToken) {
    return this.maps.placeDetails(placeId, sessionToken);
  }

  reverse({ lat, lng }) {
    return this.maps.reverseGeocode({ lat, lng });
  }
}
