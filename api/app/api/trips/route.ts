import { NextRequest, NextResponse } from "next/server";
import { authenticateRequest } from "@/lib/auth";
import { CreateTripInput } from "@/lib/schemas";

export async function GET(request: NextRequest) {
  const auth = await authenticateRequest(request);
  if (auth instanceof NextResponse) return auth;

  const status = request.nextUrl.searchParams.get("status");

  let query = auth.supabase
    .from("trips")
    .select("*, trip_days(*), activities(*)")
    .order("created_at", { ascending: false });

  if (status === "active" || status === "archived") {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json(data);
}

export async function POST(request: NextRequest) {
  const auth = await authenticateRequest(request);
  if (auth instanceof NextResponse) return auth;

  const body = await request.json();
  const parsed = CreateTripInput.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0].message },
      { status: 400 }
    );
  }

  const input = parsed.data;

  const startDate = new Date(input.startDate);
  const endDate = new Date(input.endDate);
  if (endDate < startDate) {
    return NextResponse.json(
      { error: "endDate must be on or after startDate" },
      { status: 400 }
    );
  }

  const { data: trip, error: tripError } = await auth.supabase
    .from("trips")
    .insert({
      user_id: auth.userId,
      title: input.title,
      destination: input.destination,
      start_date: input.startDate,
      end_date: input.endDate,
      mode: input.mode,
      home_base_name: input.homeBaseName ?? null,
      home_base_address: input.homeBaseAddress ?? null,
      home_base_lat: input.homeBaseLat ?? null,
      home_base_lng: input.homeBaseLng ?? null,
      preferences: input.preferences ?? null,
    })
    .select()
    .single();

  if (tripError || !trip) {
    return NextResponse.json(
      { error: tripError?.message ?? "Failed to create trip" },
      { status: 500 }
    );
  }

  // Generate trip_days for structured mode
  let tripDays: unknown[] = [];
  if (input.mode === "structured") {
    const days = [];
    const current = new Date(startDate);
    let dayNumber = 1;
    while (current <= endDate) {
      days.push({
        trip_id: trip.id,
        date: current.toISOString().slice(0, 10),
        day_number: dayNumber,
      });
      current.setUTCDate(current.getUTCDate() + 1);
      dayNumber++;
    }

    if (days.length > 0) {
      const { data, error: daysError } = await auth.supabase
        .from("trip_days")
        .insert(days)
        .select();

      if (daysError) {
        return NextResponse.json(
          { error: daysError.message },
          { status: 500 }
        );
      }
      tripDays = data ?? [];
    }
  }

  return NextResponse.json(
    { ...trip, trip_days: tripDays, activities: [] },
    { status: 201 }
  );
}
