---
name: oklch
description: Work with OKLCH colors for CSS and design tokens, including perceptual palette design, shade generation, gradient decisions, gamut and chroma checks, and conversions between OKLCH and other spaces (sRGB, Display-P3, OKLab, XYZ) using @texel/color. Use when a task mentions `oklch(...)`, color uniformity tuning, translating HEX/RGB/HSL to OKLCH, or converting OKLCH back to display-ready values.
---

# OKLCH Color Workflow

Use this skill to reason about color manually first, then convert precisely with `@texel/color`.

## Apply the Model Correctly

- Use `oklch(L C H)`.
- Treat `L` as perceived lightness (`0..1` or `0%..100%`).
- Treat `C` as chroma (intensity).
- Treat `H` as hue angle in degrees (`0..360`).
- Keep `L` fixed across multiple hues to keep UI colors visually balanced.
- Change `L` (not `H`) to build shade ramps with less hue drift.

## Handle Gamut and Chroma Safely

- Expect clipping when chroma is too high for the target gamut.
- Choose target intent before converting.
- Target `sRGB` for broad compatibility.
- Target `display-p3` for wide-gamut UIs when supported.
- Prefer gamut mapping over naive clipping for saturated OKLCH inputs.

## Convert Colors with `@texel/color`

Run this helper with plain Node. On first run, it auto-installs `@texel/color` into `~/.cache/oklch-skill/runtime`.

Convert from a CSS color string:

```bash
node /home/dennis/.agents/skills/oklch/scripts/texel-convert.mjs \
  --input "oklch(0.62 0.19 264)" --to srgb
```

Convert from explicit coordinates:

```bash
node /home/dennis/.agents/skills/oklch/scripts/texel-convert.mjs \
  --from srgb --coords "0.23,0.45,0.88" --to oklch
```

Apply gamut mapping from OKLCH to a target gamut/space:

```bash
node /home/dennis/.agents/skills/oklch/scripts/texel-convert.mjs \
  --input "oklch(0.7 0.4 40)" --to srgb --gamut srgb --mapping adaptive-cusp
```

List supported spaces from the installed package:

```bash
node /home/dennis/.agents/skills/oklch/scripts/texel-convert.mjs --list-spaces
```

## Use CSS Fallbacks When Needed

Use sRGB fallback first, then override with OKLCH behind feature support:

```css
:root {
  --brand-500: #4f46e5;
}

@supports (color: oklch(0 0 0)) {
  :root {
    --brand-500: oklch(0.62 0.19 264);
  }
}
```

## Diagnose Common Issues

- Lower `C` when converted RGB looks clipped or flat.
- Keep `L` aligned across semantic colors when one swatch looks brighter than peers.
- Switch gradient interpolation to OKLab when OKLCH hue wrapping creates unexpected midpoint colors.
- Serialize to target CSS format before shipping values into tokens.

## Resources

- Use [references/oklch-primer.md](./references/oklch-primer.md) for practical OKLCH heuristics and conversion notes.
- Use [scripts/texel-convert.mjs](./scripts/texel-convert.mjs) for command-line conversions and gamut mapping.
