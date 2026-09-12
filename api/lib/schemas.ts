import { z } from "zod";

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const timeHHmm = z.string().regex(/^\d{2}:\d{2}$/);
const category = z.enum([
  "restaurant",
  "attraction",
  "shopping",
  "museum",
  "nightlife",
  "other",
]);
const tripMode = z.enum(["structured", "unstructured"]);
const tripStatus = z.enum(["active", "archived"]);
const activityStatus = z.enum(["planned", "visited", "skipped"]);
const activitySource = z.enum(["manual", "ai_generated", "places_api"]);

export const CreateTripInput = z.object({
  title: z.string().min(1).max(200),
  destination: z.string().min(1).max(200),
  startDate: isoDate,
  endDate: isoDate,
  mode: tripMode,
  homeBaseName: z.string().max(200).optional(),
  homeBaseAddress: z.string().max(500).optional(),
  homeBaseLat: z.number().gte(-90).lte(90).optional(),
  homeBaseLng: z.number().gte(-180).lte(180).optional(),
  preferences: z.record(z.string(), z.unknown()).optional(),
});

export const UpdateTripInput = CreateTripInput.partial().extend({
  status: tripStatus.optional(),
});

export const CreateActivityInput = z.object({
  name: z.string().min(1).max(300),
  category,
  tripDayId: z.string().uuid().optional(),
  area: z.string().max(200).optional(),
  latitude: z.number().gte(-90).lte(90).optional(),
  longitude: z.number().gte(-180).lte(180).optional(),
  address: z.string().max(500).optional(),
  startTime: timeHHmm.optional(),
  endTime: timeHHmm.optional(),
  durationMin: z.number().int().gte(1).optional(),
  sortOrder: z.number().int().gte(0).optional(),
  source: activitySource.optional(),
  placeId: z.string().max(300).optional(),
  notes: z.string().max(2000).optional(),
});

export const UpdateActivityInput = CreateActivityInput.partial().extend({
  status: activityStatus.optional(),
});

export const ReorderInput = z.array(
  z.object({
    id: z.string().uuid(),
    sortOrder: z.number().int().gte(0),
    tripDayId: z.string().uuid().nullable().optional(),
  })
);

const GeneratedActivity = z.object({
  name: z.string(),
  category,
  description: z.string(),
  area: z.string(),
  latitude: z.number(),
  longitude: z.number(),
  address: z.string(),
  durationMin: z.number().int().gte(1),
  startTime: timeHHmm.optional(),
  endTime: timeHHmm.optional(),
});

export const GeneratedStructuredDay = z.object({
  dayNumber: z.number().int().gte(1),
  activities: z.array(GeneratedActivity),
});

export const GeneratedUnstructuredGroup = z.object({
  area: z.string(),
  activities: z.array(GeneratedActivity),
});

export const StructuredItinerary = z.object({
  days: z.array(GeneratedStructuredDay),
});

export const UnstructuredItinerary = z.object({
  groups: z.array(GeneratedUnstructuredGroup),
});

export type CreateTripInputType = z.infer<typeof CreateTripInput>;
export type UpdateTripInputType = z.infer<typeof UpdateTripInput>;
export type CreateActivityInputType = z.infer<typeof CreateActivityInput>;
export type UpdateActivityInputType = z.infer<typeof UpdateActivityInput>;
export type ReorderInputType = z.infer<typeof ReorderInput>;
