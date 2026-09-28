@echo off
setlocal

if not exist .venv (
    py -m venv .venv
    if errorlevel 1 exit /b 1
)

call .venv\Scripts\activate
.venv\Scripts\python.exe -m pip install --upgrade pip
if errorlevel 1 exit /b 1
.venv\Scripts\python.exe -m pip install -r requirements.txt
if errorlevel 1 exit /b 1

if exist allure-results rmdir /s /q allure-results
.venv\Scripts\python.exe -m pytest --alluredir=allure-results
if errorlevel 1 exit /b 1

echo.
echo Test run finished. To open the report, run:
echo allure serve allure-results
endlocal
