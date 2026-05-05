import unittest

from pg_schema_erd.parser import parse_schema


SQL = """
CREATE TABLE public.users (
    id bigserial PRIMARY KEY,
    email character varying(255) NOT NULL,
    role_id bigint REFERENCES public.roles(id)
);

CREATE TABLE public.roles (
    id bigint PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE orders (
    id bigint PRIMARY KEY,
    user_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);
"""


class ParseSchemaTests(unittest.TestCase):
    def test_parses_tables_columns_and_relationships(self) -> None:
        schema = parse_schema(SQL)

        self.assertEqual({"public.users", "public.roles", "orders"}, set(schema.tables))

        users = schema.tables["public.users"]
        self.assertEqual(
            [("id", "bigserial"), ("email", "character varying(255)"), ("role_id", "bigint")],
            [(column.name, column.data_type) for column in users.columns],
        )
        self.assertTrue(users.columns[0].is_primary_key)
        self.assertTrue(users.columns[2].is_foreign_key)
        self.assertEqual(2, len(users.relationships))

        orders = schema.tables["orders"]
        self.assertEqual("timestamp without time zone", orders.columns[2].data_type)
        self.assertFalse(orders.columns[1].is_nullable)
        self.assertEqual("public.users", orders.relationships[0].target_table)

    def test_ignores_sql_comments(self) -> None:
        schema = parse_schema(
            """
            -- comment
            CREATE TABLE things (
                id integer PRIMARY KEY /* inline */
            );
            """
        )
        self.assertIn("things", schema.tables)

    def test_ignores_non_foreign_key_table_constraints(self) -> None:
        schema = parse_schema(
            """
            CREATE TABLE growth_stage (
                id integer PRIMARY KEY,
                crop_id integer NOT NULL,
                stage_name text NOT NULL,
                stage_order integer NOT NULL,
                UNIQUE(crop_id, stage_name),
                UNIQUE(crop_id, stage_order),
                CHECK (stage_order > 0)
            );
            """
        )

        table = schema.tables["growth_stage"]
        self.assertEqual(
            ["id", "crop_id", "stage_name", "stage_order"],
            [column.name for column in table.columns],
        )


if __name__ == "__main__":
    unittest.main()
