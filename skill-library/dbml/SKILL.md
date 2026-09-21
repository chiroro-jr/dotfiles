---
name: dbml
description: Create, extend, review, and normalize database schemas written in DBML (Database Markup Language). Use when authoring or editing `.dbml` files, translating SQL schemas into DBML, documenting tables and relationships, or validating DBML constructs such as `Table`, `Ref`, `Enum`, `TablePartial`, `TableGroup`, `checks`, `indexes`, and `records`.
---

# DBML Schema

Author DBML that is readable first and SQL-faithful second. Prefer clear table names, explicit keys, and consistent relationship direction over clever compression.

## Workflow

1. Determine the job shape:
   - Create a new schema from requirements.
   - Refine an existing `.dbml` file.
   - Translate SQL or a live database into DBML, then normalize the result.
2. Model the core domain first:
   - Add `Project` metadata if it improves context.
   - Define `Enum` values before tables that use them.
   - Create tables with primary keys, nullability, unique constraints, defaults, checks, and indexes.
3. Add relationships deliberately:
   - Use inline `ref` only when the foreign key column is already obvious in that table.
   - Use short or long `Ref` form when relationships are cross-schema, composite, or easier to scan separately.
   - Be careful with one-to-one ordering because the foreign key side matters.
4. Reduce repetition only after the base schema is clear:
   - Use `TablePartial` for shared audit fields, soft-delete fields, or repeated indexes.
   - Use `TableGroup` and notes for documentation and visualization, not as a substitute for schema design.
5. Validate and round-trip:
   - If CLI or JS tooling is available, parse DBML and export SQL to catch structural mistakes early.
   - If the schema came from SQL, compare the normalized DBML back against the source intent.

## Authoring Rules

- Keep one concern per line: one column, one relationship, one enum value, one record row.
- Prefer explicit column settings like `[pk, not null]` over relying on assumptions.
- Quote identifiers with double quotes only when they contain spaces or special characters.
- Use single quotes for string literals and backticks for SQL expressions such as defaults or checks.
- Prefer true junction tables over `<>` when the many-to-many relationship needs attributes, audit fields, or direct SQL fidelity.
- Use `<>` only when the relationship is conceptual and no join-table payload is required.
- Inject `TablePartial` only after checking for field/index conflicts. Local table definitions win; otherwise the last injected partial wins.
- Use `records` only when sample data helps documentation, testing, or examples. Do not invent fake production-like data unless the user asked for samples.

## Default Shape

Start from this structure and remove sections you do not need:

```dbml
Project app {
  database_type: 'PostgreSQL'
  Note: 'Short description of the schema'
}

Enum user_role {
  admin
  member
}

TablePartial audit_fields {
  id uuid [pk, not null, default: `gen_random_uuid()`]
  created_at timestamp [not null, default: `now()`]
  updated_at timestamp [not null, default: `now()`]
}

Table users {
  ~audit_fields
  email varchar(255) [not null, unique]
  role user_role [not null, default: 'member']

  indexes {
    email [unique]
  }
}

Table posts {
  ~audit_fields
  user_id uuid [not null, ref: > users.id]
  title varchar(255) [not null]
  body text

  checks {
    `length(title) > 0` [name: 'chk_posts_title_not_empty']
  }
}
```

## Conversion And Validation

- Use the DBML CLI when you need fast round-trips:
  - `dbml2sql schema.dbml --postgres`
  - `sql2dbml schema.sql --postgres`
  - `db2dbml postgres '<connection-string>' -o schema.dbml`
- Use `@dbml/core` when the task needs parsing, transformation, or programmatic validation inside Node.js.
- After import from SQL or a live database, clean up naming, factor repeated columns into partials only if it improves clarity, and verify relationships/indexes were preserved.

## Resources

- Read [references/dbml-reference.md](./references/dbml-reference.md) when you need exact syntax, feature coverage, or reminders about edge cases such as composite foreign keys, records, or partial precedence.
