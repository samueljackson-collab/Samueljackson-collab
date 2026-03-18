import { useEffect, useMemo, useState } from "react";
import axios from "axios";
import PhotoUpload from "../../components/photos/PhotoUpload";

type ViewMode = "grid" | "list";

type Photo = {
  filename: string;
  url: string;
};

const API_BASE =
  typeof import.meta !== "undefined" && import.meta.env?.VITE_API_URL
    ? import.meta.env.VITE_API_URL
    : "/api";

const PhotosPage = () => {
  const [viewMode, setViewMode] = useState<ViewMode>("grid");
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const fetchPhotos = async () => {
    try {
      const response = await axios.get<{ photos: Photo[] }>(`${API_BASE}/photos`);
      setPhotos(response.data.photos);
    } catch {
      setLoadError("Could not load photos. Please try again later.");
    }
  };

  useEffect(() => {
    fetchPhotos();
  }, []);

  const handleUploadSuccess = (url: string) => {
    setSuccessMessage("Photo uploaded successfully.");
    setPhotos((prev) => [{ filename: url.split("/").pop() ?? url, url }, ...prev]);
  };

  const dismissSuccessMessage = () => setSuccessMessage(null);

  const viewModeLabel = useMemo(
    () => (viewMode === "grid" ? "Grid view" : "List view"),
    [viewMode]
  );

  return (
    <div className="photos-page">
      <header className="photos-page__header">
        <h1>Photos</h1>
        <div className="photos-page__actions" aria-label="View mode controls">
          <button
            type="button"
            className={viewMode === "grid" ? "is-active" : ""}
            onClick={() => setViewMode("grid")}
          >
            Grid
          </button>
          <button
            type="button"
            className={viewMode === "list" ? "is-active" : ""}
            onClick={() => setViewMode("list")}
          >
            List
          </button>
        </div>
      </header>

      {successMessage && (
        <div className="photos-page__success" role="status" aria-live="polite">
          <span>{successMessage}</span>
          <button type="button" onClick={dismissSuccessMessage}>
            Dismiss
          </button>
        </div>
      )}

      {loadError && (
        <div className="photos-page__error" role="alert">
          {loadError}
        </div>
      )}

      <section
        className={`photos-page__gallery photos-page__gallery--${viewMode}`}
        aria-label={`Photo gallery — ${viewModeLabel}`}
      >
        {photos.length === 0 && !loadError && (
          <p>No photos yet. Upload your first photo below.</p>
        )}
        {photos.map((photo) => (
          <img
            key={photo.filename}
            src={`${API_BASE}${photo.url}`}
            alt={photo.filename}
            className="photos-page__photo"
          />
        ))}
      </section>

      <footer className="photos-page__footer">
        <PhotoUpload
          uploadUrl={`${API_BASE}/photos/upload`}
          onUploadSuccess={handleUploadSuccess}
          onUploadError={(msg) => setLoadError(msg)}
        />
      </footer>
    </div>
  );
};

export default PhotosPage;
