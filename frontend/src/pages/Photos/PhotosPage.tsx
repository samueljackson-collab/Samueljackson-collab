import { useMemo, useState } from "react";

type ViewMode = "grid" | "list";

const PhotosPage = () => {
  const [viewMode, setViewMode] = useState<ViewMode>("grid");
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const handleUploadComplete = () => {
    setSuccessMessage("Photos uploaded successfully.");
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
        <div className="photos-page__success" role="status">
          <span>{successMessage}</span>
          <button type="button" onClick={dismissSuccessMessage}>
            Dismiss
          </button>
        </div>
      )}

      <section className={`photos-page__gallery photos-page__gallery--${viewMode}`}>
        <p>Currently showing photos in {viewModeLabel}.</p>
      </section>

      <footer className="photos-page__footer">
        <button type="button" onClick={handleUploadComplete}>
          Simulate Upload Complete
        </button>
      </footer>
    </div>
  );
};

export default PhotosPage;
