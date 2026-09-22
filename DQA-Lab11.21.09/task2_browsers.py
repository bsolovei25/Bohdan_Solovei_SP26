from selenium import webdriver
from selenium.webdriver.firefox.service import Service as FirefoxService


def open_chrome():
    """Open Google in Chrome using automatic Selenium Manager."""
    driver = webdriver.Chrome()

    try:
        driver.get("https://www.google.com")
        print(f"Chrome page title: {driver.title}")
    finally:
        driver.quit()


def open_firefox():
    """Open Google in Firefox using a manually specified driver."""
    firefox_service = FirefoxService(
        executable_path=r"C:\WebDriver\geckodriver.exe"
    )

    driver = webdriver.Firefox(service=firefox_service)

    try:
        driver.get("https://www.google.com")
        print(f"Firefox page title: {driver.title}")
    finally:
        driver.quit()


if __name__ == "__main__":
    open_chrome()
    open_firefox()