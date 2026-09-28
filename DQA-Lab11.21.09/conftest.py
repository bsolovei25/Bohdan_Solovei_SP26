import boto3
import pytest
import requests

from botocore import UNSIGNED
from botocore.config import Config
from google.cloud import storage


@pytest.fixture
def provide_config():
    return {
        "prefix": "2024/01/01/KTLX/",
        "gcp_bucket_name": "gcp-public-data-nexrad-l2",
        "aws_bucket_name": "unidata-nexrad-level2",
        "s3_anon_client": boto3.client(
            "s3",
            config=Config(signature_version=UNSIGNED)
        ),
        "gcp_storage_anon_client":
            storage.Client.create_anonymous_client()
    }


@pytest.fixture
def list_gcs_blobs(provide_config):
    client = provide_config["gcp_storage_anon_client"]

    blobs = client.list_blobs(
        provide_config["gcp_bucket_name"],
        prefix=provide_config["prefix"]
    )

    return [blob.name for blob in blobs]

@pytest.fixture
def list_aws_blobs(provide_config):
    config = provide_config

    response = config["s3_anon_client"].list_objects(
        Bucket=config["aws_bucket_name"],
        Prefix=config["prefix"]
    )

    objects = [
        content["Key"]
        for content in response.get("Contents", [])
    ]

    return objects


@pytest.fixture
def provide_posts_data():
    response = requests.get(
        "https://jsonplaceholder.typicode.com/posts",
        params={"userId": 3},
        timeout=10
    )

    assert response.status_code == 200, (
        f"Expected status code 200, "
        f"but received {response.status_code}"
    )

    return response.json()