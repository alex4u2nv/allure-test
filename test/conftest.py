import allure
import pytest

def pytest_runtest_setup(item):
  allure.dynamic.parameter("system_version", "ABC 20.04", True)
  allure.dynamic.parameter("environment_name", "Staging", True)
