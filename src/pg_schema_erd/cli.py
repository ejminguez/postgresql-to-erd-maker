import argparse
from pathlib import Path

from .graphviz_renderer import render_png, schema_to_dot
from .parser import parse_schema


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert a PostgreSQL schema SQL file into an ERD PNG using Graphviz."
    )
    parser.add_argument("input", help="Path to the PostgreSQL schema SQL file.")
    parser.add_argument(
        "--output",
        "-o",
        default="erd.png",
        help="Path to the output PNG file. Default: erd.png",
    )
    parser.add_argument(
        "--dot-output",
        help="Optional path to also save the generated Graphviz DOT source.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    sql_text = Path(args.input).read_text(encoding="utf-8")
    schema = parse_schema(sql_text)
    dot_source = schema_to_dot(schema)

    if args.dot_output:
        Path(args.dot_output).write_text(dot_source, encoding="utf-8")

    render_png(dot_source, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
