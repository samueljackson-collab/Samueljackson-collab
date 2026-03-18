/**
 * Tests for src/components/elderly/SidebarNav.tsx
 *
 * Covers: rendering, link/span distinction, nested item indentation,
 * deep nesting fallback, and WCAG compliance via jest-axe.
 */
import { render, screen } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { describe, expect, it } from 'vitest';

import SidebarNav, { type SidebarNavItem } from '../../components/elderly/SidebarNav';

expect.extend(toHaveNoViolations);

const FLAT_ITEMS: SidebarNavItem[] = [
  { label: 'Photos', href: '/photos' },
  { label: 'Calendar', href: '/calendar' },
  { label: 'Settings', href: '/settings' },
];

const NESTED_ITEMS: SidebarNavItem[] = [
  {
    label: 'Library',
    href: '/library',
    children: [
      { label: 'Albums', href: '/library/albums' },
      { label: 'Favourites', href: '/library/favourites' },
    ],
  },
  { label: 'Backup', href: '/backup' },
];

const DEEP_ITEMS: SidebarNavItem[] = [
  {
    label: 'L0',
    children: [
      {
        label: 'L1',
        children: [
          {
            label: 'L2',
            children: [
              {
                label: 'L3',
                children: [
                  {
                    label: 'L4',
                    children: [{ label: 'L5', href: '/deep' }],
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  },
];

describe('SidebarNav', () => {
  // -------------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------------

  it('renders a <nav> element with an accessible label', () => {
    render(<SidebarNav items={FLAT_ITEMS} />);
    expect(screen.getByRole('navigation', { name: /sidebar navigation/i })).toBeInTheDocument();
  });

  it('renders all top-level items', () => {
    render(<SidebarNav items={FLAT_ITEMS} />);
    expect(screen.getByRole('link', { name: 'Photos' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Calendar' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Settings' })).toBeInTheDocument();
  });

  it('renders an empty list without crashing', () => {
    render(<SidebarNav items={[]} />);
    expect(screen.getByRole('navigation')).toBeInTheDocument();
  });

  // -------------------------------------------------------------------------
  // Link vs. span
  // -------------------------------------------------------------------------

  it('renders an <a> element for items with an href', () => {
    render(<SidebarNav items={[{ label: 'Photos', href: '/photos' }]} />);
    const link = screen.getByRole('link', { name: 'Photos' });
    expect(link).toHaveAttribute('href', '/photos');
  });

  it('renders a <span> (not a link) for items without an href', () => {
    render(<SidebarNav items={[{ label: 'Section Header' }]} />);
    expect(screen.queryByRole('link', { name: 'Section Header' })).toBeNull();
    expect(screen.getByText('Section Header').tagName).toBe('SPAN');
  });

  // -------------------------------------------------------------------------
  // Nesting
  // -------------------------------------------------------------------------

  it('renders nested child items', () => {
    render(<SidebarNav items={NESTED_ITEMS} />);
    expect(screen.getByRole('link', { name: 'Albums' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Favourites' })).toBeInTheDocument();
  });

  it('applies pl-4 (level 0) indentation class to top-level items', () => {
    render(<SidebarNav items={FLAT_ITEMS} />);
    const photoLink = screen.getByRole('link', { name: 'Photos' });
    expect(photoLink.closest('li')).toHaveClass('pl-4');
  });

  it('applies pl-8 (level 1) indentation class to first-level children', () => {
    render(<SidebarNav items={NESTED_ITEMS} />);
    const albumsLink = screen.getByRole('link', { name: 'Albums' });
    expect(albumsLink.closest('li')).toHaveClass('pl-8');
  });

  // -------------------------------------------------------------------------
  // Deep nesting — fallback inline style
  // -------------------------------------------------------------------------

  it('applies inline paddingLeft style for levels beyond the predefined map (level 5)', () => {
    render(<SidebarNav items={DEEP_ITEMS} />);
    const deepLink = screen.getByRole('link', { name: 'L5' });
    const li = deepLink.closest('li')!;
    // Level 5 is beyond INDENTATION_CLASSES (max key = 4), so style is used
    expect(li.style.paddingLeft).toBeTruthy();
  });

  // -------------------------------------------------------------------------
  // WCAG Accessibility (jest-axe)
  // -------------------------------------------------------------------------

  it('has no accessibility violations with flat items', async () => {
    const { container } = render(<SidebarNav items={FLAT_ITEMS} />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations with nested items', async () => {
    const { container } = render(<SidebarNav items={NESTED_ITEMS} />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations with an empty list', async () => {
    const { container } = render(<SidebarNav items={[]} />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
