# Implementation Summary

- **High Contrast:** Darkened the primary accent from `#3b82f6` to `#1e40af` so links and buttons reach an 8.72:1 ratio against white backgrounds, satisfying WCAG 2.1 AAA for normal text (threshold 7:1). Contrast was measured with the WCAG relative luminance formula using a Python check (see below) to verify the ratio before updating the palette.

## Contrast Measurement Method

Contrast ratios were validated with the WCAG 2.1 relative luminance calculation using this Python snippet:

```bash
python - <<'PY'
import math

def srgb_to_linear(c):
    c /= 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

def luminance(rgb):
    r, g, b = rgb
    return 0.2126 * srgb_to_linear(r) + 0.7152 * srgb_to_linear(g) + 0.0722 * srgb_to_linear(b)

def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    L1, L2 = max(la, lb), min(la, lb)
    return (L1 + 0.05) / (L2 + 0.05)

primary = (0x1e, 0x40, 0xaf)  # #1e40af
white = (0xff, 0xff, 0xff)
print(contrast(primary, white))
PY
```

The script reports `8.72`, confirming the updated primary color meets the stated 7:1 target.
