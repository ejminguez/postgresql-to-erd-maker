import html
import subprocess
from pathlib import Path
from typing import Union

from .models import Column, Relationship, Schema, Table


def schema_to_dot(schema: Schema) -> str:
    lines = [
        "digraph ERD {",
        '  graph [rankdir=LR, splines=true, pad="0.3"];',
        '  node [shape=plain, fontname="Helvetica"];',
        '  edge [fontname="Helvetica", arrowsize=0.8];',
    ]

    for table_name in sorted(schema.tables):
        lines.append(_table_to_dot(schema.tables[table_name]))

    for table_name in sorted(schema.tables):
        table = schema.tables[table_name]
        for relationship in table.relationships:
            lines.append(_relationship_to_dot(relationship))

    lines.append("}")
    return "\n".join(lines)


def render_png(dot_source: str, output_path: Union[str, Path]) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["dot", "-Tpng", "-o", str(output)],
        input=dot_source,
        text=True,
        capture_output=True,
        check=True,
    )
    return output


def _table_to_dot(table: Table) -> str:
    rows = [
        '<TR><TD COLSPAN="2" BGCOLOR="lightblue"><B>{}</B></TD></TR>'.format(_escape(table.name))
    ]
    rows.append('<TR><TD><B>Attribute</B></TD><TD><B>Type</B></TD></TR>')
    for column in table.columns:
        rows.append(_column_row(column))
    label = (
        '<<TABLE BORDER="1" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">{}</TABLE>>'.format("".join(rows))
    )
    return f'  "{table.name}" [label={label}];'


def _column_row(column: Column) -> str:
    name = column.name
    if column.is_primary_key:
        name += " [PK]"
    if column.is_foreign_key:
        name += " [FK]"
    if not column.is_nullable and not column.is_primary_key:
        name += " [NN]"
    return "<TR><TD ALIGN=\"LEFT\">{}</TD><TD ALIGN=\"LEFT\">{}</TD></TR>".format(
        _escape(name), _escape(column.data_type)
    )


def _relationship_to_dot(relationship: Relationship) -> str:
    label = "{} -> {}".format(
        ", ".join(relationship.source_columns),
        ", ".join(f"{relationship.target_table}.{col}" for col in relationship.target_columns),
    )
    return (
        f'  "{relationship.source_table}" -> "{relationship.target_table}" '
        f'[label="{_escape(label)}", arrowhead="normal"];'
    )


def _escape(value: str) -> str:
    return html.escape(value, quote=True)
