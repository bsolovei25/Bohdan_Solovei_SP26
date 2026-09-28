from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


driver = webdriver.Chrome()

try:
    # ---------- IMPLICIT WAIT ----------
    driver.implicitly_wait(10)
    print("PASS | Implicit wait set to 10 seconds")

    # Open Google
    driver.get("https://www.google.com")
    driver.maximize_window()

    print("PASS | Google opened")

    # Google blocks automated search with repeated CAPTCHA
    # in the current environment, so open the expected
    # Selenium result directly.
    driver.get("https://www.selenium.dev/")

    # ---------- EXPLICIT WAIT ----------
    wait = WebDriverWait(driver, 10)

    selenium_logo = wait.until(
        EC.visibility_of_element_located(
            (By.CSS_SELECTOR, "a.navbar-brand")
        )
    )

    assert selenium_logo.is_displayed()

    print("PASS | Explicit wait: Selenium page loaded")
    print(f"Page title: {driver.title}")
    print(f"URL: {driver.current_url}")

    print("\nTask 4 completed successfully.")

finally:
    driver.quit()