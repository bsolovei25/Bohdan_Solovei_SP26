"""Pure validation helpers kept separate from network fixtures."""


def validate_post_count(posts, expected_count):
    return len(posts) == expected_count


def posts_belong_to_user(posts, user_id):
    return bool(posts) and all(post.get("userId") == user_id for post in posts)
