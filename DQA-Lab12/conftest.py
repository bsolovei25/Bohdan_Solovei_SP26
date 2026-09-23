"""Shared fixtures for unit, integration, and Selenium UI tests."""

from pathlib import Path

import boto3
import pytest
import requests
import yaml
from botocore import UNSIGNED
from botocore.config import Config
from google.cloud import storage
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


ROOT = Path(__file__).resolve().parent


@pytest.fixture(scope="session")
def selenium_config():
    config_path = ROOT / "Configs" / "config_selenium.yaml"
    with config_path.open(encoding="utf-8") as config_file:
        return yaml.safe_load(config_file)["global"]


@pytest.fixture
def driver(selenium_config):
    options = Options()
    if selenium_config.get("headless", True):
        options.add_argument("--headless=new")
    options.add_argument("--window-size=1440,1000")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    browser = webdriver.Chrome(options=options)
    browser.set_page_load_timeout(60)
    yield browser
    browser.quit()


@pytest.fixture(scope="session")
def provide_config():
    return {
        "prefix": "2024/01/01/KTLX/",
        "gcp_bucket_name": "gcp-public-data-nexrad-l2",
        "aws_bucket_name": "unidata-nexrad-level2",
        "s3_anon_client": boto3.client(
            "s3", config=Config(signature_version=UNSIGNED)
        ),
        "gcp_storage_anon_client": storage.Client.create_anonymous_client(),
    }


@pytest.fixture(scope="session")
def list_gcs_blobs(provide_config):
    blobs = provide_config["gcp_storage_anon_client"].list_blobs(
        provide_config["gcp_bucket_name"], prefix=provide_config["prefix"]
    )
    return [blob.name for blob in blobs]


@pytest.fixture(scope="session")
def list_aws_blobs(provide_config):
    response = provide_config["s3_anon_client"].list_objects_v2(
        Bucket=provide_config["aws_bucket_name"],
        Prefix=provide_config["prefix"],
        MaxKeys=1000,
    )
    return [item["Key"] for item in response.get("Contents", [])]


@pytest.fixture(scope="session")
def provide_posts_data():
    response = requests.get(
        "https://jsonplaceholder.typicode.com/posts",
        params={"userId": 3},
        timeout=20,
    )
    response.raise_for_status()
    return response.json()
