# DQE Task 13 Pytest and Selenium Framework

This framework integrates the earlier API and cloud-storage tests with unit
tests and two Selenium checks for the Power BI **Capture Report Views** showcase.

## Setup

```bash
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
```

Chrome must be installed. Selenium Manager obtains a compatible driver.

## Run tests

```bash
pytest -m unit
pytest -m integration
pytest -m ui
pytest --alluredir=allure-results
allure serve allure-results
```

On Windows, the simplest complete run is:

```powershell
.\run_all_tests.bat
allure serve allure-results
```

Set `headless: false` in `Configs/config_selenium.yaml` to watch UI execution.
Integration and UI tests require internet access.
