/**
 * Tests for src/components/photos/PhotoCalendar.tsx
 *
 * Covers: rendering, photo count badge, date click handler,
 * empty state, and memoized photo lookup.
 */
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

// react-calendar renders a full interactive calendar; mock it for unit tests
// so tests are not dependent on its internal DOM structure.
vi.mock('react-calendar', () => ({
  default: ({
    onClickDay,
    tileContent,
  }: {
    onClickDay: (date: Date) => void;
    tileContent: ({ date }: { date: Date }) => React.ReactNode;
  }) => {
    const testDate = new Date('2024-03-15T00:00:00');
    return (
      <div>
        <button onClick={() => onClickDay(testDate)} data-testid="mock-day">
          15
        </button>
        <div data-testid="tile-content">{tileContent({ date: testDate })}</div>
      </div>
    );
  },
}));

import React from 'react';
import PhotoCalendar from '../../../components/photos/PhotoCalendar';

const MARCH_15: { date: string; photos: { id: string; url: string }[] } = {
  date: '2024-03-15',
  photos: [
    { id: '1', url: 'https://example.com/a.jpg' },
    { id: '2', url: 'https://example.com/b.jpg' },
  ],
};

describe('PhotoCalendar', () => {
  // -------------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------------

  it('renders without crashing when monthData is empty', () => {
    render(<PhotoCalendar monthData={[]} />);
    expect(screen.getByTestId('mock-day')).toBeInTheDocument();
  });

  it('renders without crashing when monthData has entries', () => {
    render(<PhotoCalendar monthData={[MARCH_15]} />);
    expect(screen.getByTestId('mock-day')).toBeInTheDocument();
  });

  // -------------------------------------------------------------------------
  // Photo count badge
  // -------------------------------------------------------------------------

  it('shows the correct photo count badge for a date with photos', () => {
    render(<PhotoCalendar monthData={[MARCH_15]} />);
    const tileContent = screen.getByTestId('tile-content');
    expect(tileContent.textContent).toBe('2');
  });

  it('renders no badge for a date with no photos', () => {
    render(<PhotoCalendar monthData={[]} />);
    const tileContent = screen.getByTestId('tile-content');
    expect(tileContent.textContent).toBe('');
  });

  // -------------------------------------------------------------------------
  // Click handler
  // -------------------------------------------------------------------------

  it('calls onSelectDate with the clicked date and associated photos', async () => {
    const onSelectDate = vi.fn();
    render(<PhotoCalendar monthData={[MARCH_15]} onSelectDate={onSelectDate} />);

    await userEvent.click(screen.getByTestId('mock-day'));

    expect(onSelectDate).toHaveBeenCalledOnce();
    const [calledDate, calledPhotos] = onSelectDate.mock.calls[0];
    expect(calledDate).toBeInstanceOf(Date);
    expect(calledPhotos).toHaveLength(2);
    expect(calledPhotos[0].id).toBe('1');
  });

  it('calls onSelectDate with an empty array when the date has no photos', async () => {
    const onSelectDate = vi.fn();
    render(<PhotoCalendar monthData={[]} onSelectDate={onSelectDate} />);

    await userEvent.click(screen.getByTestId('mock-day'));

    const [, calledPhotos] = onSelectDate.mock.calls[0];
    expect(calledPhotos).toEqual([]);
  });

  it('does not throw when onSelectDate is not provided', async () => {
    render(<PhotoCalendar monthData={[MARCH_15]} />);
    await userEvent.click(screen.getByTestId('mock-day'));
    // No assertion needed — just verifying no unhandled error
  });
});

// ---------------------------------------------------------------------------
// formatDateKey (internal utility — tested indirectly via the calendar mock)
// The mock always renders tileContent for 2024-03-15; data keyed with that
// date must produce a badge. Data keyed with a different date must not.
// ---------------------------------------------------------------------------

describe('formatDateKey (via tileContent)', () => {
  it('matches the YYYY-MM-DD key used in monthData', () => {
    // Data keyed for the mock date (2024-03-15) → badge should appear
    render(<PhotoCalendar monthData={[MARCH_15]} />);
    expect(screen.getByTestId('tile-content').textContent).toBe('2');
  });

  it('produces no badge when the key does not match the displayed date', () => {
    const differentDay = { date: '2024-03-16', photos: [{ id: 'y', url: 'https://example.com/y.jpg' }] };
    render(<PhotoCalendar monthData={[differentDay]} />);
    expect(screen.getByTestId('tile-content').textContent).toBe('');
  });
});
