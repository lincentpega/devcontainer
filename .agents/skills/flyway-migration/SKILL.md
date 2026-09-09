---
name: flyway-migration
description: >-
  Use when adding or changing a Flyway migration — a new `V*__*.sql` under
  `db/migration`, a table/column/index/constraint change, a lookup-row insert, or
  a data backfill. Enforces the two properties that matter in this codebase:
  every statement is re-runnable (idempotent), and the schema change is
  backward compatible with the code already running in production. Triggers on:
  "add a migration", "create table", "add a column", "add an index", "drop the
  table", "backfill", "alter the schema", "flyway", "V2xx", "новая миграция",
  or any task whose implementation needs a schema change — even if the user only
  describes the feature.
user-invocable: true
argument-hint: [ what the migration should change ]
---

# Flyway migrations

A migration is a script that will be run against databases you cannot inspect, in an order you
do not control, possibly more than once, while the previous version of the application is still
serving traffic. Write every file so that all four of those are fine.

Reference conventions: `baraka-services/corebanking-java/src/main/resources/db/migration`. The
older files there predate this rule — plenty of them are not idempotent. Follow this skill, not
the worst neighbour.

## Why these two properties, concretely

The service runs Flyway with `out-of-order: true` and `baseline-on-migrate: true`
(`application.yaml`). Consequences you must design for:

- **A script can be applied to a database that already has part of its effect.** Someone ran the
  DDL by hand during an incident; a non-transactional script (`CONCURRENTLY`) died halfway; an
  environment was baselined mid-history. Flyway will not know, and will run the file. If the first
  statement throws `relation already exists`, the deploy stops with a failed migration and a
  human has to clean up under time pressure. Idempotent statements make the re-run a no-op.
- **A lower-numbered migration can land after a higher-numbered one.** Two branches merge, or a
  hotfix ships first. So a file must never assume that some other migration has already run —
  keep each one self-contained, and guard anything that depends on existing shape.
- **Old and new code run at the same time.** Deploys are rolling and a hot-standby replica
  follows the primary. The schema after your migration must satisfy the code that is *currently*
  deployed as well as the code shipping with it. A dropped or renamed column takes down the pods
  that are still selecting it.

## Naming and placement

`src/main/resources/db/migration/V<yyyyMMddHHmmss>__<snake_case_description>.sql`, the version
being the moment you write the file — `V20260903101000__user_disable.sql`. Two branches can no
longer claim the same version, which is what the old sequential `V<next>` scheme kept colliding
on; `out-of-order: true` then lets a lower timestamp land after a higher one without trouble.

The files below `V212` predate this and keep their sequential numbers. Never renumber them — the
checksums are recorded in every environment.

Describe the change, verb first, matching the neighbours: `create_payment_turnover`,
`add_index_to_card_issue_outbox`, `alter_qr_payment_add_seller`, `drop_issuance_tables`,
`backfill_master_pan_issuance_process_failure_system`. One logical change per file.

## Idempotency: the re-runnable form of every statement

| Change | Write it as |
|---|---|
| new table | `CREATE TABLE IF NOT EXISTS t (...)` |
| new column | `ALTER TABLE t ADD COLUMN IF NOT EXISTS c ...` |
| new index | `CREATE [UNIQUE] INDEX IF NOT EXISTS ix ON t (...)` |
| drop anything | `DROP TABLE / INDEX IF EXISTS`, `ALTER TABLE t DROP COLUMN IF EXISTS c` |
| lookup / seed row | `INSERT ... VALUES ... ON CONFLICT (pk) DO NOTHING` |
| backfill | `UPDATE ... WHERE <rows not yet in the target state>` |
| new enum label | `ALTER TYPE t ADD VALUE IF NOT EXISTS 'X'` |
| set a column NOT NULL | already idempotent — but backfill first, see below |

Two cases Postgres gives no `IF NOT EXISTS` for. Guard them on the catalog:

```sql
-- constraint (see V108__add_retry_failure_prefix_length_check.sql)
DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_prefix_length') THEN
            ALTER TABLE t ADD CONSTRAINT chk_prefix_length CHECK (char_length(prefix) > 10);
        END IF;
    END
$$;
```

`ALTER TABLE t DROP CONSTRAINT IF EXISTS c; ALTER TABLE t ADD CONSTRAINT c ...;` is an acceptable
shorter form for a cheap CHECK on a small table — but on a large one the re-added constraint is
re-validated under an exclusive lock, so prefer the guard.

```sql
-- type (see V1__create_extensions_and_types.sql)
DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'p2p_transaction_status') THEN
            CREATE TYPE p2p_transaction_status AS ENUM ('init', 'confirmed');
        END IF;
    END
$$;
```

Extensions: `CREATE EXTENSION IF NOT EXISTS pg_trgm;`.

**Backfills are the easy place to get this wrong.** An `UPDATE` is idempotent only if its `WHERE`
excludes rows it has already fixed. `V197` does this well: `WHERE failure_system IS NULL AND ...`.
An `UPDATE ... SET counter = counter + 1` with no such guard corrupts data on a second run —
compute from the source columns instead of mutating in place.

**`CREATE INDEX CONCURRENTLY`** (`V203`) has two traps. Flyway runs such a script outside a
transaction, so put *nothing else* in that file — otherwise a mid-script failure leaves the file
half-applied. And a failed concurrent build leaves an **invalid** index behind, which
`IF NOT EXISTS` then happily skips forever, so the index silently never exists:

```sql
DO
$$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_index i ON i.indexrelid = c.oid
                   WHERE c.relname = 'idx_card_outbox_processable' AND NOT i.indisvalid) THEN
            EXECUTE 'DROP INDEX idx_card_outbox_processable';
        END IF;
    END
$$;
```

(That guard needs its own file, since the `CONCURRENTLY` file must stay single-statement.)

## Backward compatibility: expand, then contract

The migration ships before/with the new code and must not break the old code. So a release only
ever *adds*; removal happens in a later release, after nothing reads the thing any more.

**Adding a column.** Nullable, or `NOT NULL` with a `DEFAULT` — never `NOT NULL` without one,
because the currently running code inserts rows that don't mention the column. A constant default
is metadata-only in Postgres 11+, so it does not rewrite the table (`V184`, `V202`).

**Tightening to NOT NULL** is a three-step change, not one migration: add nullable → new code
starts writing it → later migration backfills the stragglers and flips the flag. `V173` shows the
last step, and note that it backfills *first*:

```sql
UPDATE t SET printed = false WHERE printed IS NULL;
ALTER TABLE t ALTER COLUMN printed SET DEFAULT false;
ALTER TABLE t ALTER COLUMN printed SET NOT NULL;
```

**Renaming** — don't. `ALTER TABLE ... RENAME COLUMN` (`V113`) breaks every pod that hasn't
restarted yet, and can't be re-run. Add the new column, backfill, switch the code, drop the old
one a release later.

**Dropping** a table or column: only once no deployed version references it. `V206`/`V193` are the
tail end of that process, and both use `IF EXISTS` throughout.

**New CHECK / FOREIGN KEY on a populated table.** Existing rows may violate it — verify with a
`SELECT count(*)` against production-shaped data first, and be aware that old code may still write
the now-forbidden value. On a large table add it `NOT VALID` and `VALIDATE CONSTRAINT` in a
follow-up migration; that keeps the exclusive lock to a moment instead of a full scan. For status
CHECK lists (`V79`, `V145`) adding a value is safe; removing one is a contract break.

**Types**: widen only (`varchar(32)` → `varchar(64)`, `varchar` → `text`). Narrowing, or
`int` → `bigint` on a big table, rewrites it under lock and changes the jOOQ type — treat it as
add-new-column + backfill + switch.

Anything that takes a heavy lock is safest behind `SET lock_timeout = '3s';` at the top of the
file: failing fast is better than a DDL lock queueing every query behind it.

## Never edit an applied migration

Flyway stores a checksum; editing a file that has run anywhere fails validation for everyone
(`CLAUDE.md` states this too). Fix forward with a new file. Locally, a bad migration is cheapest
to undo by recreating the database.

## After the migration

- **jOOQ**: if the change alters table shape, mirror it in `src/main/resources/db/jooq-schema.sql`
  and regenerate. Skipping this makes the generated classes disagree with the real schema.
- **Comments**: SQL can't express *why*, so a short header comment explaining the reason for the
  table or the backfill is worth it (`V189`, `V197`), and one line per non-obvious index naming
  the query it serves. No comments restating the DDL.

## Verify before calling it done

1. **Prove idempotency by applying the file twice** to a live database, not by eyeballing it:

   ```bash
   docker compose up -d postgres
   psql -h localhost -p 5435 -U postgres -d corebanking -f src/main/resources/db/migration/V<n>__<name>.sql
   psql -h localhost -p 5435 -U postgres -d corebanking -f src/main/resources/db/migration/V<n>__<name>.sql
   ```

   Both runs must exit 0, the second one changing nothing. (`PGPASSWORD=secret`, per `compose.yaml`.)
2. **Full history from scratch**: `./mvnw verify -DskipIntegrationTests=false` — Testcontainers
   replays every migration on an empty database, which catches ordering and syntax problems.
3. Re-read the file asking: would this break a pod running the *previous* release? If yes, split
   it into expand-now / contract-later.

## Related

- Repository query changes that follow a migration need two tests each: `tdd`.
- Comment discipline in the SQL header: `self-documenting-code`.
