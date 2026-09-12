const PLACES_API_KEY = process.env.GOOGLE_PLACES_API_KEY;
const PLACES_BASE_URL = "https://places.googleapis.com/v1/places";

export interface PlaceResult {
  placeId: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  rating?: number;
  types: string[];
}

export async function searchPlaces(
  query: string,
  lat?: number,
  lng?: number
): Promise<PlaceResult[]> {
  const body: Record<string, unknown> = {
    textQuery: query,
    maxResultCount: 20,
  };

  if (lat != null && lng != null) {
    body.locationBias = {
      circle: { center: { latitude: lat, longitude: lng }, radius: 10000 },
    };
  }

  const response = await fetch(`${PLACES_BASE_URL}:searchText`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": PLACES_API_KEY!,
      "X-Goog-FieldMask":
        "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.types",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Places API error: ${response.status}`);
  }

  const data = await response.json();
  return (data.places ?? []).map(
    (p: {
      id: string;
      displayName: { text: string };
      formattedAddress: string;
      location: { latitude: number; longitude: number };
      rating?: number;
      types: string[];
    }) => ({
      placeId: p.id,
      name: p.displayName.text,
      address: p.formattedAddress,
      latitude: p.location.latitude,
      longitude: p.location.longitude,
      rating: p.rating,
      types: p.types ?? [],
    })
  );
}

export async function getPlaceDetails(placeId: string): Promise<PlaceResult> {
  const response = await fetch(`${PLACES_BASE_URL}/${placeId}`, {
    headers: {
      "X-Goog-Api-Key": PLACES_API_KEY!,
      "X-Goog-FieldMask":
        "id,displayName,formattedAddress,location,rating,types",
    },
  });

  if (!response.ok) {
    throw new Error(`Places API error: ${response.status}`);
  }

  const p = await response.json();
  return {
    placeId: p.id,
    name: p.displayName.text,
    address: p.formattedAddress,
    latitude: p.location.latitude,
    longitude: p.location.longitude,
    rating: p.rating,
    types: p.types ?? [],
  };
}
