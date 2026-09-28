"""Integration tests migrated from the previous API/cloud-storage module."""

import pytest


@pytest.mark.integration
def test_user_with_posts(provide_posts_data):
    assert len(provide_posts_data) == 10, (
        f"Expected 10 posts for user 3, found {len(provide_posts_data)}"
    )
    assert all(post["userId"] == 3 for post in provide_posts_data)


@pytest.mark.integration
def test_data_is_presented_between_staging_raw(list_gcs_blobs, list_aws_blobs):
    assert list_gcs_blobs, "No objects found in the GCP bucket for the date"
    assert list_aws_blobs, "No objects found in the AWS bucket for the date"
