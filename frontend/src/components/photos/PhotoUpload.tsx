import React, { useCallback } from 'react';

type PhotoUploadProps = {
  handleFiles: (files: FileList | null) => void | Promise<void>;
} & React.InputHTMLAttributes<HTMLInputElement>;

const PhotoUpload: React.FC<PhotoUploadProps> = ({ handleFiles, ...inputProps }) => {
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

  return <input type="file" onChange={onChange} {...inputProps} />;
};

export default PhotoUpload;
