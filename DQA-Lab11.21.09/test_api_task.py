def test_user_with_posts(provide_posts_data):
    assert len(provide_posts_data) == 10, (
        f"Expected 10 posts for user 3, "
        f"but found {len(provide_posts_data)}"
    )


def test_data_is_presented_between_staging_raw(
    list_gcs_blobs,
    list_aws_blobs
):
    assert len(list_gcs_blobs) > 0, (
        "No objects were found in the GCP bucket "
        "for the specified date."
    )

    assert len(list_aws_blobs) > 0, (
        "No objects were found in the AWS bucket "
        "for the specified date."
    )