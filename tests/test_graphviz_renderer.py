import subprocess
import tempfile
import unittest
from pathlib import Path

from pg_schema_erd.graphviz_renderer import render_png, schema_to_dot
from pg_schema_erd.parser import parse_schema


class GraphvizRendererTests(unittest.TestCase):
    def test_generates_dot_with_entities_attributes_types_and_arrows(self) -> None:
        schema = parse_schema(
            """
            CREATE TABLE authors (
                id integer PRIMARY KEY,
                name text NOT NULL
            );

            CREATE TABLE books (
                id integer PRIMARY KEY,
                author_id integer REFERENCES authors(id),
                title text NOT NULL
            );
            """
        )

        dot = schema_to_dot(schema)

        self.assertIn('"authors" [label=<<TABLE', dot)
        self.assertIn("Attribute", dot)
        self.assertIn("Type", dot)
        self.assertIn("author_id [FK]", dot)
        self.assertIn('"books" -> "authors"', dot)
        self.assertIn('orientation=landscape', dot)
        self.assertIn('size="11.0,8.5!"', dot)
        self.assertIn('arrowhead="normal"', dot)

    def test_renders_png_file(self) -> None:
        schema = parse_schema(
            """
            CREATE TABLE items (
                id integer PRIMARY KEY,
                name text NOT NULL
            );
            """
        )
        dot = schema_to_dot(schema)

        with tempfile.TemporaryDirectory() as tmpdir:
            output = Path(tmpdir) / "erd.png"
            render_png(dot, output)
            self.assertTrue(output.exists())
            self.assertGreater(output.stat().st_size, 0)

    def test_raises_when_dot_fails(self) -> None:
        with self.assertRaises(subprocess.CalledProcessError):
            render_png("digraph { invalid", Path("broken.png"))


if __name__ == "__main__":
    unittest.main()
