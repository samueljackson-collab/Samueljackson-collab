/**
 * Tests for src/components/elderly/LargeButton.tsx
 *
 * Covers: rendering, accessibility attributes, disabled state behaviour,
 * click handling, icon rendering, and WCAG compliance via jest-axe.
 */
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';
import { describe, expect, it, vi } from 'vitest';

import LargeButton from '../../components/elderly/LargeButton';

expect.extend(toHaveNoViolations);

describe('LargeButton', () => {
  // -------------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------------

  it('renders the label text', () => {
    render(<LargeButton label="Upload Photo" />);
    expect(screen.getByRole('button', { name: 'Upload Photo' })).toBeInTheDocument();
  });

  it('defaults to type="button" to avoid accidental form submission', () => {
    render(<LargeButton label="Save" />);
    expect(screen.getByRole('button')).toHaveAttribute('type', 'button');
  });

  it('accepts a custom type prop', () => {
    render(<LargeButton label="Submit" type="submit" />);
    expect(screen.getByRole('button')).toHaveAttribute('type', 'submit');
  });

  it('renders an icon alongside the label when provided', () => {
    const Icon = () => <svg data-testid="icon" aria-hidden="true" />;
    render(<LargeButton label="Add" icon={<Icon />} />);
    expect(screen.getByTestId('icon')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Add' })).toBeInTheDocument();
  });

  it('appends extra className to the button element', () => {
    render(<LargeButton label="Test" className="extra-class" />);
    expect(screen.getByRole('button')).toHaveClass('extra-class');
  });

  // -------------------------------------------------------------------------
  // Click handling
  // -------------------------------------------------------------------------

  it('fires the onClick handler when clicked', async () => {
    const onClick = vi.fn();
    render(<LargeButton label="Click me" onClick={onClick} />);
    await userEvent.click(screen.getByRole('button'));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('does not fire onClick when disabled', async () => {
    const onClick = vi.fn();
    render(<LargeButton label="Disabled" onClick={onClick} disabled />);
    await userEvent.click(screen.getByRole('button'));
    expect(onClick).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // Disabled state
  // -------------------------------------------------------------------------

  it('sets the HTML disabled attribute when disabled=true', () => {
    render(<LargeButton label="Disabled" disabled />);
    expect(screen.getByRole('button')).toBeDisabled();
  });

  it('sets aria-disabled="true" when disabled', () => {
    render(<LargeButton label="Disabled" disabled />);
    expect(screen.getByRole('button')).toHaveAttribute('aria-disabled', 'true');
  });

  it('sets aria-disabled="false" when not disabled', () => {
    render(<LargeButton label="Active" />);
    expect(screen.getByRole('button')).toHaveAttribute('aria-disabled', 'false');
  });

  it('is not disabled by default', () => {
    render(<LargeButton label="Active" />);
    expect(screen.getByRole('button')).not.toBeDisabled();
  });

  // -------------------------------------------------------------------------
  // Styling — accessibility classes documented
  // -------------------------------------------------------------------------

  it('includes high-contrast background colour classes (bg-blue-800)', () => {
    render(<LargeButton label="High contrast" />);
    expect(screen.getByRole('button').className).toContain('bg-blue-800');
  });

  it('includes focus-visible ring class for keyboard users', () => {
    render(<LargeButton label="Focus ring" />);
    expect(screen.getByRole('button').className).toContain('focus-visible:ring-4');
  });

  it('includes disabled opacity class', () => {
    render(<LargeButton label="Disabled style" disabled />);
    expect(screen.getByRole('button').className).toContain('disabled:opacity-60');
  });

  // -------------------------------------------------------------------------
  // WCAG Accessibility (jest-axe)
  // -------------------------------------------------------------------------

  it('has no accessibility violations in default state', async () => {
    const { container } = render(<LargeButton label="Accessible Button" />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations when disabled', async () => {
    const { container } = render(<LargeButton label="Disabled Button" disabled />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations when rendered with an icon', async () => {
    const Icon = () => <svg aria-hidden="true" />;
    const { container } = render(<LargeButton label="Icon Button" icon={<Icon />} />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
