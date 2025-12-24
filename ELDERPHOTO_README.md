# ElderPhoto Product Page

This document outlines the design notes for the ElderPhoto product landing page, including accessibility assurances for the primary brand color.

## Accessibility
- **Primary color:** `#0D47A1` (deep blue)
- **Text contrast:** White text (`#FFFFFF`) on the primary color background measures **8.63:1**, exceeding the WCAG AAA 7:1 requirement for normal text.
- **Usage guidance:** Apply the primary color for key calls-to-action and navigational accents, with body text set to a near-black (`#0A0A0A`) for readability on light surfaces. Avoid pairing the primary color with black text to preserve contrast compliance.

## Implementation
The primary color is expressed as a CSS variable and applied to primary buttons. Keep text on these elements white to maintain the measured 8.63:1 contrast ratio.

```css
:root {
  --primary-color: #0D47A1;
  --text-color: #0A0A0A;
}

body {
  color: var(--text-color);
  background-color: #FFFFFF;
  font-family: "Inter", system-ui, -apple-system, sans-serif;
}

.btn-primary {
  background-color: var(--primary-color);
  color: #FFFFFF;
  border: 0;
  padding: 0.75rem 1.25rem;
  border-radius: 0.5rem;
}
```
