export PYTHONPATH=`pwd`
mkdir -p allure-results/history
mkdir -p saved-history
cp -r allure-report/history saved-history/

# Run pytest
pytest --alluredir=allure-results

# Restore history for the next run
cp -r saved-history/history allure-results/

# Generate the report
allure generate allure-results -o allure-report --clean

