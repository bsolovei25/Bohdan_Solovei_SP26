from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.relative_locator import locate_with


def check_locator(driver, locator_type, locator_value, description):
    """Find one element and print the result."""
    elements = driver.find_elements(locator_type, locator_value)

    assert len(elements) == 1, (
        f"{description}: expected exactly 1 element, "
        f"but found {len(elements)}"
    )

    print(f"PASS | {description} | exactly 1 element found")
    return elements[0]


driver = webdriver.Chrome()

try:
    driver.get("https://phptravels.com/demo")
    driver.maximize_window()

    print("\n--- CLASS NAME LOCATORS ---")

    check_locator(
        driver,
        By.CLASS_NAME,
        "first_name",
        "CLASS_NAME: First Name input"
    )

    check_locator(
        driver,
        By.CLASS_NAME,
        "last_name",
        "CLASS_NAME: Last Name input"
    )

    print("\n--- ID LOCATORS ---")

    check_locator(
        driver,
        By.ID,
        "demo",
        "ID: Access Live Demo button"
    )

    check_locator(
        driver,
        By.ID,
        "number",
        "ID: Math captcha input"
    )

    print("\n--- CSS SELECTOR LOCATORS ---")

    check_locator(
        driver,
        By.CSS_SELECTOR,
        "input.company_name",
        "CSS: Business Name input"
    )

    check_locator(
        driver,
        By.CSS_SELECTOR,
        "input.email[type='email']",
        "CSS: Email input"
    )

    print("\n--- XPATH LOCATORS ---")

    check_locator(
        driver,
        By.XPATH,
        "//input[@placeholder='Enter WhatsApp number']",
        "XPATH: WhatsApp Number input"
    )

    check_locator(
        driver,
        By.XPATH,
        "//button[@id='demo']/span[text()='Access Live Demo']",
        "XPATH: Access Live Demo text"
    )

    print("\nAll Demo page locators passed.")

    print("\n--- NAME LOCATORS ---")

    driver.get("https://phptravels.org/register.php")

    check_locator(
        driver,
        By.NAME,
        "firstname",
        "NAME: First Name input"
    )

    check_locator(
        driver,
        By.NAME,
        "lastname",
        "NAME: Last Name input"
    )



    print("\nAll 10 required locators passed.")

    print("\n--- RELATIVE LOCATORS ---")

    first_name = driver.find_element(By.ID, "inputFirstName")

    # 1. Find Last Name input to the right of First Name
    relative_last_name = driver.find_element(
        locate_with(By.TAG_NAME, "input").to_right_of(first_name)
    )

    assert relative_last_name.get_attribute("id") == "inputLastName"
    print(
        "PASS | RELATIVE: Last Name to the right of First Name "
        "| correct element found"
    )

    # 2. Find Email input below First Name
    relative_email = driver.find_element(
        locate_with(By.TAG_NAME, "input").below(first_name)
    )

    assert relative_email.get_attribute("id") == "inputEmail"
    print(
        "PASS | RELATIVE: Email below First Name "
        "| correct element found"
    )

    print("\nAll 12 Task 3 locators passed.")


finally:
    driver.quit()