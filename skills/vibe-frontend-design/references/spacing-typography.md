# Spacing and Typography Reference

Reference file for spacing tokens and typography rules for screen-based UI design.

> Source: UI Design Fundamentals course (REF 00:00–04:14:25)

---

## 8-Point Grid System

The foundational layout system is based on an **8-point base grid** (REF 12:52).

### Base Grid Units

| Token | Size | Primary Use |
|-------|------|-------------|
| 4 | 4 pt | Micro gaps, fine line separation |
| 8 | 8 pt | Tight text-to-text relations |
| 16 | 16 pt | Items within one content group |
| 24 | 24 pt | Card padding or gap between repeated groups |
| 32 | 32 pt | Outer margins, major section separation |
| 48 | 48 pt | Large vertical separation, breathing room |

---

## Spacing Hierarchy Model

Objects that are closer to one another are naturally perceived as belonging together (REF 13:50).

### Relationship-Based Spacing

| Relationship | Typical Spacing |
|--------------|----------------|
| Tight/internal elements | 4, 8, 16 |
| Medium/internal or card padding | 16, 24 |
| Section/action separation | 24, 32 |
| Major section separation | 32, 48 |

### Practical Spacing Ladder for Browsing Screens

| Spacing | Typical Role |
|---------|--------------|
| 8 | Between closely related text lines |
| 16 | Internal padding and image/text alignment |
| 24 | Separation between repeated cards/rows within one list |
| 32 | Section margins, screen edges, larger structural offsets |

---

## Outer Margins

- Screen left/right margins: **32 pt** (REF 14:51, 25:45, 40:31)
- Card outer margin from screen: **32 pt**

---

## Touch Targets

### Mobile Tap Target Rules

| Element | Safe Rule |
|---------|-----------|
| Comfortable tap target | **44 × 44 pt** minimum |
| Button height minimum | **40 pt** |
| Button height preferred | **44–48 pt** |
| Icon container | Often fits inside 44 × 44 |
| Icon graphic | Usually no more than about half of that square when unsure |

**Hard Rule**: A button at 40 × 20 is too small and frustrating on mobile (REF 06:02).

### OS Helper Heights

| Element | Height |
|---------|--------|
| Status bar | 44 |
| Nav bar | 60 |
| Tab bar | 64 |
| Safe area | 22 |

### Invisible Touch Targets

For small icons or text links (REF 46:41):
1. Create a rectangle with height **44 pt**
2. Set rectangle opacity to **0**
3. Center the visible element within the invisible touch area
4. Group rectangle + visible element together

---

## Typography Scale

### Font Size Ranges

| Use | Recommended Size |
|-----|-----------------|
| Minimum readable mobile text | **12 pt** |
| Common interface text | **12–24 pt** |
| Body copy safe zone | **14–16 pt** |
| Large emphasis / onboarding titles | **32–40 pt** |

### Hard Rule
**Do not go below 12 pt on mobile** (REF 07:10).

### Exception for Tab Labels
Tab bar labels can go as low as **10 pt** (REF 02:33:03).

### Exception for Notification Badges
Notification bubbles are a rare case where **10–11 pt** may be acceptable (REF 01:32:45).

### Font Weight Guidelines

| Weight | Use Case |
|--------|----------|
| Regular | Body and primary content |
| Medium | Labels, secondary emphasis |
| Bold/Semibold | Headings, emphasis |
| Extra bold | Large hero headings (use sparingly) |

**Avoid**: Thin and light weights as a beginner (REF 07:10).

### Typography Consistency Rules

- Use a **small selection of fonts**
- Prefer **one font family per product**
- Avoid experimental font pairing early on
- Avoid thin and light weights

---

## Typography for Specific Elements

### Category List Items

| Element | Size |
|---------|------|
| Category name | 16 pt, stronger weight |
| Item count | 12 pt, lighter, less saturated |

### Product Titles

| Context | Size |
|---------|------|
| Standard product title | 24 pt, bold |
| Store title in pullout card | 20 pt |
| Hero heading (registration) | 32 pt |

### Secondary/Meta Text

| Element | Treatment |
|---------|-----------|
| Item count | Lighter than primary, saturation 10–15 |
| Opening hours/address | Lightness ~60, saturation ~10 |
| Supporting metadata | Increase lightness by ~20, decrease saturation by ~10 |

---

## Line Height Rules

### Body Text Line Height

For font size `f`, readable line height can be estimated by:

```
line height ≈ (1.3 to 1.6) × f
```

| Font Size | Recommended Line Height Range |
|-----------|------------------------------|
| 12 | 15.6 – 19.2 |
| 14 | 18.2 – 22.4 |
| 16 | 20.8 – 25.6 |

**Example**: For 14 pt body text, a line height of **20** is within the recommended range (REF 02:47:46).

### Text-to-Line Spacing Within Blocks

- Use **8 pt** between description and price (REF 02:02:57)
- Use **8 pt** between title and description (REF 02:02:57)
- Reduce line height within description for tighter stacking (example: 15 instead of 17)

---

## Corner Radii

### Nested Radius Rule

Outer containers should have larger radii than inner elements:

| Element | Radius |
|---------|--------|
| Main card | 8 |
| Photo top corners only | 8 |
| Internal smaller elements | 4 |
| Button | 4 |
| Button label block | 8 |
| Tile/container radius | 8 |
| Thumbnail initial radius | 4 |
| Thumbnail adjusted mask radius in tile | 2 |
| Floating action button | 8 |
| Selected-tab pill | 8 |

**Relation**: `r_inner < r_outer` (REF 01:38:43)

---

## Button Sizing

### Button Height

| Purpose | Value |
|---------|-------|
| Minimum | 40 pt |
| Preferred | 44–48 pt |
| Example (form) | 56 pt |
| Safe range | 44–60 pt |

### Button Padding

For a button with label width `L`:

```
button width ≈ L + 2P_x
```

Where safe beginner padding is:

```
P_x ≥ width of one "W" (conservative)
P_x ≈ width of two "W"s (better)
```

**Vertical padding**: `P_top = P_bottom`

### Button Label Sizing

- Button label text: **16–17 pt** (OPTICAL centering may require adjustment)
- Button labels should be centered horizontally and vertically

---

## Field/Input Sizing

| Element | Value |
|---------|-------|
| Field height | 44 pt |
| Field/button radius | 4 |
| Label font size | 12–14 pt |
| Placeholder font size | Same as label |
| Placeholder style | Italics, lighter color |

---

## Card Layouts

### Two-Column Card Grid

For frame width `W`, two cards, side margins `m`, and inter-card gap `g`:

```
card width = (W - 2m - g) / 2
```

**Example**: For 390 pt width, 32 pt margins, 24 pt gap:

```
card width = (390 - 2(32) - 24) / 2 = 151 pt
```

### Card Internal Padding

| Purpose | Value |
|---------|-------|
| Card internal padding | 16 pt |
| Gap between cards | 24 pt |
| Screen-edge margin | 32 pt |

---

## List View Spacing

### Tile-Based List

| Purpose | Value |
|---------|-------|
| Gap between list items | 24 pt |
| Tile internal padding | 16 pt |
| Tile/container radius | 8 |
| Text-to-thumbnail gap | 16 pt |
| Text line gap inside category item | 8 pt |

### Full-Width List Row

| Purpose | Value |
|---------|-------|
| Top padding | 24 pt |
| Bottom padding | 24 pt |
| Left padding | 32 pt |
| Right padding | 32 pt |

### Product Row

| Purpose | Value |
|---------|-------|
| Product image size | 88 × 88 pt |
| Text-to-text spacing | 8 pt |
| Gap between product rows | 24 pt |

---

## Tab Bar Dimensions

### Tab Width Calculation

For screen width `W` and `n` tabs:

```
w = W / n
```

If `w` is not an integer, distribute remainder across gaps.

| Number of Tabs | Tab Width (for 390 pt screen) |
|----------------|-------------------------------|
| 2 | 195 pt |
| 3 | 130 pt |
| 4 | 96 pt with 2 pt gaps |
| 5 | 78 pt |

### Tab Bar Vertical Layout

| Purpose | Value |
|---------|-------|
| Label baseline to safe area | 8 pt |
| Icon zone spacing above labels | 16 pt |
| Selected-tab pill radius | 8 |

---

## Navigation Elements

### Hamburger Menu

| Element | Value |
|---------|-------|
| Menu width | ~2/3 of screen |
| Left margin | 32 pt |
| Menu item touch target height | 48 pt |
| Icon placeholder size | 24 × 24 pt |
| Icon-to-text gap | 16 pt |
| Menu title top/left margin | 32 pt |
| Logout bottom margin | 32 pt |

---

## Modal/Popup Spacing

### Confirmation Dialog

| Relation | Spacing |
|----------|---------|
| Popup top → title | 24 or 32 pt |
| Title → description | 24 or 32 pt |
| Description → buttons | 32 pt |
| Buttons → popup bottom | 16 pt |
| Close icon invisible target | 48 × 48 pt |

### Equal-Width Button Layout

- Place **16 pt** squares as helpers for equal spacing
- Gap between two buttons: **16 pt**

---

## Shadow Rules

### Soft Shadow Ratio

**Rule**: `blur ≥ 2 × Y offset`

| Element | Y Offset | Blur | Spread |
|---------|----------|------|--------|
| Card shadow | 16 | 32 | — |
| Button shadow (large) | 16 | 32 | — |
| Button shadow (small) | 8 | 16 | -2 or 0 |
| Text shadow | 2 | 4 | — |
| Logo shadow | 16 | 32 | — |

---

## Profile Screen Dimensions

### Left-Aligned Profile

| Element | Value |
|---------|-------|
| Avatar size | 48 × 48 pt |
| Left margin | 32 pt |
| Name-to-avatar gap | 16 pt |
| Card top from avatar | 32 pt |
| Badge internal padding | 16 pt |
| Gap between metadata badges | 8 pt |
| Section-to-section spacing | 32 pt |

### Centered Hero Profile

| Element | Value |
|---------|-------|
| Profile photo size | 160 × 160 pt |
| Photo to centered name | 32 pt |
| Name to badges | 32 pt |
| Description width margins | 32 pt |
| Gap from centered bio to left-aligned rails | 48 pt |

---

## Map View Elements

| Element | Value |
|---------|-------|
| Base map pin size | ~20 pt |
| Max selected pin size | Under 48 pt |
| Pullout card side margin | 32 pt |
| Pullout photo size | 100 × 100 pt |
| Photo-to-text gap in pullout | 24 pt |
| Store title size in pullout | 20 pt |
| Title to first detail line | 24 pt |
| Gap between small detail lines | 16 pt |
| Chevron above bottom safe area | ~4 pt |
| Floating "find me" button | 48 × 48 pt |
| Floating button corner radius | 8 |
| Floating button offset from edges | 24 pt |

---

## Artboard Organization

| Element | Value |
|---------|-------|
| Artboard gap | 100 pt (both horizontal and vertical) |

---

## Color-Derived Text System (Inferred)

From accent color `C = (H, S, L)`:

| Purpose | Approximate Values |
|---------|-------------------|
| Dark branded text | H, ~20, ~40 |
| Light/secondary text | H, ~20, ~60 |
| Placeholder text | H, ~10, lighter |
| Field border | H, ~20, ~80 |

---

## Accessibility Requirements

| Factor | Requirement |
|--------|------------|
| Minimum readable UI text | 12 pt |
| Allowed tab-label minimum | 10 pt |
| Font weights to avoid | Thin and light |
| Contrast target | AA |
| Elements to check | Text/background, button text/fill, important figures |

---

## Quick Reference Numbers

| Rule | Value |
|------|-------|
| Touch target minimum | 44 × 44 pt |
| Button height minimum | 40 pt |
| Button height preferred | 44–48 pt |
| Font minimum on mobile | 12 pt |
| Body text safe zone | 14–16 pt |
| Large titles | 32–40 pt |
| Base grid | 8 pt |
| Helper squares | 4, 8, 16, 24, 32 |
| Card radius | 8 |
| Inner element radius | 4 |
| Status bar | 44 |
| Nav bar | 60 |
| Tab bar | 64 |
