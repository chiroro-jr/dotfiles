# DBML Reference

Use this file when exact syntax matters more than workflow guidance.

## Core Constructs

```dbml
Project shop {
  database_type: 'PostgreSQL'
  Note: 'Commerce schema'
}

Enum order_status {
  pending
  paid
  shipped
  cancelled
}

Table core.users {
  id uuid [pk, not null, default: `gen_random_uuid()`]
  email varchar(255) [not null, unique]
  created_at timestamp [not null, default: `now()`]
}
```

- Omit the schema prefix to target `public`.
- Use double quotes around identifiers or enum values only when they contain spaces or special characters.
- Types cannot contain spaces unless wrapped in double quotes, for example `"double precision"`.

## Column Settings

Use these settings inside `[]`:

- `pk` or `primary key`
- `null` or `not null`
- `unique`
- `default: ...`
- `increment`
- `check: `expression``
- `note: 'text'`

Default value rules:

- Numbers: `default: 123`
- Strings: `default: 'member'`
- Expressions: `default: `now()``
- Boolean or null: `default: false`, `default: null`

## Checks And Indexes

```dbml
Table bookings {
  id integer
  country varchar
  booking_date date
  created_at timestamp

  checks {
    `booking_date >= current_date - interval '365 days'` [name: 'chk_booking_date_window']
  }

  indexes {
    (id, country) [pk]
    created_at [name: 'idx_bookings_created_at']
    (country, booking_date) [unique]
    booking_date [type: hash]
    (`lower(country)`)
  }
}
```

- Use the `checks {}` block for multi-column constraints.
- Use `indexes {}` for composite primary keys, multi-column indexes, unique indexes, and expression indexes.
- Accepted index types in the docs are `btree` and `hash`.

## Relationships

DBML supports four operators:

- `<` one-to-many
- `>` many-to-one
- `-` one-to-one
- `<>` many-to-many

Three relationship forms are valid:

```dbml
Ref: posts.user_id > users.id

Ref user_owner {
  posts.user_id > users.id [delete: cascade, update: no action]
}

Table posts {
  id uuid [pk]
  user_id uuid [not null, ref: > users.id]
}
```

Key rules:

- In short and long `Ref` forms, the second column is treated as the foreign key for one-to-one relationships.
- In inline form, the column containing `[ref: ...]` is the foreign key.
- Nullable foreign keys affect zero-to-one or zero-to-many interpretation.
- Composite foreign keys use tuple syntax:

```dbml
Ref: merchant_periods.(merchant_id, country_code) > merchants.(id, country_code)
```

Prefer a real junction table over `<>` when the relationship needs extra columns such as `created_at`, `role`, or `quantity`.

## TablePartial

Use partials to reuse fields, indexes, and table settings:

```dbml
TablePartial audit_fields {
  id int [pk, not null]
  created_at timestamp [default: `now()`]
}

Table users {
  ~audit_fields
  email varchar [not null, unique]
}
```

Conflict precedence:

1. Local table definitions override partial content.
2. Between partials, the last injected partial wins.

Use partials for audit fields, soft-delete fields, tenant scoping, or repeated indexes. Avoid partials when they hide important domain distinctions.

## TableGroup, Notes, And Records

Use these features for documentation and visualization:

```dbml
TableGroup commerce [note: 'Checkout-related tables'] {
  users
  orders
}

Note release_note {
  'Renamed invoices to billing_documents in v2'
}

Table orders {
  id int [pk]
  status order_status

  records (id, status) {
    1, pending
    2, 'paid'
  }
}
```

Records rules:

- One `records` block per table.
- Outside-table records need an explicit column list.
- Inside-table records may omit the column list and then follow table column order.
- Strings use single quotes, expressions use backticks, enum values may use either `Enum.value` or a string literal.

## Tooling

CLI:

```bash
dbml2sql schema.dbml --postgres
sql2dbml schema.sql --postgres
db2dbml postgres '<connection-string>' -o schema.dbml
```

Node.js:

```js
const { Parser, exporter, importer } = require('@dbml/core')

const dbml = importer.import(sqlText, 'postgres')
const model = new Parser().parse(dbml, 'dbml')
const postgresSql = exporter.export(dbml, 'postgres')
```

Use `@dbml/core` when you need parsing or transformation in code. Use the CLI for fast local conversions.

## Common Pitfalls

- Reversing one-to-one foreign key direction.
- Using `<>` when a join table is actually required.
- Forgetting that omitted nullability defaults to nullable.
- Letting imported DBML keep noisy SQL-era names instead of normalizing them.
- Injecting partials before understanding conflict precedence.
- Overusing notes and groups when the real issue is unclear table design.
