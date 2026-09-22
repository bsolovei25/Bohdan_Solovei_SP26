"""Fast unit tests for the API response validation logic."""

import pytest

from Utils.api_validation import posts_belong_to_user, validate_post_count


@pytest.mark.unit
def test_validate_post_count_accepts_ten_posts():
    posts = [{"id": number, "userId": 3} for number in range(1, 11)]
    assert validate_post_count(posts, expected_count=10)


@pytest.mark.unit
def test_posts_belong_to_requested_user():
    posts = [{"id": 1, "userId": 3}, {"id": 2, "userId": 3}]
    assert posts_belong_to_user(posts, user_id=3)
