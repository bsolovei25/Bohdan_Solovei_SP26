"""Two UI checks required for the Power BI Capture Report Views showcase."""

import pytest

from Pages.power_bi_page import PowerBICaptureViewsPage


@pytest.mark.ui
def test_capture_and_saved_views_controls_are_visible(driver, selenium_config):
    page = PowerBICaptureViewsPage(driver, selenium_config["delay"])
    page.open(selenium_config["report_uri"])

    assert page.capture_button_text() == "Capture view"
    assert page.saved_views_button_text() == "Saved views"


@pytest.mark.ui
def test_empty_view_name_displays_validation_message(driver, selenium_config):
    page = PowerBICaptureViewsPage(driver, selenium_config["delay"])
    page.open(selenium_config["report_uri"])
    page.open_capture_dialog()

    assert page.modal_title() == "What would you like to do with this view?"
    page.submit_empty_view_name()
    assert page.validation_message() == "Please provide a valid name"
