import React, { useState } from "react";
import axios from "axios";

interface PhotoUploadProps {
  uploadUrl: string;
  onUploadSuccess?: (url: string) => void;
  onUploadError?: (message: string) => void;
}

const PhotoUpload: React.FC<PhotoUploadProps> = ({ uploadUrl, onUploadSuccess, onUploadError }) => {
  const [isUploading, setIsUploading] = useState(false);

  const handleUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append("file", file);

    setIsUploading(true);
    try {
      const response = await axios.post(uploadUrl, formData, {
        headers: { "Content-Type": "multipart/form-data" },
      });
      const uploadedUrl: string = response.data?.url ?? "";
      onUploadSuccess?.(uploadedUrl);
    } catch (error) {
      const specificMessage = axios.isAxiosError<{ detail?: string }>(error)
        ? error.response?.data?.detail ?? error.message
        : (error as Error).message;
      onUploadError?.(specificMessage);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div>
      <input type="file" accept="image/*" onChange={handleUpload} disabled={isUploading} />
      {isUploading && <p>Uploading...</p>}
    </div>
  );
};

export default PhotoUpload;
