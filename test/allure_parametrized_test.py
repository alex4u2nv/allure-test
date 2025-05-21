import allure
import pytest


@pytest.mark.parametrize("test_param", ["First namex", "Second namex"],
                         ids=["first", "second"])
@allure.title("test_allure_parametrized_test -- [{test_param}]")
def test_allure_parametrized_test(test_param):
    with allure.step("Step inside parametrized test"):
        pass
    with allure.step(f"Test parameter: {test_param}"):
        pass


@pytest.fixture(params=["First fixture paramx", "Second fixture paramx"],
                ids=["first", "second"])
def parametrized_fixture(request):
    with allure.step(f"Fixture parameter: {request.param}"):
        pass


def test_allure_parametrized_fixture(parametrized_fixture):
    pass


@pytest.mark.parametrize("system_version, environment_name", [("Redhat 20.04",
                                                             "Prod")])
@allure.title("test_allure_parametrized_test -- [{environment_name}]")
def test_example(system_version, environment_name):
    with allure.step(f"Running on {system_version} in {environment_name} environment"):
        # Test logic here
        pass


def test_example_2():
    allure.dynamic.parameter("system_version", "22.04")
    with allure.step(
        f"Running on environment"):
        # Test logic here
        pass
