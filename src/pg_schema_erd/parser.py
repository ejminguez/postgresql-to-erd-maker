import re
from typing import Optional

from .models import Column, Relationship, Schema, Table


CREATE_TABLE_RE = re.compile(
    r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?P<name>(?:\"[^\"]+\"|\w+)(?:\.(?:\"[^\"]+\"|\w+))?)\s*\((?P<body>.*)\)\s*$",
    re.IGNORECASE | re.DOTALL,
)

ALTER_TABLE_FK_RE = re.compile(
    r"ALTER\s+TABLE\s+(?:ONLY\s+)?(?P<table>(?:\"[^\"]+\"|\w+)(?:\.(?:\"[^\"]+\"|\w+))?)\s+ADD\s+(?:CONSTRAINT\s+(?P<constraint>(?:\"[^\"]+\"|\w+))\s+)?FOREIGN\s+KEY\s*\((?P<source>[^)]+)\)\s+REFERENCES\s+(?P<target_table>(?:\"[^\"]+\"|\w+)(?:\.(?:\"[^\"]+\"|\w+))?)\s*\((?P<target>[^)]+)\)",
    re.IGNORECASE | re.DOTALL,
)


def parse_schema(sql_text: str) -> Schema:
    schema = Schema()
    cleaned_sql = _remove_comments(sql_text)

    for statement in _split_sql_statements(cleaned_sql):
        statement = statement.strip()
        if not statement:
            continue
        create_match = CREATE_TABLE_RE.match(statement)
        if create_match:
            table = _parse_create_table(create_match.group("name"), create_match.group("body"))
            schema.tables[table.name] = table
            continue
        alter_match = ALTER_TABLE_FK_RE.match(statement)
        if alter_match:
            relationship = Relationship(
                source_table=_normalize_identifier(alter_match.group("table")),
                source_columns=_parse_column_list(alter_match.group("source")),
                target_table=_normalize_identifier(alter_match.group("target_table")),
                target_columns=_parse_column_list(alter_match.group("target")),
                constraint_name=_normalize_identifier(alter_match.group("constraint"))
                if alter_match.group("constraint")
                else None,
            )
            _attach_relationship(schema, relationship)
    return schema


def _parse_create_table(raw_name: str, body: str) -> Table:
    table = Table(name=_normalize_identifier(raw_name))
    primary_key_columns: set[str] = set()
    pending_relationships: list[Relationship] = []

    for part in _split_top_level(body, ","):
        definition = part.strip()
        if not definition:
            continue
        upper = definition.upper()
        if upper.startswith("CONSTRAINT "):
            constraint_body = definition.split(None, 2)[2]
            parsed = _parse_table_constraint(table.name, constraint_body)
        elif upper.startswith("PRIMARY KEY") or upper.startswith("FOREIGN KEY"):
            parsed = _parse_table_constraint(table.name, definition)
        else:
            column = _parse_column_definition(table.name, definition)
            table.columns.append(column)
            if column.is_primary_key:
                primary_key_columns.add(column.name)
            if column.is_foreign_key:
                inline_rel = _parse_inline_reference(table.name, definition, column.name)
                if inline_rel:
                    pending_relationships.append(inline_rel)
            continue

        if parsed is None:
            continue
        if parsed["type"] == "primary_key":
            primary_key_columns.update(parsed["columns"])
        elif parsed["type"] == "foreign_key":
            pending_relationships.append(parsed["relationship"])

    for column in table.columns:
        if column.name in primary_key_columns:
            column.is_primary_key = True

    for relationship in pending_relationships:
        for column in table.columns:
            if column.name in relationship.source_columns:
                column.is_foreign_key = True
        table.relationships.append(relationship)

    return table


def _parse_table_constraint(table_name: str, definition: str):
    primary_key_match = re.match(r"PRIMARY\s+KEY\s*\((?P<columns>[^)]+)\)", definition, re.IGNORECASE)
    if primary_key_match:
        return {"type": "primary_key", "columns": _parse_column_list(primary_key_match.group("columns"))}

    foreign_key_match = re.match(
        r"FOREIGN\s+KEY\s*\((?P<source>[^)]+)\)\s+REFERENCES\s+(?P<target_table>(?:\"[^\"]+\"|\w+)(?:\.(?:\"[^\"]+\"|\w+))?)\s*\((?P<target>[^)]+)\)",
        definition,
        re.IGNORECASE | re.DOTALL,
    )
    if foreign_key_match:
        relationship = Relationship(
            source_table=table_name,
            source_columns=_parse_column_list(foreign_key_match.group("source")),
            target_table=_normalize_identifier(foreign_key_match.group("target_table")),
            target_columns=_parse_column_list(foreign_key_match.group("target")),
        )
        return {"type": "foreign_key", "relationship": relationship}
    return None


def _parse_column_definition(table_name: str, definition: str) -> Column:
    tokens = _split_type_tokens(definition)
    if len(tokens) < 2:
        raise ValueError(f"Unable to parse column definition in {table_name}: {definition}")

    name = _normalize_identifier(tokens[0])
    type_tokens: list[str] = []
    constraint_started = False
    i = 1
    while i < len(tokens):
        token_upper = tokens[i].upper()
        next_upper = tokens[i + 1].upper() if i + 1 < len(tokens) else ""
        if token_upper in {"DEFAULT", "REFERENCES", "CHECK", "UNIQUE", "CONSTRAINT", "COLLATE", "GENERATED"}:
            constraint_started = True
        elif token_upper == "PRIMARY" and next_upper == "KEY":
            constraint_started = True
        elif token_upper == "NOT" and next_upper == "NULL":
            constraint_started = True
        elif token_upper == "NULL":
            constraint_started = True

        if constraint_started:
            break
        type_tokens.append(tokens[i])
        i += 1

    remainder = " ".join(tokens[i:])
    upper_remainder = remainder.upper()
    return Column(
        name=name,
        data_type=" ".join(type_tokens),
        is_primary_key="PRIMARY KEY" in upper_remainder,
        is_foreign_key="REFERENCES" in upper_remainder,
        is_nullable="NOT NULL" not in upper_remainder and "PRIMARY KEY" not in upper_remainder,
    )


def _parse_inline_reference(table_name: str, definition: str, column_name: str) -> Optional[Relationship]:
    match = re.search(
        r"REFERENCES\s+(?P<table>(?:\"[^\"]+\"|\w+)(?:\.(?:\"[^\"]+\"|\w+))?)\s*(?:\((?P<columns>[^)]+)\))?",
        definition,
        re.IGNORECASE,
    )
    if not match:
        return None
    target_columns = _parse_column_list(match.group("columns")) if match.group("columns") else ["id"]
    return Relationship(
        source_table=table_name,
        source_columns=[column_name],
        target_table=_normalize_identifier(match.group("table")),
        target_columns=target_columns,
    )


def _attach_relationship(schema: Schema, relationship: Relationship) -> None:
    table = schema.tables.get(relationship.source_table)
    if table is None:
        table = Table(name=relationship.source_table)
        schema.tables[table.name] = table
    for column in table.columns:
        if column.name in relationship.source_columns:
            column.is_foreign_key = True
    table.relationships.append(relationship)


def _remove_comments(sql_text: str) -> str:
    sql_text = re.sub(r"/\*.*?\*/", "", sql_text, flags=re.DOTALL)
    sql_text = re.sub(r"--.*?$", "", sql_text, flags=re.MULTILINE)
    return sql_text


def _split_sql_statements(sql_text: str) -> list[str]:
    return _split_top_level(sql_text, ";")


def _split_top_level(text: str, delimiter: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    paren_depth = 0
    in_single_quote = False
    in_double_quote = False

    for char in text:
        if char == "'" and not in_double_quote:
            in_single_quote = not in_single_quote
        elif char == '"' and not in_single_quote:
            in_double_quote = not in_double_quote
        elif not in_single_quote and not in_double_quote:
            if char == "(":
                paren_depth += 1
            elif char == ")":
                paren_depth = max(paren_depth - 1, 0)

        if char == delimiter and paren_depth == 0 and not in_single_quote and not in_double_quote:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)

    if current:
        parts.append("".join(current))
    return parts


def _split_type_tokens(definition: str) -> list[str]:
    tokens: list[str] = []
    current: list[str] = []
    paren_depth = 0
    for char in definition.strip():
        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth = max(paren_depth - 1, 0)

        if char.isspace() and paren_depth == 0:
            if current:
                tokens.append("".join(current))
                current = []
        else:
            current.append(char)
    if current:
        tokens.append("".join(current))
    return tokens


def _parse_column_list(raw_columns: str) -> list[str]:
    return [_normalize_identifier(part.strip()) for part in raw_columns.split(",") if part.strip()]


def _normalize_identifier(identifier: Optional[str]) -> str:
    if not identifier:
        return ""
    segments = [segment.strip().strip('"') for segment in identifier.strip().split(".")]
    return ".".join(segments)
