import React, { useCallback } from 'react';

type PhotoUploadProps = {
  handleFiles: (files: FileList | null) => void | Promise<void>;
} & React.InputHTMLAttributes<HTMLInputElement>;

const PhotoUpload: React.FC<PhotoUploadProps> = ({ handleFiles, onChange: _ignored, ...inputProps }) => {
  const onChange = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      try {
        await handleFiles(e.currentTarget.files);
      } finally {
        // Clear the value so selecting the same file triggers onChange again
        e.currentTarget.value = '';
      }
    },
    [handleFiles]
  );

  return <input type="file" {...inputProps} onChange={onChange} />;
};

export default PhotoUpload;
