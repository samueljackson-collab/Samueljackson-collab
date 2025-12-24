import axios, { AxiosInstance } from 'axios';

type ImageUrlResponse = {
  url: string;
};

const apiClient: AxiosInstance = axios.create({
  baseURL: typeof import.meta !== 'undefined' && import.meta.env?.VITE_API_URL ? import.meta.env.VITE_API_URL : '/api',
  withCredentials: true,
});

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('authToken');

  if (token) {
    config.headers.Authorization = `Bearer ${token}`;

  }

  return config;
});

const encodePath = (imagePath: string): string => {
  const normalized = imagePath.startsWith('/') ? imagePath.slice(1) : imagePath;
  return normalized
    .split('/')
    .filter(Boolean)
    .map(encodeURIComponent)
    .join('/');
};

/**
 * Retrieve a backend-generated signed URL for an image. Prefer this when the backend supports
 * expiring URLs so that <img> tags never point to public/bare resources.
 */
export const fetchSignedImageUrl = async (imagePath: string): Promise<string> => {
  const response = await apiClient.get<ImageUrlResponse>(`/images/${encodePath(imagePath)}/signed-url`);
  return response.data.url;
};

/**
 * Fetch an image through the authenticated client and expose it as an object URL for rendering.
 * This ensures Authorization headers accompany the request instead of embedding a bare URL in <img> tags.
 */
export const fetchImageObjectUrl = async (
  imagePath: string,
): Promise<{ objectUrl: string; revoke: () => void }> => {
  const response = await apiClient.get<Blob>(`/images/${encodePath(imagePath)}`, {
    responseType: 'blob',
  });

  const objectUrl = URL.createObjectURL(response.data);
  const revoke = () => URL.revokeObjectURL(objectUrl);

  return { objectUrl, revoke };
};
