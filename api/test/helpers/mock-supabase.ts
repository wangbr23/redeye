import { SupabaseClient } from "@supabase/supabase-js";

export type MockRow = Record<string, unknown>;

type Tables = { trips: MockRow[]; tripDays: MockRow[]; activities: MockRow[] };

type Filter =
  | { column: string; op: "eq"; value: unknown }
  | { column: string; op: "in"; value: unknown[] }
  | { column: string; op: "not"; value: unknown };

export type RecordedCall = {
  table: string;
  operation: "select" | "insert" | "update" | "delete";
  columns?: string;
  payload?: unknown;
  filters: Filter[];
};

export class MockSupabase implements Tables {
  trips: MockRow[] = [];
  tripDays: MockRow[] = [];
  activities: MockRow[] = [];
  calls: RecordedCall[] = [];
  failNext: { table: string; operation: string; message: string } | null = null;

  nextId = 0;

  from(table: string): QueryBuilder {
    return new QueryBuilder(this, table);
  }
}

type BuilderOp = "select" | "insert" | "update" | "delete";

const TABLE_TO_PROP: Record<string, keyof Tables> = {
  trips: "trips",
  trip_days: "tripDays",
  activities: "activities",
};

class QueryBuilder implements PromiseLike<{ data: unknown; error: unknown }> {
  private filters: Filter[] = [];
  private orderBys: Array<{
    column: string;
    referencedTable?: string;
    ascending: boolean;
  }> = [];
  private isSingle = false;
  private op: BuilderOp | null = null;
  private columns = "";
  private payload: unknown = null;

  constructor(
    private db: MockSupabase,
    private table: string
  ) {}

  private get rows(): MockRow[] {
    const prop = TABLE_TO_PROP[this.table];
    return this.db[prop] as unknown as MockRow[];
  }

  private setRows(rows: MockRow[]) {
    const prop = TABLE_TO_PROP[this.table];
    this.db[prop] = rows as unknown as MockRow[];
  }

  private matches(row: MockRow): boolean {
    return this.filters.every((f) => {
      const val = row[f.column];
      if (f.op === "eq") return val === f.value;
      if (f.op === "in") return f.value.includes(val);
      // "not" with "is null" semantics
      return val !== f.value;
    });
  }

  private record() {
    this.db.calls.push({
      table: this.table,
      operation: this.op as BuilderOp,
      columns: this.op === "select" ? this.columns : undefined,
      payload: this.op === "insert" || this.op === "update" ? this.payload : undefined,
      filters: [...this.filters],
    });
  }

  private consumeFail(): unknown | null {
    if (
      this.db.failNext &&
      this.db.failNext.table === this.table &&
      this.db.failNext.operation === this.op
    ) {
      const { message } = this.db.failNext;
      this.db.failNext = null;
      return message;
    }
    return null;
  }

  private execute(): { data: unknown; error: unknown } {
    this.record();
    const fail = this.consumeFail();
    if (fail) {
      return { data: null, error: { message: fail } };
    }

    if (this.op === "insert") {
      const batch = (Array.isArray(this.payload) ? this.payload : [this.payload]) as MockRow[];
      const inserted = batch.map((r) => {
        const id = r.id ?? `generated-${++this.db.nextId}`;
        this.rows.push({ ...r, id });
        return { ...r, id };
      });
      return { data: inserted, error: null };
    }

    if (this.op === "update") {
      for (const row of this.rows) {
        if (this.matches(row)) Object.assign(row, this.payload as MockRow);
      }
      return { data: null, error: null };
    }

    if (this.op === "delete") {
      this.setRows(this.rows.filter((r) => !this.matches(r)));
      return { data: null, error: null };
    }

    // select
    let result = this.rows.filter((r) => this.matches(r));
    for (const o of this.orderBys) {
      if (!o.referencedTable) {
        result = [...result].sort((a, b) => {
          const av = a[o.column];
          const bv = b[o.column];
          if (av === bv) return 0;
          const cmp =
            av === undefined ? 1 : bv === undefined ? -1 : String(av) < String(bv) ? -1 : 1;
          return o.ascending ? cmp : -cmp;
        });
      }
    }

    if (this.isSingle) {
      if (result.length !== 1) {
        return {
          data: null,
          error: { code: "PGRST116", message: "The result contains 0 rows" },
        };
      }
      return { data: this.withNested(result[0]), error: null };
    }

    return { data: result.map((r) => this.withNested(r)), error: null };
  }

  private withNested(row: MockRow): MockRow {
    const out: MockRow = { ...row };
    if (this.columns.includes("trip_days(*)")) {
      out.trip_days = this.db.tripDays
        .filter((d) => d.trip_id === row.id)
        .sort((a, b) => Number(a.day_number) - Number(b.day_number));
    }
    if (this.columns.includes("activities(*)")) {
      out.activities = this.db.activities
        .filter((a) => a.trip_id === row.id)
        .sort((a, b) => Number(a.sort_order) - Number(b.sort_order));
    }
    return out;
  }

  then<TResult1 = { data: unknown; error: unknown }, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: unknown; error: unknown }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ): PromiseLike<TResult1 | TResult2> {
    return Promise.resolve(this.execute()).then(onfulfilled, onrejected);
  }

  select(columns: string) {
    this.op = "select";
    this.columns = columns;
    return this;
  }

  insert(rows: MockRow | MockRow[]) {
    this.op = "insert";
    this.payload = rows;
    return this;
  }

  update(payload: MockRow) {
    this.op = "update";
    this.payload = payload;
    return this;
  }

  delete() {
    this.op = "delete";
    return this;
  }

  eq(column: string, value: unknown) {
    this.filters.push({ column, op: "eq", value });
    return this;
  }

  in(column: string, value: unknown[]) {
    this.filters.push({ column, op: "in", value });
    return this;
  }

  not(column: string, _operator: string, value: unknown) {
    this.filters.push({ column, op: "not", value });
    return this;
  }

  order(
    column: string,
    opts?: { referencedTable?: string; ascending?: boolean }
  ) {
    this.orderBys.push({
      column,
      referencedTable: opts?.referencedTable,
      ascending: opts?.ascending ?? true,
    });
    return this;
  }

  single() {
    this.isSingle = true;
    return this;
  }
}

export function asSupabase(mock: MockSupabase): SupabaseClient {
  return mock as unknown as SupabaseClient;
}
