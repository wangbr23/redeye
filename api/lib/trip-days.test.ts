import { describe, expect, it, beforeEach } from "vitest";
import { generateTripDays, regenerateDaysForDateChange } from "./trip-days";
import { MockSupabase, asSupabase } from "../test/helpers/mock-supabase";

const TRIP_ID = "trip-1";

function day(date: string, dayNumber: number, id: string) {
  return { id, trip_id: TRIP_ID, date, day_number: dayNumber };
}

function activity(id: string, tripDayId: string | null, tripId = TRIP_ID) {
  return { id, trip_id: tripId, trip_day_id: tripDayId, name: id };
}

let db: MockSupabase;

beforeEach(() => {
  db = new MockSupabase();
});

describe("generateTripDays", () => {
  it("inserts one row per date in the range with sequential day numbers", async () => {
    await generateTripDays(asSupabase(db), TRIP_ID, "2026-09-01", "2026-09-03");

    expect(db.tripDays).toHaveLength(3);
    expect(db.tripDays.map((d) => d.date)).toEqual([
      "2026-09-01",
      "2026-09-02",
      "2026-09-03",
    ]);
    expect(db.tripDays.map((d) => d.day_number)).toEqual([1, 2, 3]);
    expect(db.tripDays.every((d) => d.trip_id === TRIP_ID)).toBe(true);
  });

  it("handles a range crossing a month boundary", async () => {
    await generateTripDays(asSupabase(db), TRIP_ID, "2026-09-29", "2026-10-02");

    expect(db.tripDays.map((d) => d.date)).toEqual([
      "2026-09-29",
      "2026-09-30",
      "2026-10-01",
      "2026-10-02",
    ]);
  });

  it("does nothing when the range is empty", async () => {
    // end before start produces no dates
    await generateTripDays(asSupabase(db), TRIP_ID, "2026-09-05", "2026-09-01");
    expect(db.tripDays).toHaveLength(0);
  });
});

describe("regenerateDaysForDateChange", () => {
  it("renumbers all days sequentially after removing some dates", async () => {
    db.tripDays = [
      day("2026-09-01", 1, "d1"),
      day("2026-09-02", 2, "d2"),
      day("2026-09-03", 3, "d3"),
    ];
    db.activities = [
      activity("a1", "d1"),
      activity("a2", "d2"),
      activity("a3", "d3"),
    ];

    await regenerateDaysForDateChange(
      asSupabase(db),
      TRIP_ID,
      "2026-09-01",
      "2026-09-03",
      "2026-09-02",
      "2026-09-03"
    );

    // Removed day d1 deleted; its activity detached
    expect(db.tripDays.map((d) => d.id)).toEqual(["d2", "d3"]);
    expect(db.activities.find((a) => a.id === "a1")?.trip_day_id).toBeNull();
    expect(db.activities.find((a) => a.id === "a2")?.trip_day_id).toBe("d2");
    // Renumbered sequentially by date
    expect(db.tripDays.map((d) => d.day_number)).toEqual([1, 2]);
  });

  it("adds new days and renumbers after extending the range", async () => {
    db.tripDays = [
      day("2026-09-01", 1, "d1"),
      day("2026-09-02", 2, "d2"),
    ];

    await regenerateDaysForDateChange(
      asSupabase(db),
      TRIP_ID,
      "2026-09-01",
      "2026-09-02",
      "2026-09-01",
      "2026-09-04"
    );

    expect(db.tripDays).toHaveLength(4);
    expect(db.tripDays.map((d) => d.date)).toEqual([
      "2026-09-01",
      "2026-09-02",
      "2026-09-03",
      "2026-09-04",
    ]);
    expect(db.tripDays.map((d) => d.day_number)).toEqual([1, 2, 3, 4]);
  });

  it("handles a full shift where some dates are removed and others added", async () => {
    db.tripDays = [
      day("2026-09-01", 1, "d1"),
      day("2026-09-02", 2, "d2"),
      day("2026-09-03", 3, "d3"),
    ];
    db.activities = [activity("a1", "d1"), activity("a2", "d3")];

    await regenerateDaysForDateChange(
      asSupabase(db),
      TRIP_ID,
      "2026-09-01",
      "2026-09-03",
      "2026-09-03",
      "2026-09-05"
    );

    // d1 removed, d3 kept; d4, d5 added
    expect(db.tripDays.map((d) => d.date).sort()).toEqual([
      "2026-09-03",
      "2026-09-04",
      "2026-09-05",
    ]);
    // a1 detached (was on removed d1)
    expect(db.activities.find((a) => a.id === "a1")?.trip_day_id).toBeNull();
    // a2 stays attached to d3
    expect(db.activities.find((a) => a.id === "a2")?.trip_day_id).toBe("d3");
    // final renumber is sequential
    expect(
      db.tripDays.map((d) => Number(d.day_number)).sort((a, b) => a - b)
    ).toEqual([1, 2, 3]);
  });

  it("detaches activities before deleting removed days", async () => {
    db.tripDays = [day("2026-09-01", 1, "d1"), day("2026-09-02", 2, "d2")];
    db.activities = [activity("a1", "d1")];

    await regenerateDaysForDateChange(
      asSupabase(db),
      TRIP_ID,
      "2026-09-01",
      "2026-09-02",
      "2026-09-02",
      "2026-09-02"
    );

    const updateCall = db.calls.find(
      (c) => c.table === "activities" && c.operation === "update"
    );
    const deleteCall = db.calls.find(
      (c) => c.table === "trip_days" && c.operation === "delete"
    );

    expect(updateCall).toBeDefined();
    expect(deleteCall).toBeDefined();
    const updateIdx = db.calls.indexOf(updateCall!);
    const deleteIdx = db.calls.indexOf(deleteCall!);
    expect(updateIdx).toBeLessThan(deleteIdx);
    expect(updateCall!.filters).toEqual([
      { column: "trip_day_id", op: "in", value: ["d1"] },
    ]);
  });

  it("keeps existing days unchanged when the range does not change", async () => {
    db.tripDays = [day("2026-09-01", 1, "d1"), day("2026-09-02", 2, "d2")];

    await regenerateDaysForDateChange(
      asSupabase(db),
      TRIP_ID,
      "2026-09-01",
      "2026-09-02",
      "2026-09-01",
      "2026-09-02"
    );

    expect(db.tripDays.map((d) => ({ id: d.id, day_number: d.day_number }))).toEqual([
      { id: "d1", day_number: 1 },
      { id: "d2", day_number: 2 },
    ]);
  });
});
