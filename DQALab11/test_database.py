import allure
import pytest
import yaml


def load_tests(config_file, test_type):
    with open(config_file, "r") as stream:
        config = yaml.safe_load(stream)
    return config[test_type]


smoke_tests = load_tests("config_sql.yaml", "smoke_tests")
critical_tests = load_tests("config_sql.yaml", "critical_tests")


@pytest.mark.smoke
@pytest.mark.parametrize(
    "test_case",
    smoke_tests,
    ids=[test["name"] for test in smoke_tests],
)
def test_smoke_database(db_cursor, test_case):
    with allure.step(f"Execute SQL: {test_case['name']}"):
        db_cursor.execute(test_case["sql"])
        actual_result = db_cursor.fetchone()[0]

    with allure.step(
        f"Compare actual result {actual_result} "
        f"with expected result {test_case['expected']}"
    ):
        assert actual_result == test_case["expected"], (
            f"{test_case['name']} failed: "
            f"expected {test_case['expected']}, "
            f"got {actual_result}"
        )


@pytest.mark.critical
@pytest.mark.parametrize(
    "test_case",
    critical_tests,
    ids=[test["name"] for test in critical_tests],
)
def test_critical_database(db_cursor, test_case):
    with allure.step(f"Execute SQL: {test_case['name']}"):
        db_cursor.execute(test_case["sql"])
        actual_result = db_cursor.fetchone()[0]

    with allure.step(
        f"Compare actual result {actual_result} "
        f"with expected result {test_case['expected']}"
    ):
        assert actual_result == test_case["expected"], (
            f"{test_case['name']} failed: "
            f"expected {test_case['expected']}, "
            f"got {actual_result}"
        )