# pg-schema-erd

`pg-schema-erd` converts a PostgreSQL schema SQL file into an entity relationship diagram and exports it as a PNG using Graphviz.

## Features

- Parses PostgreSQL `CREATE TABLE` statements
- Detects columns, data types, primary keys, and foreign keys
- Supports foreign keys declared:
  - inline on a column
  - as a table constraint
  - through `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY`
- Generates ERD nodes with:
  - entity name
  - attributes
  - attribute data types
  - relationship arrows
- Optionally saves the generated Graphviz DOT source

## Requirements

- Python 3.9 or later
- Graphviz installed and available on `PATH`

Check Graphviz:

```bash
dot -V
```

## Project Layout

```text
pg_schema_erd/
├── README.md
├── pyproject.toml
├── src/pg_schema_erd/
│   ├── __init__.py
│   ├── cli.py
│   ├── graphviz_renderer.py
│   ├── models.py
│   └── parser.py
└── tests/
    ├── test_graphviz_renderer.py
    └── test_parser.py
```

## Installation

Run directly from source:

```bash
cd /Users/errolminguez/pg_schema_erd
PYTHONPATH=src python3 -m pg_schema_erd.cli --help
```

Install in editable mode:

```bash
cd /Users/errolminguez/pg_schema_erd
python3 -m pip install -e .
```

After installation:

```bash
pg-schema-erd --help
```

## Usage

Basic usage:

```bash
cd /Users/errolminguez/pg_schema_erd
PYTHONPATH=src python3 -m pg_schema_erd.cli schema.sql --output erd.png
```

Using the installed CLI:

```bash
pg-schema-erd schema.sql --output erd.png
```

Generate both PNG and DOT files:

```bash
pg-schema-erd schema.sql --output erd.png --dot-output erd.dot
```

## CLI Arguments

```text
positional arguments:
  input                 Path to the PostgreSQL schema SQL file

optional arguments:
  --output, -o          Path to the output PNG file
  --dot-output          Optional path to write the generated DOT source
```

## Example

Input schema:

```sql
CREATE TABLE customers (
    id bigint PRIMARY KEY,
    email text NOT NULL
);

CREATE TABLE invoices (
    id bigint PRIMARY KEY,
    customer_id bigint NOT NULL,
    total numeric(10,2) NOT NULL,
    CONSTRAINT invoices_customer_id_fkey
        FOREIGN KEY (customer_id) REFERENCES customers(id)
);
```

Command:

```bash
pg-schema-erd schema.sql --output erd.png --dot-output erd.dot
```

Result:

- `erd.png` contains the rendered ERD
- `erd.dot` contains the intermediate Graphviz source

## ERD Output

Each entity is rendered as a table-like node with:

- entity name
- attribute names
- attribute data types
- `[PK]` markers for primary keys
- `[FK]` markers for foreign keys
- `[NN]` markers for non-null columns

Relationships are rendered as directed arrows from the referencing table to the referenced table.

## Supported SQL Patterns

This version is designed for schema-oriented PostgreSQL SQL files and supports:

- `CREATE TABLE ... (...)`
- schema-qualified table names such as `public.users`
- quoted identifiers
- inline `REFERENCES`
- table-level `PRIMARY KEY`
- table-level `FOREIGN KEY`
- `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY`

## Limitations

This is not a full PostgreSQL parser. You should expect gaps for advanced or unusual DDL, including:

- deeply vendor-specific syntax outside common PostgreSQL table definitions
- computed expressions that significantly alter column declaration shape
- relationship cardinality notation beyond directional foreign key arrows
- database objects outside tables and foreign key relationships

## Testing

Run the test suite:

```bash
cd /Users/errolminguez/pg_schema_erd
PYTHONPATH=src python3 -m unittest discover -s tests -v
```

The tests cover:

- schema parsing
- comment handling
- DOT generation
- PNG rendering through Graphviz
- failure handling when `dot` receives invalid graph input

## Development Notes

- The parser is implemented with targeted string and regex parsing rather than a full SQL grammar.
- Rendering is done by generating Graphviz DOT and invoking `dot -Tpng`.
- The implementation uses only the Python standard library.
