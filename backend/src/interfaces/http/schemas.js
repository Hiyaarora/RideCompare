import { z } from 'zod';
import { CATEGORIES, PROVIDER_IDS } from '../../domain/rideTypes.js';

const lat = z.coerce.number().min(-90).max(90);
const lng = z.coerce.number().min(-180).max(180);

const place = z.object({
  name: z.string().trim().min(1).max(200),
  address: z.string().trim().max(300).optional().default(''),
  placeId: z.string().max(300).nullish(),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

export const compareBody = z.object({
  pickup: place,
  drop: place,
  providers: z.array(z.enum(PROVIDER_IDS)).min(1).optional(),
  categories: z.array(z.enum(CATEGORIES)).min(1).optional(),
});

export const autocompleteQuery = z
  .object({
    q: z.string().trim().min(2, 'Type at least 2 characters').max(100),
    lat: lat.optional(),
    lng: lng.optional(),
    sessionToken: z.string().max(100).optional(),
  })
  .refine((v) => (v.lat == null) === (v.lng == null), { message: 'lat and lng must be sent together' });

export const reverseQuery = z.object({ lat, lng });

export const placeParams = z.object({ placeId: z.string().min(1).max(300) });
export const placeQuery = z.object({ sessionToken: z.string().max(100).optional() });

export const recentQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(10) });
