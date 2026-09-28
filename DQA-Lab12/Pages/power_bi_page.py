"""Page Object Model for the Power BI Capture Report Views showcase."""

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


class PowerBICaptureViewsPage:
    """User actions and assertions exposed by the Capture Views page."""

    CAPTURE_VIEW_BUTTON = (By.ID, "capture-btn")
    SAVED_VIEWS_BUTTON = (By.ID, "display-btn")
    CAPTURE_MODAL = (By.ID, "modal-action")
    MODAL_TITLE = (By.ID, "my-modal-label")
    VIEW_NAME_INPUT = (By.ID, "viewname")
    SAVE_BUTTON = (By.ID, "save-bookmark-btn")
    VALIDATION_MESSAGE = (By.CSS_SELECTOR, "#save-view-div .invalid-feedback")

    def __init__(self, driver, timeout=20):
        self.driver = driver
        self.wait = WebDriverWait(driver, timeout)

    def open(self, url):
        self.driver.get(url)
        self.wait.until(EC.title_contains("Capture Report Views"))
        return self

    def capture_button_text(self):
        button = self.wait.until(
            EC.presence_of_element_located(self.CAPTURE_VIEW_BUTTON)
        )
        return button.get_attribute("textContent").strip()

    def saved_views_button_text(self):
        button = self.wait.until(
            EC.presence_of_element_located(self.SAVED_VIEWS_BUTTON)
        )
        return button.get_attribute("textContent").strip()

    def open_capture_dialog(self):
        button = self.wait.until(
            EC.presence_of_element_located(self.CAPTURE_VIEW_BUTTON)
        )
        self.driver.execute_script("arguments[0].click();", button)
        self.wait.until(
            lambda driver: "show" in driver.find_element(
                *self.CAPTURE_MODAL
            ).get_attribute("class")
        )
        return self

    def modal_title(self):
        return self.wait.until(
            EC.visibility_of_element_located(self.MODAL_TITLE)
        ).text.strip()

    def submit_empty_view_name(self):
        name_input = self.wait.until(
            EC.visibility_of_element_located(self.VIEW_NAME_INPUT)
        )
        name_input.clear()
        save_button = self.wait.until(
            EC.presence_of_element_located(self.SAVE_BUTTON)
        )
        self.driver.execute_script("arguments[0].click();", save_button)

    def validation_message(self):
        return self.wait.until(
            EC.visibility_of_element_located(self.VALIDATION_MESSAGE)
        ).text.strip()
