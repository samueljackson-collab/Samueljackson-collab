"""Tests for the /images FastAPI endpoints.

These tests verify:
- GET /images/{image_path} returns 200 with the correct content-type for an
  existing image
- GET /images/{image_path} returns 404 for an image that does not exist
- GET /images/{image_path} rejects unsupported file extensions with 400
- GET /images/{image_path} rejects path traversal attempts with 400/403
- GET /images/{image_path}/signed-url returns a signed URL for an existing image
  and 404 for a nonexistent one
"""
from fastapi.testclient import TestClient

# A minimal valid 1x1 PNG, used to seed an "existing image" for retrieval tests.
TINY_PNG_BYTES = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000a49444154789c6360000002000154a24f5d0000000049454e44ae426082"
)


def _upload_photo(client: TestClient) -> str:
    """Upload a tiny PNG and return its stored filename (e.g. '<uuid>.png')."""
    response = client.post(
        "/photos/upload",
        files={"file": ("photo.png", TINY_PNG_BYTES, "image/png")},
    )
    assert response.status_code == 200
    url = response.json()["url"]
    return url.rsplit("/", 1)[-1]


class TestGetImage:
    def test_existing_image_returns_200_with_content_type(self, photos_client: TestClient):
        filename = _upload_photo(photos_client)

        response = photos_client.get(f"/images/{filename}")

        assert response.status_code == 200
        assert response.headers["content-type"] == "image/png"
        assert response.content  # non-empty body

    def test_nonexistent_image_returns_404(self, photos_client: TestClient):
        response = photos_client.get("/images/missing-file.png")

        assert response.status_code == 404
        assert response.json()["detail"] == "Image not found."

    def test_unsupported_extension_returns_400(self, photos_client: TestClient):
        response = photos_client.get("/images/script.exe")

        assert response.status_code == 400
        assert response.json()["detail"] == "Unsupported file type."

    def test_path_traversal_is_rejected(self, photos_client: TestClient):
        response = photos_client.get("/images/..%2F..%2Fetc%2Fpasswd")

        # Either rejected outright (400 - bad/unsupported path) or, if somehow
        # resolved, must never escape the upload directory (403). It must
        # never succeed with a 200.
        assert response.status_code in (400, 403, 404)


class TestGetSignedImageUrl:
    def test_existing_image_returns_signed_url(self, photos_client: TestClient):
        filename = _upload_photo(photos_client)

        response = photos_client.get(f"/images/{filename}/signed-url")

        assert response.status_code == 200
        body = response.json()
        assert "url" in body
        assert body["url"].startswith(f"/images/{filename}")
        assert "token=" in body["url"]

    def test_nonexistent_image_returns_404(self, photos_client: TestClient):
        response = photos_client.get("/images/missing-file.png/signed-url")

        assert response.status_code == 404
        assert response.json()["detail"] == "Image not found."
