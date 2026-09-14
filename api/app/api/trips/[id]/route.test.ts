import { describe, expect, it, vi, beforeEach } from "vitest";
import { NextRequest, NextResponse } from "next/server";
import { MockSupabase, asSupabase } from "@/test/helpers/mock-supabase";

vi.mock("@/lib/auth", () => ({
  authenticateRequest: vi.fn(),
}));

import { authenticateRequest } from "@/lib/auth";
import { GET, PATCH, DELETE } from "./route";

const authMock = vi.mocked(authenticateRequest);

function req(
  url: string,
  init?: ConstructorParameters<typeof NextRequest>[1]
): NextRequest {
  return new NextRequest(url, init);
}

function routeContext(id: string) {
  return { params: Promise.resolve({ id }) };
}

function asAuth(supabase: MockSupabase) {
  return { userId: "user-1", token: "token", supabase: asSupabase(supabase) };
}

const TRIP = {
  id: "trip-1",
  user_id: "user-1",
  title: "Paris",
  destination: "Paris",
  start_date: "2026-09-01",
  end_date: "2026-09-03",
  mode: "structured",
  status: "active",
};

let db: MockSupabase;

beforeEach(() => {
  db = new MockSupabase();
  authMock.mockReset();
  authMock.mockResolvedValue(asAuth(db));
});

describe("GET /api/trips/[id]", () => {
  it("returns the trip with nested days and activities", async () => {
    db.trips = [{ ...TRIP }];
    db.tripDays = [{ id: "d1", trip_id: TRIP.id, date: "2026-09-01", day_number: 1 }];
    db.activities = [{ id: "a1", trip_id: TRIP.id, trip_day_id: "d1", name: "Eiffel", sort_order: 0 }];

    const res = await GET(req("http://localhost/api/trips/trip-1"), routeContext("trip-1"));
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.id).toBe("trip-1");
    expect(body.trip_days).toEqual([
      { id: "d1", trip_id: TRIP.id, date: "2026-09-01", day_number: 1 },
    ]);
    expect(body.activities).toEqual([
      { id: "a1", trip_id: TRIP.id, trip_day_id: "d1", name: "Eiffel", sort_order: 0 },
    ]);
  });

  it("returns 404 when the trip does not exist", async () => {
    const res = await GET(req("http://localhost/api/trips/nope"), routeContext("nope"));
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: "Trip not found" });
  });

  it("returns 401 when not authenticated", async () => {
    authMock.mockResolvedValue(
      NextResponse.json({ error: "Missing authorization" }, { status: 401 })
    );
    const res = await GET(req("http://localhost/api/trips/trip-1"), routeContext("trip-1"));
    expect(res.status).toBe(401);
  });
});

describe("PATCH /api/trips/[id]", () => {
  it("updates basic fields", async () => {
    db.trips = [{ ...TRIP }];
    const res = await PATCH(
      req("http://localhost/api/trips/trip-1", {
        method: "PATCH",
        body: JSON.stringify({ title: "Lyon" }),
      }),
      routeContext("trip-1")
    );

    expect(res.status).toBe(200);
    expect(db.trips[0].title).toBe("Lyon");
    expect((await res.json()).title).toBe("Lyon");
  });

  it("switches structured → unstructured: detaches activities and deletes days", async () => {
    db.trips = [{ ...TRIP }];
    db.tripDays = [{ id: "d1", trip_id: TRIP.id, date: "2026-09-01", day_number: 1 }];
    db.activities = [
      { id: "a1", trip_id: TRIP.id, trip_day_id: "d1", name: "Eiffel", sort_order: 0 },
    ];

    const res = await PATCH(
      req("http://localhost/api/trips/trip-1", {
        method: "PATCH",
        body: JSON.stringify({ mode: "unstructured" }),
      }),
      routeContext("trip-1")
    );

    expect(res.status).toBe(200);
    expect(db.tripDays).toHaveLength(0);
    expect(db.activities[0].trip_day_id).toBeNull();
    expect(db.activities[0].start_time).toBeNull();
    expect(db.activities[0].end_time).toBeNull();
    expect(db.trips[0].mode).toBe("unstructured");
  });

  it("switches unstructured → structured: generates days for the range", async () => {
    db.trips = [{ ...TRIP, mode: "unstructured" }];
    const res = await PATCH(
      req("http://localhost/api/trips/trip-1", {
        method: "PATCH",
        body: JSON.stringify({ mode: "structured" }),
      }),
      routeContext("trip-1")
    );

    expect(res.status).toBe(200);
    expect(db.tripDays).toHaveLength(3);
    expect(db.tripDays.map((d) => d.day_number)).toEqual([1, 2, 3]);
  });

  it("regenerates days on a date change", async () => {
    db.trips = [{ ...TRIP }];
    db.tripDays = [
      { id: "d1", trip_id: TRIP.id, date: "2026-09-01", day_number: 1 },
      { id: "d2", trip_id: TRIP.id, date: "2026-09-02", day_number: 2 },
      { id: "d3", trip_id: TRIP.id, date: "2026-09-03", day_number: 3 },
    ];
    db.activities = [
      { id: "a1", trip_id: TRIP.id, trip_day_id: "d1", name: "Eiffel", sort_order: 0 },
    ];

    const res = await PATCH(
      req("http://localhost/api/trips/trip-1", {
        method: "PATCH",
        body: JSON.stringify({ startDate: "2026-09-02", endDate: "2026-09-03" }),
      }),
      routeContext("trip-1")
    );

    expect(res.status).toBe(200);
    expect(db.trips[0].start_date).toBe("2026-09-02");
    expect(db.tripDays.map((d) => d.date)).toEqual(["2026-09-02", "2026-09-03"]);
    expect(db.activities.find((a) => a.id === "a1")?.trip_day_id).toBeNull();
  });

  it("leaves the trip row unchanged when regeneration fails", async () => {
    db.trips = [{ ...TRIP }];
    db.tripDays = [{ id: "d1", trip_id: TRIP.id, date: "2026-09-01", day_number: 1 }];
    db.failNext = {
      table: "trip_days",
      operation: "delete",
      message: "boom",
    };

    const res = await PATCH(
      req("http://localhost/api/trips/trip-1", {
        method: "PATCH",
        body: JSON.stringify({ mode: "unstructured" }),
      }),
      routeContext("trip-1")
    );

    expect(res.status).toBe(500);
    expect(db.trips[0].mode).toBe("structured");
    expect(db.tripDays).toHaveLength(1);
  });

  it("rejects an end date before the start date", async () => {
    db.trips = [{ ...TRIP }];
    const res = await PATCH(
      req("http://localhost/api/trips/trip-1", {
        method: "PATCH",
        body: JSON.stringify({ startDate: "2026-09-05", endDate: "2026-09-01" }),
      }),
      routeContext("trip-1")
    );

    expect(res.status).toBe(400);
    expect((await res.json()).error).toMatch(/endDate/);
  });

  it("returns 404 when the trip does not exist", async () => {
    const res = await PATCH(
      req("http://localhost/api/trips/nope", {
        method: "PATCH",
        body: JSON.stringify({ title: "X" }),
      }),
      routeContext("nope")
    );
    expect(res.status).toBe(404);
  });
});

describe("DELETE /api/trips/[id]", () => {
  it("deletes the trip", async () => {
    db.trips = [{ ...TRIP }];
    const res = await DELETE(req("http://localhost/api/trips/trip-1"), routeContext("trip-1"));
    expect(res.status).toBe(204);
    expect(db.trips).toHaveLength(0);
  });
});
