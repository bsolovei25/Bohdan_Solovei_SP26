import pytest
import psycopg2


@pytest.fixture(scope="session")
def db_cursor():
    connection = psycopg2.connect(
        database="dwh_hw_db",
        user="postgres",
        password="admin",
        host="localhost",
        port="5432",
    )

    cursor = connection.cursor()

    yield cursor

    cursor.close()
    connection.close()