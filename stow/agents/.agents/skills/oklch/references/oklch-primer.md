# OKLCH Primer

## Core ideas from oklch.fyi

- Use OKLCH for perceptual uniformity: equal numeric moves tend to look like equal visual moves.
- Use fixed lightness across different hues to keep UI accents equally bright.
- Build ramps by changing lightness while keeping hue stable to reduce hue drift.
- Watch gradients in polar spaces: hue interpolation can take unexpected circular routes.
- Prefer OKLab interpolation for gradients when midpoint predictability matters.
- Respect gamut limits: some OKLCH values are mathematically valid but not displayable in sRGB or Display-P3.

## Practical ranges

- Lightness (`L`): `0..1` (or `0%..100%`)
- Hue (`H`): `0..360`
- Chroma (`C`): unbounded in theory, but high values may clip; many web workflows stay around `0..0.4`.

## Conversion with `@texel/color`

Use these APIs most often:

- `convert(coords, fromSpace, toSpace)` for direct conversion.
- `serialize(coords, inputSpace, outputSpace?)` for CSS-safe output strings.
- `deserialize(colorString)` for parsing `oklch()`, `oklab()`, `rgb()/rgba()`, hex, and simple `color(...)` strings.
- `gamutMapOKLCH(oklch, gamut, targetSpace, out, mapping)` for mapping saturated OKLCH values into a display gamut.

## Typical workflow

1. Parse incoming color string.
2. Convert into OKLCH when doing perceptual edits.
3. Edit lightness/chroma/hue according to visual intent.
4. Gamut-map if required for display targets.
5. Serialize to CSS format for tokens.

## References

- https://oklch.fyi/
- https://npmx.dev/package/%40texel/color
- https://texel-org.github.io/color/
