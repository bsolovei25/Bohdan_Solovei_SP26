import pytest
import yaml


def get_numbers_data(config_name):
    with open(config_name, 'r') as stream:
        config = yaml.safe_load(stream)
    return config['cases']


def add_numbers(a, b, c):
    try:
        return a + b + c
    except TypeError:
        raise 'Please check the parameters. All of them must be numeric'

test_data = get_numbers_data("config.yaml")

@pytest.mark.smoke
@pytest.mark.parametrize(
    "a,b,c,expected",
    [
        (
            case["input"][0],
            case["input"][1],
            case["input"][2],
            case["expected"],
        )
        for case in test_data
    ],
    ids=[case["case_name"] for case in test_data],
)
def test_add_numbers(a, b, c, expected):
    result = add_numbers(a, b, c)
    assert result == expected


@pytest.mark.critical
def test_add_invalid_types():
    a, b, c = "a", 2, 1

    with pytest.raises(TypeError):
        add_numbers(a, b, c)