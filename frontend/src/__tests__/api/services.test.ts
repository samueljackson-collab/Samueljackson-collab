/**
 * Tests for src/api/services.ts
 *
 * Uses MSW (Mock Service Worker) to intercept HTTP requests so that no real
 * network traffic is generated.
 */
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { fetchImageObjectUrl, fetchSignedImageUrl } from '../../api/services';

// ---------------------------------------------------------------------------
// MSW server setup
//
// Use RegExp patterns so that multi-segment image paths (e.g.
// "photos/sunset.jpg") are matched correctly.  The signed-url handler must be
// registered BEFORE the blob handler so the more-specific route wins.
// ---------------------------------------------------------------------------

const server = setupServer(
  // Signed URL endpoint  — matches /api/images/<any-path>/signed-url
  http.get(/\/api\/images\/.+\/signed-url$/, () =>
    HttpResponse.json({ url: 'https://cdn.example.com/photo.jpg?sig=abc' }),
  ),
  // Blob (image data) endpoint — matches /api/images/<any-path>
  http.get(/\/api\/images\/.+/, () =>
    new HttpResponse(new Blob(['fake-image-data'], { type: 'image/jpeg' }), {
      headers: { 'Content-Type': 'image/jpeg' },
    }),
  ),
);

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// ---------------------------------------------------------------------------
// fetchSignedImageUrl
// ---------------------------------------------------------------------------

describe('fetchSignedImageUrl', () => {
  it('returns the signed URL from the backend response', async () => {
    const url = await fetchSignedImageUrl('photos/sunset.jpg');
    expect(url).toBe('https://cdn.example.com/photo.jpg?sig=abc');
  });

  it('encodes special characters in the image path', async () => {
    let capturedPathname = '';
    server.use(
      http.get(/\/api\/images\/.+\/signed-url$/, ({ request }) => {
        capturedPathname = new URL(request.url).pathname;
        return HttpResponse.json({ url: 'https://cdn.example.com/encoded.jpg' });
      }),
    );

    await fetchSignedImageUrl('my photos/file name.jpg');
    // Path segments should be URI-encoded
    expect(capturedPathname).toContain('my%20photos');
  });

  it('throws when the server responds with 401', async () => {
    server.use(
      http.get(/\/api\/images\/.+\/signed-url$/, () =>
        new HttpResponse(null, { status: 401 }),
      ),
    );

    await expect(fetchSignedImageUrl('secret.jpg')).rejects.toThrow();
  });

  it('throws when the server responds with 500', async () => {
    server.use(
      http.get(/\/api\/images\/.+\/signed-url$/, () =>
        new HttpResponse(null, { status: 500 }),
      ),
    );

    await expect(fetchSignedImageUrl('photo.jpg')).rejects.toThrow();
  });
});

// ---------------------------------------------------------------------------
// fetchImageObjectUrl
// ---------------------------------------------------------------------------

describe('fetchImageObjectUrl', () => {
  it('returns an objectUrl and a revoke function', async () => {
    const result = await fetchImageObjectUrl('photos/beach.jpg');
    expect(result).toHaveProperty('objectUrl');
    expect(result).toHaveProperty('revoke');
    expect(typeof result.revoke).toBe('function');
  });

  it('calls URL.createObjectURL to build the blob URL', async () => {
    const createSpy = vi.spyOn(URL, 'createObjectURL');
    await fetchImageObjectUrl('photos/beach.jpg');
    expect(createSpy).toHaveBeenCalledOnce();
  });

  it('revoke() calls URL.revokeObjectURL', async () => {
    const revokeSpy = vi.spyOn(URL, 'revokeObjectURL');
    const { revoke } = await fetchImageObjectUrl('photos/beach.jpg');
    revoke();
    expect(revokeSpy).toHaveBeenCalledOnce();
  });

  it('throws when the server responds with 404', async () => {
    server.use(
      http.get(/\/api\/images\/.+/, () =>
        new HttpResponse(null, { status: 404 }),
      ),
    );

    await expect(fetchImageObjectUrl('missing.jpg')).rejects.toThrow();
  });
});

// ---------------------------------------------------------------------------
// Auth token injection
// ---------------------------------------------------------------------------

describe('auth token injection', () => {
  beforeEach(() => localStorage.clear());

  it('adds Authorization header when a token is stored', async () => {
    localStorage.setItem('authToken', 'test-token-123');

    let capturedAuth = '';
    server.use(
      http.get(/\/api\/images\/.+\/signed-url$/, ({ request }) => {
        capturedAuth = request.headers.get('Authorization') ?? '';
        return HttpResponse.json({ url: 'https://cdn.example.com/photo.jpg' });
      }),
    );

    await fetchSignedImageUrl('photo.jpg');
    expect(capturedAuth).toBe('Bearer test-token-123');
  });

  it('omits Authorization header when no token is stored', async () => {
    let capturedAuth: string | null = 'present';
    server.use(
      http.get(/\/api\/images\/.+\/signed-url$/, ({ request }) => {
        capturedAuth = request.headers.get('Authorization');
        return HttpResponse.json({ url: 'https://cdn.example.com/photo.jpg' });
      }),
    );

    await fetchSignedImageUrl('photo.jpg');
    expect(capturedAuth).toBeNull();
  });
});
