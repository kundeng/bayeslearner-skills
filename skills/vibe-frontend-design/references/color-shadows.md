# Color Systems and Shadow Rules for Screen-Based UI Design

> Sourced from: `ref1.txt` (UI Design Fundamentals Course)  
> Sections covered: REF 00:00–04:14:25

---

## Table of Contents

1. [Safe Starter Palette](#1-safe-starter-palette)
2. [Accent-Derived HSL Palette System](#2-accent-derived-hsl-palette-system)
3. [Text and Label Colors](#3-text-and-label-colors)
4. [Secondary Accent Color](#4-secondary-accent-color)
5. [Validation State Colors](#5-validation-state-colors)
6. [Special Color Treatments](#6-special-color-treatments)
7. [Shadow Ratio Formula](#7-shadow-ratio-formula)
8. [Card Shadows](#8-card-shadows)
9. [Button Shadows](#9-button-shadows)
10. [Logo and Text Shadows](#10-logo-and-text-shadows)
11. [Map UI Depth Strategy](#11-map-ui-depth-strategy)
12. [Gradient Rules](#12-gradient-rules)
13. [Corner Radii](#13-corner-radii)
14. [Nested Radius Rule](#14-nested-radius-rule)
15. [Icon Consistency](#15-icon-consistency)

---

## 1. Safe Starter Palette

**Reference:** REF 10:12–10:47

| Element | Rule |
|---|---|
| Accent | 1 accent color (example: blue) |
| Background | white |
| Text | very dark gray with a hint of the accent |
| Expansion | Start with 3 colors; add second accent only after mastering first |
| Spectrum | Stay roughly in the middle **70–80%** of the color spectrum before experimenting at extremes |

### Clashing Warning
Avoid combinations like:
- red next to green
- red next to blue

when edges appear visually fuzzy or jarring.

---

## 2. Accent-Derived HSL Palette System

**Reference:** REF 41:01–43:34, 56:16

Starting from accent color $C$ in HSL:

$$
C = (H, S, L)
$$

### Palette Derivation

| Use | Formula | Example Values |
|---|---|---|
| Near-white branded background | $C_{\text{bg}} \approx (H, 80, 80\text{ to }90)$ | saturation=80, lightness=80–90 |
| Soft border | $C_{\text{border}} \approx (H, 20, 80)$ | saturation=20, lightness=80 |
| Dark branded text | $C_{\text{text}} \approx (H, 20, 40)$ | saturation=20, lightness=40 |
| Secondary button fill | $C_{\text{secondary}} \approx (H, S', 80)$ | small to moderate saturation |

### Background Creation Procedure
1. Switch color controls to **HSL**
2. Set: lightness $L \in [80, 90]$, saturation $\approx 80$
3. Result: very light tinted background, almost off-white, tied to brand color

### Border Derivation
1. Sample the accent color
2. Reduce saturation to about **20**
3. Increase lightness to around **80**

For higher contrast:
- lower lightness to around **60–70**

---

## 3. Text and Label Colors

**Reference:** REF 43:03–43:34

### Label Text (Above Fields)
| Property | Value |
|---|---|
| Saturation | about **20** |
| Lightness | about **40** |

> **Rule:** Pure black visually detaches from the rest of the palette. A dark gray tinted with the accent color blends better with the interface.

### Heading Hierarchy
| Level | Lightness | Notes |
|---|---|---|
| Strong heading | **30** | Stronger emphasis |
| Standard heading | **40** | Default |
| Secondary/muted text | **60** | Supporting detail |

### Secondary Text Treatment
**Reference:** REF 5283–5295

| Property | Value |
|---|---|
| Saturation | **10** |
| Lightness | **60** |

### Supporting Text Demotion
**Reference:** REF 4877–4879

| Property | Adjustment |
|---|---|
| Lightness | increase by about **20** |
| Saturation | decrease by about **10** |

---

## 4. Secondary Accent Color

**Reference:** REF 01:32:14

### Creation Method
1. Duplicate the accent-color square
2. Shift hue slightly toward a nearby neighboring hue (example: green toward yellow-green)
3. Adjust lightness and saturation until it harmonizes

### Safety Rules
- Stay close to the main accent hue
- If colors clash, reduce saturation or tweak lightness

### Use Cases
- Cart notification badges
- Add-to-cart buttons (for differentiation from primary accent elements)
- Account-type/points badges

---

## 5. Validation State Colors

**Reference:** REF 01:09:45–01:20:50

| State | Visual Treatment |
|---|---|
| **Positive/Valid** | green border and/or green icon |
| **Warning/Weak quality** | orange indicator |
| **Error/Invalid** | red border + red message |
| **Revealed password** | swapped eye icon + literal characters |
| **Placeholder/Empty** | lighter italic text |
| **Entered/Valid input** | darker semibold text |

### Error State Treatment
**Reference:** REF 01:15:10–01:18:41

| Element | Treatment |
|---|---|
| Field border | shift hue toward red, keep other values similar |
| Error message text | same red as field border |
| Optional | make actual input text red as well |

### Mismatch Error
- Apply the same red border color to **both** affected fields
- Mismatch errors should identify both affected fields, not just one

---

## 6. Special Color Treatments

### Favorite/Heart Icon
**Reference:** REF 02:57:39

- Use a **desaturated red** rather than a strong red
- A strong red would clash with a green-based palette
- A muted red preserves the "favorited" meaning without overpowering the rest of the screen

### Negative Notification (Out of Stock)
**Reference:** REF 03:56:13

| Element | Treatment |
|---|---|
| Background | shift toward red |
| Saturation | keep moderate |
| Text | darken/desaturate so it stays mostly gray with a hint of red |

> **Rule:** Negative notifications often use red, but excessive saturation can make the UI loud and hostile. A muted red communicates status without overwhelming the design.

### Map Pin Tint
**Reference:** REF 03:23:26

- If the map is very colorful, add a fill to the map image
- Use the main accent color
- Lower opacity to about **5%**

---

## 7. Shadow Ratio Formula

**Reference:** REF 23:10–24:42

### Core Formula

Given vertical offset $y$ and blur $b$:

$$
b \ge 2y
$$

> **Rule:** Blur must be at least **2× the Y offset**

### Examples

| Element | Y offset | Blur | Ratio |
|---|---|---|---|
| Card shadow | **16** | **32** | 2:1 |
| Button shadow (default) | **4** | **8** | 2:1 |
| Button shadow (stronger) | **8** | **16** | 2:1 |
| Text shadow | **2** | **4** | 2:1 |
| Logo shadow | **16** | **32** | 2:1 |

> **Why:** Soft shadows give depth without harshness. Colored shadows tied to the object feel more natural.

### Interdependence Rule
If the shadow gets smaller, it often needs to get darker to remain visible.

---

## 8. Card Shadows

**Reference:** REF 23:10

### Card Shadow Example

| Property | Value |
|---|---|
| Y offset | **16** |
| Blur | **32** |
| Color | sampled from accent/image area, then desaturated and lowered in opacity |

### Procedure
1. Shadow color sampled from the accent/image area
2. Desaturate the sampled color
3. Lower opacity for softness

---

## 9. Button Shadows

**Reference:** REF 23:10, 01:21:53

### Default Button Shadow

| Property | Value |
|---|---|
| Y | **4** |
| Blur | **8** |
| Spread | **-2** |
| Color | derived from darker accent of the button |
| Opacity | lower for softness |

### Stronger Button Shadow

| Property | Value |
|---|---|
| Y | **8** |
| Blur | **16** |
| Spread | **-2 or 0** |

### Custom Button Shadow Setup

| Property | Value |
|---|---|
| Y | **16** |
| Blur | **32** |
| X | **0** |
| Spread | optional negative spread so shadow tucks under button |
| Color | app's accent color, darkened to lightness around **35** |
| Opacity | **40–60%** |

---

## 10. Logo and Text Shadows

**Reference:** REF 01:23:27, 01:24:27

### Logo Shadow

| Property | Value |
|---|---|
| Y | **16** |
| Blur | **32** |
| Color | accent-derived shadow color |

> **Note:** Logo shadow can be more expressive because the logo is branding, not an action control.

### Primary Button Text Shadow

| Property | Value |
|---|---|
| Y | **2** |
| Blur | **4** |
| Color | accent color with lightness decreased by about **10** |
| Alpha | **50%** |

> **Constraint:** Do **not** add this shadow to light secondary buttons.

---

## 11. Map UI Depth Strategy

**Reference:** REF 03:21:59–03:30:23

On map screens, standard shadows are often replaced or supplemented by subtle transparency gradients:

| Location | Purpose |
|---|---|
| Under top navbar | depth separation |
| Above/below bottom pullout card | panel lift effect |

### Rule
The gradients should be weak enough to imply depth without visibly darkening large parts of the map.

### Gradient Overlay for White Top Controls

| Property | Value |
|---|---|
| Fill type | linear gradient, both ends black |
| Bottom handle opacity | **0%** |
| Top handle opacity | **80–90%** |

### Pullout Card Depth
**Reference:** REF 03:30:23

1. Duplicate the top gradient shadow
2. Rotate it **180°**
3. Place it under the pullout card
4. Keep it subtle: move lower or reduce opacity

---

## 12. Gradient Rules

### Button Gradient
**Reference:** REF 23:10, 49:17

| Property | Rule |
|---|---|
| Colors | two similar accent colors |
| Direction | diagonal: bottom-left to top-right |
| Lightness difference | 3–4 points between stops |
| Bottom | darker color |
| Top | lighter color |

### Procedure
1. Remove border
2. Fill with accent color
3. Switch fill to linear gradient
4. Make both gradient stops the same accent color first
5. Optionally rotate the gradient to diagonal
6. Decrease lightness on one side by **3–4**
7. Increase lightness on the other side by **3–4**

### Logo Gradient
**Reference:** REF 01:00:30

- Optionally add a subtle diagonal gradient to the logo square

### Background Gradient
**Reference:** REF 01:25:32

| Property | Rule |
|---|---|
| Direction | top-to-bottom |
| Top stop | white |
| Bottom stop | original very light branded background |
| Visibility | very low (adds depth without distraction) |

---

## 13. Corner Radii

**Reference:** REF 21:39

### Radius Mapping

| Element | Radius | Notes |
|---|---|---|
| Main card | **8** | |
| Photo top corners (in card) | **8** | photo corners only |
| Internal smaller elements | **4** | inner elements should visually relate to, but not overpower, parent |
| Button | **4** | |
| Button label block | **8** | |
| Tile/container | **8** | more card-like than form field |
| Selected-tab pill | **8** | |
| Floating action button (find me) | **8** | |
| Field/button (example) | **4** | other options: 0 (sharp), 8, or 16 |

### Beginner Guidance
- Keep radius low for the first app
- Large pill radii imply matching pill text fields, which can weaken alignment clarity for top labels

---

## 14. Nested Radius Rule

**Reference:** REF 01:38:43–01:40:10

### Core Rule

$$
r_{\text{inner}} < r_{\text{outer}}
$$

### Demonstrated Values

| Level | Initial | Adjusted |
|---|---|---|
| Outer tile radius | **8** | **8** |
| Inner image radius (initial) | **4** | |
| Inner image radius (adjusted) | | **2** |

### Why Adjust from 4 to 2
If the tile radius is 8 and the photo radius is 4, the white gap around the masked photo can look uneven near diagonals. Decreasing to **2** makes the white space around the photo look more uniform—diagonal clearance becomes closer to top/left clearance, and the nested shape feels more visually balanced.

---

## 15. Icon Consistency

**Reference:** REF 11:10

### Rule
All icons in one interface should come from the **same icon set**.

### Consistency Dimensions
| Dimension | Requirement |
|---|---|
| Corner roundness | must match across all icons |
| Stroke thickness | must be consistent |
| Filled vs outline style | pick one style and stick with it |
| Detail density | should be uniform |

> **Why:** Even small stylistic mismatches make a UI feel inconsistent.

### Icon Sizing Guidance
| Context | Size |
|---|---|
| Menu icon placeholder | **24 × 24** (yields icon around **16 × 16**) |
| Badge circle | **16 × 16** |
| Tab icon | fit within tab container |
| Navbar icon | centered in **44 × 44** hit area |

### Icon Color
- Use the darker desaturated accent color for standard icon outlines
- Active tab icons may switch to **white** when on a dark/accent background

---

## Quick Reference Card

### HSL Palette Quick Lookup

```
Accent = (H, S, L)
├─ Background:   (H, 80, 80-90)
├─ Border:       (H, 20, 80)
├─ Text:         (H, 20, 40)
├─ Secondary:    (H, ~10, 60)
└─ Secondary btn: (H, small S, 80)
```

### Shadow Quick Lookup

```
Ratio: blur ≥ 2 × Y offset

Card:       Y=16, blur=32
Button:     Y=4,  blur=8   (or Y=8, blur=16)
Text:       Y=2,  blur=4
Logo:       Y=16, blur=32
```

### Radius Quick Lookup

```
Outer container: 8
Inner element:   2-4
Button:          4
```

### Gradient Quick Lookup

```
Button:  diagonal, accent ± 3-4 lightness
Logo:    subtle diagonal
Background: top-to-bottom, white to light brand
```

---

*End of reference file*
