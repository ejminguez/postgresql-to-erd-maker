from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Column:
    name: str
    data_type: str
    is_primary_key: bool = False
    is_foreign_key: bool = False
    is_nullable: bool = True


@dataclass
class Relationship:
    source_table: str
    source_columns: list[str]
    target_table: str
    target_columns: list[str]
    constraint_name: Optional[str] = None


@dataclass
class Table:
    name: str
    columns: list[Column] = field(default_factory=list)
    relationships: list[Relationship] = field(default_factory=list)


@dataclass
class Schema:
    tables: dict[str, Table] = field(default_factory=dict)
