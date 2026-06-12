"""Tests for the /photos FastAPI endpoints.

These tests verify:
- POST /photos/upload accepts a valid image and stores it under UPLOAD_DIR
- POST /photos/upload rejects oversized files with 413
- POST /photos/upload rejects files that are not recognised image formats with 400
- GET /photos lists previously uploaded photos
- GET /images/{filename} returns 404 for a photo id/filename that does not exist
"""
from fastapi.testclient import TestClient

# A minimal valid 1x1 PNG, used as a "small image file" for upload tests.
TINY_PNG_BYTES = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000a49444154789c6360000002000154a24f5d0000000049454e44ae426082"
)

MAX_UPLOAD_BYTES = 20 * 1024 * 1024


class TestUploadPhoto:
    def test_upload_valid_png_returns_200_with_url(self, photos_client: TestClient):
        response = photos_client.post(
            "/photos/upload",
            files={"file": ("photo.png", TINY_PNG_BYTES, "image/png")},
        )

        assert response.status_code == 200
        body = response.json()
        assert "url" in body
        assert body["url"].startswith("/images/")
        assert body["url"].endswith(".png")

    def test_upload_oversized_file_returns_413(self, photos_client: TestClient):
        oversized = b"\x00" * (MAX_UPLOAD_BYTES + 1)

        response = photos_client.post(
            "/photos/upload",
            files={"file": ("huge.bin", oversized, "application/octet-stream")},
        )

        assert response.status_code == 413
        assert "20 MB" in response.json()["detail"]

    def test_upload_invalid_content_returns_400(self, photos_client: TestClient):
        response = photos_client.post(
            "/photos/upload",
            files={"file": ("notes.txt", b"this is not an image", "text/plain")},
        )

        assert response.status_code == 400
        assert "image format" in response.json()["detail"]


class TestListPhotos:
    def test_list_includes_uploaded_photo(self, photos_client: TestClient):
        upload_response = photos_client.post(
            "/photos/upload",
            files={"file": ("photo.png", TINY_PNG_BYTES, "image/png")},
        )
        uploaded_url = upload_response.json()["url"]
        uploaded_filename = uploaded_url.rsplit("/", 1)[-1]

        list_response = photos_client.get("/photos")

        assert list_response.status_code == 200
        body = list_response.json()
        assert "photos" in body
        filenames = [photo["filename"] for photo in body["photos"]]
        urls = [photo["url"] for photo in body["photos"]]
        assert uploaded_filename in filenames
        assert uploaded_url in urls

    def test_list_returns_empty_when_no_photos(self, photos_client: TestClient):
        response = photos_client.get("/photos")

        assert response.status_code == 200
        assert response.json() == {"photos": []}


class TestRetrievePhoto:
    def test_retrieve_nonexistent_photo_returns_404(self, photos_client: TestClient):
        response = photos_client.get("/images/does-not-exist.png")

        assert response.status_code == 404
        assert response.json()["detail"] == "Image not found."
