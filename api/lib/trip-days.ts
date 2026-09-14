import { SupabaseClient } from "@supabase/supabase-js";

function dateRange(start: string, end: string): string[] {
  const dates: string[] = [];
  const current = new Date(start);
  const last = new Date(end);
  while (current <= last) {
    dates.push(current.toISOString().slice(0, 10));
    current.setUTCDate(current.getUTCDate() + 1);
  }
  return dates;
}

// Generate trip_days for a structured trip over the given date range.
// Throws on Supabase error so callers surface a 500 instead of returning stale data.
export async function generateTripDays(
  supabase: SupabaseClient,
  tripId: string,
  startDate: string,
  endDate: string
): Promise<void> {
  const dates = dateRange(startDate, endDate);
  if (dates.length === 0) return;

  const rows = dates.map((date, i) => ({
    trip_id: tripId,
    date,
    day_number: i + 1,
  }));

  const { error } = await supabase.from("trip_days").insert(rows);
  if (error) throw new Error(error.message);
}

// §4.13: Date change with day regeneration
// - Activities on removed days become unassigned (trip_day_id = null)
// - New days are inserted
// - All days are renumbered sequentially (INV-3)
export async function regenerateDaysForDateChange(
  supabase: SupabaseClient,
  tripId: string,
  oldStart: string,
  oldEnd: string,
  newStart: string,
  newEnd: string
): Promise<void> {
  const oldDates = new Set(dateRange(oldStart, oldEnd));
  const newDates = dateRange(newStart, newEnd);
  const newDatesSet = new Set(newDates);

  const removedDates = [...oldDates].filter((d) => !newDatesSet.has(d));
  const addedDates = newDates.filter((d) => !oldDates.has(d));

  // Detach activities from removed days, then delete those days
  if (removedDates.length > 0) {
    const { data: removedDays, error } = await supabase
      .from("trip_days")
      .select("id")
      .eq("trip_id", tripId)
      .in("date", removedDates);

    if (error) throw new Error(error.message);

    if (removedDays && removedDays.length > 0) {
      const removedIds = removedDays.map((d: { id: string }) => d.id);
      const { error: detachError } = await supabase
        .from("activities")
        .update({ trip_day_id: null })
        .in("trip_day_id", removedIds);
      if (detachError) throw new Error(detachError.message);

      const { error: deleteError } = await supabase
        .from("trip_days")
        .delete()
        .in("id", removedIds);
      if (deleteError) throw new Error(deleteError.message);
    }
  }

  if (addedDates.length > 0) {
    // Move existing days to temporary numbers above the final range so the
    // renumber pass below cannot violate unique (trip_id, day_number)
    const { data: existingDays, error: listError } = await supabase
      .from("trip_days")
      .select("id")
      .eq("trip_id", tripId);
    if (listError) throw new Error(listError.message);

    const existingCount = existingDays?.length ?? 0;
    const tempBase = newDates.length + 1;
    for (let i = 0; i < existingCount; i++) {
      const { error: bumpError } = await supabase
        .from("trip_days")
        .update({ day_number: tempBase + i })
        .eq("id", existingDays![i].id);
      if (bumpError) throw new Error(bumpError.message);
    }

    const rows = addedDates.map((date, i) => ({
      trip_id: tripId,
      date,
      day_number: tempBase + existingCount + i,
    }));
    const { error: insertError } = await supabase.from("trip_days").insert(rows);
    if (insertError) throw new Error(insertError.message);
  }

  // Renumber all remaining days sequentially by date (INV-3)
  const { data: allDays, error: renumberError } = await supabase
    .from("trip_days")
    .select("id, date")
    .eq("trip_id", tripId)
    .order("date", { ascending: true });
  if (renumberError) throw new Error(renumberError.message);

  if (allDays && allDays.length > 0) {
    for (let i = 0; i < allDays.length; i++) {
      const { error } = await supabase
        .from("trip_days")
        .update({ day_number: i + 1 })
        .eq("id", allDays[i].id);
      if (error) throw new Error(error.message);
    }
  }
}