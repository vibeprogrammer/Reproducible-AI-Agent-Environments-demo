---
name: sql-migrations
description: Write and review PostgreSQL migrations for Meridian services. Use when a change adds or alters database tables.
---

# SQL migrations

1. Every migration is reversible: write the `down` step first.
2. Never rename a column in place; add, backfill, then drop.
3. Money columns are `bigint` minor units with a separate `currency char(3)`.
