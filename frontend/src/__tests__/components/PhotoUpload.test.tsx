/**
 * Tests for src/components/photos/PhotoUpload.tsx
 *
 * Covers: rendering, file selection, loading state, success callback,
 * error callback, and loading state cleanup after completion.
 */
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import axios from 'axios';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import PhotoUpload from '../../components/photos/PhotoUpload';

vi.mock('axios');
const mockedAxios = vi.mocked(axios, true);

describe('PhotoUpload', () => {
  const uploadUrl = '/api/photos/upload';

  afterEach(() => {
    vi.resetAllMocks();
  });

  // -------------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------------

  it('renders a file input that accepts images', () => {
    render(<PhotoUpload uploadUrl={uploadUrl} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]');
    expect(fileInput).not.toBeNull();
    expect(fileInput?.accept).toBe('image/*');
  });

  it('does not show the uploading indicator initially', () => {
    render(<PhotoUpload uploadUrl={uploadUrl} />);
    expect(screen.queryByText(/uploading/i)).toBeNull();
  });

  // -------------------------------------------------------------------------
  // File selection → upload
  // -------------------------------------------------------------------------

  it('shows the uploading indicator while the request is in flight', async () => {
    let resolveUpload!: (value: unknown) => void;
    mockedAxios.post = vi.fn(
      () => new Promise((res) => { resolveUpload = res; }),
    ) as typeof axios.post;

    render(<PhotoUpload uploadUrl={uploadUrl} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]')!;

    const file = new File(['img-bytes'], 'photo.jpg', { type: 'image/jpeg' });
    await userEvent.upload(fileInput, file);

    expect(screen.getByText(/uploading/i)).toBeInTheDocument();

    // Resolve so we don't leak the pending promise
    resolveUpload({ data: { url: '' } });
  });

  it('calls onUploadSuccess with the returned URL on success', async () => {
    const onSuccess = vi.fn();
    mockedAxios.post = vi.fn().mockResolvedValue({
      data: { url: 'https://cdn.example.com/photo.jpg' },
    }) as typeof axios.post;

    render(<PhotoUpload uploadUrl={uploadUrl} onUploadSuccess={onSuccess} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]')!;

    await userEvent.upload(fileInput, new File(['img'], 'img.jpg', { type: 'image/jpeg' }));

    await waitFor(() => expect(onSuccess).toHaveBeenCalledWith('https://cdn.example.com/photo.jpg'));
  });

  it('calls onUploadError with the error message on network failure', async () => {
    const onError = vi.fn();
    const err = new Error('Network Error');
    // Make axios.isAxiosError return false so the generic path is taken
    mockedAxios.post = vi.fn().mockRejectedValue(err) as typeof axios.post;
    mockedAxios.isAxiosError = vi.fn().mockReturnValue(false) as typeof axios.isAxiosError;

    render(<PhotoUpload uploadUrl={uploadUrl} onUploadError={onError} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]')!;

    await userEvent.upload(fileInput, new File(['img'], 'img.jpg', { type: 'image/jpeg' }));

    await waitFor(() => expect(onError).toHaveBeenCalledWith('Network Error'));
  });

  it('calls onUploadError with the API detail message on axios error', async () => {
    const onError = vi.fn();
    const axiosErr = { response: { data: { detail: 'File too large' } }, message: 'Request failed' };
    mockedAxios.post = vi.fn().mockRejectedValue(axiosErr) as typeof axios.post;
    mockedAxios.isAxiosError = vi.fn().mockReturnValue(true) as typeof axios.isAxiosError;

    render(<PhotoUpload uploadUrl={uploadUrl} onUploadError={onError} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]')!;

    await userEvent.upload(fileInput, new File(['img'], 'img.jpg', { type: 'image/jpeg' }));

    await waitFor(() => expect(onError).toHaveBeenCalledWith('File too large'));
  });

  // -------------------------------------------------------------------------
  // Post-upload cleanup
  // -------------------------------------------------------------------------

  it('hides the uploading indicator after a successful upload', async () => {
    mockedAxios.post = vi.fn().mockResolvedValue({ data: { url: '' } }) as typeof axios.post;

    render(<PhotoUpload uploadUrl={uploadUrl} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]')!;

    await userEvent.upload(fileInput, new File(['img'], 'img.jpg', { type: 'image/jpeg' }));

    await waitFor(() => expect(screen.queryByText(/uploading/i)).toBeNull());
  });

  it('hides the uploading indicator after a failed upload', async () => {
    mockedAxios.post = vi.fn().mockRejectedValue(new Error('fail')) as typeof axios.post;
    mockedAxios.isAxiosError = vi.fn().mockReturnValue(false) as typeof axios.isAxiosError;

    render(<PhotoUpload uploadUrl={uploadUrl} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]')!;

    await userEvent.upload(fileInput, new File(['img'], 'img.jpg', { type: 'image/jpeg' }));

    await waitFor(() => expect(screen.queryByText(/uploading/i)).toBeNull());
  });

  it('re-enables the file input after upload completes', async () => {
    mockedAxios.post = vi.fn().mockResolvedValue({ data: { url: '' } }) as typeof axios.post;

    render(<PhotoUpload uploadUrl={uploadUrl} />);
    const fileInput = document.querySelector<HTMLInputElement>('input[type="file"]')!;

    await userEvent.upload(fileInput, new File(['img'], 'img.jpg', { type: 'image/jpeg' }));

    await waitFor(() => expect(fileInput.disabled).toBe(false));
  });
});
