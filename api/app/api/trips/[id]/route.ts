import { NextRequest, NextResponse } from "next/server";
import { authenticateRequest } from "@/lib/auth";
import { UpdateTripInput, type UpdateTripInputType } from "@/lib/schemas";
import { generateTripDays, regenerateDaysForDateChange } from "@/lib/trip-days";

type RouteContext = { params: Promise<{ id: string }> };

const nestedSelect = "*, trip_days(*), activities(*)";
const nestedOrder = [
  { column: "day_number", referencedTable: "trip_days" },
  { column: "sort_order", referencedTable: "activities" },
] as const;

// UpdateTripInput field -> trips column. Iterated so only provided fields
// are applied, keeping an empty PATCH a no-op.
const FIELD_MAP: ReadonlyArray<[keyof UpdateTripInputType, string]> = [
  ["title", "title"],
  ["destination", "destination"],
  ["startDate", "start_date"],
  ["endDate", "end_date"],
  ["mode", "mode"],
  ["status", "status"],
  ["homeBaseName", "home_base_name"],
  ["homeBaseAddress", "home_base_address"],
  ["homeBaseLat", "home_base_lat"],
  ["homeBaseLng", "home_base_lng"],
  ["preferences", "preferences"],
];

export async function GET(request: NextRequest, context: RouteContext) {
  const auth = await authenticateRequest(request);
  if (auth instanceof NextResponse) return auth;

  const { id } = await context.params;

  const query = auth.supabase
    .from("trips")
    .select(nestedSelect)
    .eq("id", id);

  for (const { column, referencedTable } of nestedOrder) {
    query.order(column, { referencedTable, ascending: true });
  }

  const { data, error } = await query.single();

  if (error || !data) {
    const status = error?.code === "PGRST116" ? 404 : 500;
    return NextResponse.json(
      { error: status === 404 ? "Trip not found" : error?.message },
      { status }
    );
  }

  return NextResponse.json(data);
}

export async function PATCH(request: NextRequest, context: RouteContext) {
  const auth = await authenticateRequest(request);
  if (auth instanceof NextResponse) return auth;

  const { id } = await context.params;

  const body = await request.json();
  const parsed = UpdateTripInput.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0].message },
      { status: 400 }
    );
  }

  const input = parsed.data;

  // Fetch the existing trip to detect date or mode changes
  const { data: existing, error: fetchError } = await auth.supabase
    .from("trips")
    .select("*, trip_days(*)")
    .eq("id", id)
    .single();

  if (fetchError || !existing) {
    const status = fetchError?.code === "PGRST116" ? 404 : 500;
    return NextResponse.json(
      { error: status === 404 ? "Trip not found" : fetchError?.message },
      { status }
    );
  }

  // Validate date ordering if either date is changing
  const effectiveStart = input.startDate ?? existing.start_date;
  const effectiveEnd = input.endDate ?? existing.end_date;
  if (new Date(effectiveEnd) < new Date(effectiveStart)) {
    return NextResponse.json(
      { error: "endDate must be on or after startDate" },
      { status: 400 }
    );
  }

  // Build the update payload (only provided fields)
  const updateFields: Record<string, unknown> = {};
  for (const [field, column] of FIELD_MAP) {
    const value = input[field];
    if (value !== undefined) updateFields[column] = value;
  }

  const effectiveMode = input.mode ?? existing.mode;
  const datesChanged =
    effectiveStart !== existing.start_date ||
    effectiveEnd !== existing.end_date;
  const switchedToUnstructured =
    input.mode === "unstructured" && existing.mode === "structured";
  const switchedToStructured =
    input.mode === "structured" && existing.mode === "unstructured";

  try {
    // Mode switch: structured → unstructured (§4.6a)
    // Detach activities from days, clear time fields, delete all trip_days
    if (switchedToUnstructured) {
      const { error: detachError } = await auth.supabase
        .from("activities")
        .update({ trip_day_id: null, start_time: null, end_time: null })
        .eq("trip_id", id)
        .not("trip_day_id", "is", null);

      if (detachError) throw new Error(detachError.message);

      const { error: deleteDaysError } = await auth.supabase
        .from("trip_days")
        .delete()
        .eq("trip_id", id);

      if (deleteDaysError) throw new Error(deleteDaysError.message);
    }

    // Mode switch: unstructured → structured (§4.6b)
    // Generate trip_days for the date range; activities stay unassigned
    if (switchedToStructured) {
      await generateTripDays(auth.supabase, id, effectiveStart, effectiveEnd);
    }

    // Date change within structured mode (§4.13)
    if (datesChanged && effectiveMode === "structured" && !switchedToStructured) {
      await regenerateDaysForDateChange(
        auth.supabase,
        id,
        existing.start_date,
        existing.end_date,
        effectiveStart,
        effectiveEnd
      );
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Trip update failed" },
      { status: 500 }
    );
  }

  // Apply the trip field update only after day regeneration succeeds, so a
  // regeneration failure leaves dates/mode unchanged and a retry re-runs it.
  if (Object.keys(updateFields).length > 0) {
    const { error: updateError } = await auth.supabase
      .from("trips")
      .update(updateFields)
      .eq("id", id);

    if (updateError) {
      return NextResponse.json(
        { error: updateError.message },
        { status: 500 }
      );
    }
  }

  // Return the updated trip with nested data
  const query = auth.supabase
    .from("trips")
    .select(nestedSelect)
    .eq("id", id);

  for (const { column, referencedTable } of nestedOrder) {
    query.order(column, { referencedTable, ascending: true });
  }

  const { data: updated, error: refetchError } = await query.single();

  if (refetchError || !updated) {
    return NextResponse.json(
      { error: refetchError?.message ?? "Failed to fetch updated trip" },
      { status: 500 }
    );
  }

  return NextResponse.json(updated);
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const auth = await authenticateRequest(request);
  if (auth instanceof NextResponse) return auth;

  const { id } = await context.params;

  const { error } = await auth.supabase
    .from("trips")
    .delete()
    .eq("id", id);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return new NextResponse(null, { status: 204 });
}