# Forms & Validation Reference

*Source: ref1.txt (Mobile UI Design Course, Part 2–3) + ref2.txt (Designing Interfaces, Chapter 10)*

---

## Field Styling (ref1: Part 2, Lines ~718–1275)

### Dimensions

| Property | Value |
|---|---|
| Field height | 44pt |
| Field corner radius | 4pt |
| Border width | 1–2pt |
| Border color | Accent-derived (brand color) |
| Background | White or surface color |

### Internal Padding
- Horizontal padding: 16pt minimum
- Vertical padding: 12–14pt to center text within 44pt height

### States

| State | Visual Treatment |
|---|---|
| Empty / Placeholder | Light italic text, muted color |
| Focused | Thicker border (2pt), accent color, no background fill |
| Filled / Valid | Darker semibold text, normal border |
| Disabled | 50% opacity, no interaction |

### Validation State Styling

| Validation Result | Color | Use |
|---|---|---|
| Success / Valid | Green | Completed fields, correct input |
| Weak / Warning | Orange | Partial match, acceptable but not strong |
| Error / Invalid | Red | Incorrect format, required field empty |

Validation state text should use **lighter italic** for placeholder/pending states and **darker semibold** for entered/valid states.

---

## Button Construction (ref1: Part 2, Lines ~718–1275)

### Dimensions

| Property | Value |
|---|---|
| Button height | 40–60pt (preferred: 44–48pt) |
| Corner radius | 8pt |
| Horizontal padding | ≥ width of one "W" glyph; preferably two "W"s |

### Fill & Visual Treatment

| Type | Fill | Effect |
|---|---|---|
| Primary CTA | Gradient (top-to-bottom, lighter to darker) | Drop shadow below |
| Secondary CTA | Solid or subtle fill | Flat or minimal shadow |
| Ghost / Link | No fill | No shadow, text only |

### Shadow (for buttons with drop shadow)

- **Blur** ≥ 2× the Y offset
- Ratio: Blur : Y offset = 2 : 1 or more
- Example: Y=4pt → Blur≥8pt

### Touch Safety
- Buttons must meet 44×44pt minimum touch target
- Adequate spacing between adjacent buttons (≥8pt)

---

## Form Grouping (ref1: Part 2, Lines ~718–1275)

### Label Placement

- **Above field** (recommended): Label on line directly above the input field; 8pt gap between label baseline and field top edge
- **Inline label**: Label inside field as placeholder text; floats on focus/fill

### Grouping Principles

- Logical sections separated by **24pt gap**
- Related fields grouped under a **section heading** (optional)
- Single-field groups: no extra spacing beyond label-to-field gap
- Keep related fields on the same screen; avoid scrolling between logically linked inputs

### Spacing Within Groups

| Context | Spacing |
|---|---|
| Between label and field | 8pt |
| Between fields in a group | 16pt |
| Between groups (sections) | 24pt |
| Between form and next element | 32pt |

---

## Validation States (ref1: Part 3, Lines ~1349–2078)

### Core Validation State Map

| State | Color | Visual Cue | Text Weight |
|---|---|---|---|
| Success | Green | Checkmark icon or green border | Semibold, darker |
| Weak / Warning | Orange | Warning icon or orange border | Normal weight |
| Error / Invalid | Red | Error icon or red border | Normal or semibold |

### Inline Validation Behavior

- **On blur** (recommended): Validate after user leaves the field
- **On submit**: Show all errors at once
- **On keystroke**: Validate as user types (use sparingly; can be annoying)

### Error Message Placement

- Directly below the field (8pt gap)
- Left-aligned with the field
- Be specific: "Email must include @" not "Invalid email"

### Validation States Summary

| Pattern | When to Use | Key Behavior |
|---|---|---|
| **Inline on blur** | Most forms | Validate after field loses focus |
| **Inline on change** | Password strength, real-time search | Validate immediately as user types |
| **Submit all-at-once** | Long forms | Show all errors only on form submission |
| **Optimistic success** | Conversational / chat UI | Show success immediately, revert if error |

---

## Touch-Safe Links (ref1: Part 2, Lines ~718–1275)

### Minimum Touch Target
- **44×44pt** invisible hit area around any tappable element
- Text links count as tappable if they trigger an action (not navigation to a page)

### Implementation
- Wrap link text in a hit area container sized 44×44pt minimum
- Container can be transparent/invisible but is the touch target
- For inline text links, ensure vertical padding extends the touch area above/below the text baseline

### Visual vs. Touch Area

| Element | Visual Size | Touch Area |
|---|---|---|
| Small icon button | 24×24pt | 44×44pt (centered) |
| Text link | Text height + padding | 44pt vertical minimum |
| Card tap area | Full card | 44×44pt per target |

---

## Login / Registration Flow Rules (ref1: Part 2, Lines ~718–1275)

### Login Form Structure

1. **Email or username field** — first position
2. **Password field** — second position, with show/hide toggle
3. **"Forgot password" link** — aligned right of password field or below
4. **Primary CTA**: "Sign in" button
5. **Secondary link**: "Create an account" or "Register"

### Registration Form Structure

1. **Full name** or **First / Last name** (split or combined)
2. **Email field**
3. **Password field** + password strength indicator
4. **Confirm password field** (if required)
5. **Terms / Privacy checkbox**
6. **Primary CTA**: "Create account" button
7. **Secondary link**: "Already have an account? Sign in"

### Password Field Specifics

- **Show/hide toggle** icon: Eye icon inside field, right side
- Toggle must be a separate tap target (not the field itself)
- Default state: obscured (dots)
- Toggle tap shows plain text momentarily

### Error Handling in Auth Flows

- Invalid credentials: "Incorrect email or password" (do not reveal which is wrong)
- Email taken: "An account with this email already exists"
- Password too weak: Show password strength meter inline
- Network error: "Unable to connect. Check your internet connection."

---

## List View Rules (ref1: Part 2, Lines ~718–1275)

### Row Dimensions

| Property | Value |
|---|---|
| Row height | 44–60pt |
| Touch target per row | Full width × 44pt minimum |
| Corner radius (if card-style) | 8pt |

### Row Anatomy

```
[Leading icon/avatar] — [Title + subtitle stack] — [Trailing icon/chevron]
```

- **Leading element**: 40×40pt avatar or 24×24pt icon
- **Title**: Primary text, semibold, 14–16pt
- **Subtitle**: Secondary text, regular, 12–13pt, muted color
- **Trailing**: Chevron (▶), badge, or action icon

### Spacing

| Gap | Value |
|---|---|
| Leading to text | 16pt |
| Title to subtitle | 4pt |
| Text to trailing | 8pt |
| Between rows | 0pt (border separator) or 8pt (gap separation) |

### Dividers

- Full-width 1pt lines or partial inset 16pt lines
- Color: 10–20% opacity black (or surface border color)

---

## Card Layout (ref1: Part 2, Lines ~718–1275)

### Card Dimensions

| Property | Value |
|---|---|
| Corner radius | 8pt |
| Internal padding | 16pt |
| Shadow | Y=4pt, Blur≥8pt (same ratio as buttons) |
| Border (optional) | 1pt, 10% opacity |

### Card Anatomy

```
[Optional header image/banner]
[Title] — [Optional badge]
[Subtitle or description]
[Optional metadata row]
[Optional actions]
```

### Spacing Within Cards

| Context | Spacing |
|---|---|
| Padding (all sides) | 16pt |
| Title to body | 8pt |
| Between sections | 16pt |
| Action buttons at bottom | 16pt from content, 8pt gap between buttons |

### Card States

| State | Treatment |
|---|---|
| Default | Normal background, shadow |
| Pressed / Tapped | Slightly darker background, reduced shadow |
| Disabled | 50% opacity, no interaction |
| Selected | Border highlight (2pt, accent color) |

---

## Badge / Notification (ref1: Part 2, Lines ~718–1275)

### Badge Dimensions

| Property | Value |
|---|---|
| Size (circular) | 16×16pt |
| Size (pill) | Auto-width, min 20pt height |
| Corner radius (circular) | 50% (full circle) |
| Corner radius (pill) | 50% of height |

### Badge Colors

| Badge Type | Color |
|---|---|
| Status indicator | Green (active), Orange (pending), Red (error) |
| Count badge | Red, white text |
| Category badge | Brand accent color |
| New badge | Green with "New" text |

### Badge Placement

- **Notification dot**: Top-right corner of parent element, 4pt offset from edges
- **Count badge**: Same position as notification dot, overlapping
- **Pill badge**: Adjacent to label text, right side, 8pt gap

### Badge States

| State | Opacity / Treatment |
|---|---|
| Active | 100% opacity |
| Read / Seen | 60% opacity or muted color |
| Disabled | 30% opacity |

---

## Search Field (ref1: Part 2, Lines ~718–1275)

### Search Field Anatomy

```
[Search icon] — [Input field] — [Clear button (when filled)] — [Cancel (mobile)]
```

### Dimensions

| Property | Value |
|---|---|
| Height | 44pt |
| Corner radius | 8pt |
| Icon size | 20×20pt |
| Icon padding from edge | 12pt |

### Search Field Behavior

- **Placeholder**: "Search…" or "Search [context name]"
- **Icon**: Magnifying glass on left
- **Clear button**: X icon appears when field has text; clears on tap
- **Cancel**: "Cancel" text button on right (mobile); closes search mode

### Keyboard

- **Return key**: "Search" label (not "Return")
- Auto-focus on search activation
- Dismiss keyboard on scroll or outside tap

---

## Form Design Patterns from "Designing Interfaces" (ref2: Chapter 10, Lines ~10920–12200+)

*Format: What / Use When / Why / How*

---

### Forgiving Format

**What:** An input that accepts multiple valid formats for the same data.

**Use When:**
- The data has a common format that users may enter in several ways
- Strict formatting frustrates users (phone numbers, dates, times)
- Users are likely to paste pre-formatted data

**Why:**
- Reduces friction and cognitive load
- Prevents "format rage" — users shouldn't have to guess the exact format
- Makes copy-paste from other sources work seamlessly

**How:**
- Accept delimiters like dashes, slashes, or spaces for dates/times
- Strip formatting characters as user types
- Show normalized result after entry
- Example: Accept "555-123-4567", "(555) 123-4567", "555.123.4567"

---

### Structured Format

**What:** An input broken into separate sub-fields for structured data.

**Use When:**
- The data naturally divides into known parts
- Each part has a fixed, limited character count
- You need to enforce structure (credit card, phone, SSN)

**Why:**
- Visual clarity — users see exactly how many characters per field
- Guides users toward correct input length
- Useful for data that will be parsed programmatically

**How:**
- Break into 3–5 sub-fields
- Auto-advance to next field on completion
- Backspace at start of field moves to previous field
- Sum the values server-side for validation/transmission

---

### Fill-in-the-Blanks

**What:** A form where labels appear inside fields and move or shrink when the user focuses or types.

**Use When:**
- Space is limited (mobile, dialogs, single-field focus)
- You want a clean, uncluttered form
- Users are likely to recognize field labels immediately

**Why:**
- Saves vertical space
- Reduces visual noise — one element instead of label + field
- Works well for single or two-field screens

**How:**
- Label starts inside the field (placeholder text, light color)
- On focus: label stays or moves up to become a floating label
- When filled: label shrinks to top-left, stays visible (not just placeholder)
- Fallback: if label is unclear without context, add a visible label above

---

### Input Hints

**What:** Short instructional text placed near an input field to guide correct entry.

**Use When:**
- The expected format is not obvious
- The field has special requirements (password rules, date ranges)
- Help text clarifies ambiguity

**Why:**
- Reduces errors by setting expectations upfront
- Avoids error messages that feel punitive
- Better than forcing users to discover format requirements through trial

**How:**
- Place hint text below the field (8pt gap) or inside the field as placeholder
- Keep hint text concise (one line preferred)
- Use muted color so it doesn't compete with the input itself
- Update or change hint based on context (e.g., hint changes as user types)

---

### Input Prompt

**What:** A word or phrase inside an input field that disappears on focus, acting as a label.

**Use When:**
- The form is simple and fields are obvious
- Space is at a premium
- Users are likely to recognize field purpose without full labels

**Why:**
- Minimalist design — keeps forms short
- Works well for search bars, single-field forms
- Reduces label redundancy in obvious UIs

**How:**
- Place prompt text as placeholder inside the field
- Disappears as soon as user focuses or types
- Ensure prompt is visible but muted (not confusing with entered text)
- Never use placeholder as the only label for critical or non-obvious fields

---

### Password Strength Meter

**What:** A visual indicator showing how strong a user's password is as they type.

**Use When:**
- Users are creating a new password
- Security requirements vary and you want to encourage strong passwords
- You want to prevent weak password submissions

**Why:**
- Guides users toward better passwords in real time
- Reduces failed submissions and frustration
- Encourages longer or more complex passwords without prescribing rules

**How:**
- Show meter bar or segmented bar (e.g., 4 segments)
- Color progression: Red → Orange → Yellow → Green (or similar)
- Update meter as user types
- Optionally: List specific requirements as they become met
- Do not block submission on weak passwords unless required by policy

---

### Autocompletion

**What:** A text input that suggests possible completions as the user types.

**Use When:**
- Users are entering data that exists in a known set (countries, product names, email domains)
- Reducing typing effort is valuable (long names, addresses)
- Data accuracy matters (don't let users misspell city names)

**Why:**
- Reduces typing, especially on mobile
- Prevents spelling errors in known datasets
- Speeds up form completion

**How:**
- Show dropdown list of matches below the field
- Match from first character (or after 2–3 characters typed)
- Highlight matching portion in suggestions
- On selection, populate field with chosen value
- Provide "Other…" option if the dataset is not exhaustive

---

### Drop-down Chooser

**What:** A field that opens a menu of options when activated.

**Use When:**
- There are 5–30+ options that would overwhelm a radio button group
- Space is limited
- Options are fixed and known in advance
- Single selection is required

**Why:**
- Saves space — replaces a long list of options with one field
- Organizes many options into a scannable menu
- Standard UI pattern users recognize

**How:**
- Closed state shows current selection (or placeholder if none)
- On tap, open menu below or above (based on screen space)
- Menu should not exceed viewport height; scroll internally
- Selected option shows checkmark or highlight
- Support keyboard navigation (arrow keys, typing to jump)

---

### List Builder

**What:** A control that lets users add multiple items to a list, tag, or collection.

**Use When:**
- Users need to create a set of items (email recipients, tags, filters)
- Each item needs individual removal
- Number of items is variable and unknown

**Why:**
- More flexible than a fixed multi-select
- Lets users curate custom lists without predefined options
- Clear feedback: users see exactly what they've added

**How:**
- Text input at top: "Add a recipient…"
- Each added item appears as a chip or row with an X remove button
- Chips can be reordered (drag) or removed (tap X)
- Prevent duplicates with a message
- Show count or character limit if relevant

---

### Good Defaults and Smart Prefills

**What:** Pre-populating form fields with sensible starting values.

**Use When:**
- Most users will select the same or similar options
- You have contextual data (location, account info) to prefill
- The form has common scenarios that dominate usage

**Why:**
- Reduces work — users don't start from a blank slate
- Guides users toward recommended choices
- Faster form completion

**How:**
- Default should be the most common or recommended option
- Clearly indicate which fields are pre-filled (subtle visual treatment)
- Allow users to change defaults easily
- For location, use geolocation with permission prompt
- For account info, pull from user profile after login

---

### Error Messages

**What:** Text that communicates when user input is invalid, missing, or problematic.

**Use When:**
- User submits a form with invalid data
- A required field is empty on submission
- Input format is incorrect (email, phone, etc.)
- Business logic validation fails (e.g., username taken)

**Why:**
- Without error messages, users don't know what went wrong or how to fix it
- Good error messages reduce support requests
- Error messages should be helpful, not punishing

**How:**
- **Placement**: Directly below the offending field, aligned left
- **Timing**: On submit (all errors) or on blur (per-field)
- **Tone**: Plain language, never blame the user ("Email is required" not "You failed to enter your email")
- **Specificity**: Be concrete — "Enter a date after Jan 1, 2024" not "Invalid date"
- **Recovery**: Tell the user how to fix it
- **Visuals**: Use red text/icon, but don't rely on color alone (include text)
- **Group errors**: At form level, summarize: "3 fields need attention" with scroll-to-first

---

## Deferred Choices (ref2: Lines ~950–1006)

*Behavioral Pattern*

**What:** Delaying optional or complex decisions until the user needs to make them.

**Use When:**
- A decision can safely be made later without breaking the flow
- The choice is complex and requires context to answer well
- Early choices add anxiety (paradox of choice)
- Default behavior is acceptable until the user expresses otherwise

**Why:**
- Reduces cognitive load at decision time
- Users can proceed with minimal friction
- Avoids premature commitment
- Defaults handle the common case; explicit choices handle edge cases

**How:**
- Start with a sensible default or skip the decision entirely
- Present the decision only when it becomes relevant
- Use context at decision time to guide or pre-filter options
- Example: "Don't ask for notification preferences at signup; ask when the first notification would fire"

---

## Incremental Construction (ref2: Lines ~1017–1075)

*Behavioral Pattern*

**What:** Building up a complex form or dataset through a series of small, focused steps rather than presenting one large, intimidating form.

**Use When:**
- A task has multiple steps or stages
- Users may not need all options
- Complexity grows as the user progresses
- Early steps are high-value, later steps are optional

**Why:**
- Reduces perceived complexity — one step at a time feels manageable
- Provides natural momentum — completing step 1 motivates step 2
- Lets users stop early with a valid partial result
- Reduces abandonment from overwhelming forms

**How:**
- Break the process into 3–7 steps max
- Show progress indicator (step X of Y)
- Each step focuses on one topic or group of related fields
- "Next" advances; "Back" returns (data preserved)
- Allow skipping optional steps
- Final step summarizes all choices before confirmation

---

## Numeric Specifications Quick Reference (ref1)

### Spacing System (8pt Grid)

| Token | Value | Use |
|---|---|---|
| Micro | 4pt | Icon gaps, tight internal spacing |
| Tight | 8pt | Label-to-field gap, between chips |
| Internal | 16pt | Field internal padding, card padding |
| Card gap | 24pt | Between cards, between form groups |
| Outer | 32pt | Screen edge margins, major section separation |
| Large | 48pt | Hero spacing, full-section gaps |

### Touch & Interaction

| Element | Minimum Size |
|---|---|
| Touch target | 44×44pt |
| Field height | 44pt |
| Button height | 40–60pt (preferred 44–48pt) |
| Badge (circular) | 16×16pt |
| Icon button | 24×24pt visual / 44×44pt touch area |

### Radius

| Element | Radius |
|---|---|
| Input field | 4pt |
| Button | 8pt |
| Card | 8pt |
| Pill badge | ~50% of height |
| Circular badge | 50% (full circle) |

### Shadows

- **Button drop shadow**: Blur ≥ 2× Y offset (e.g., Y=4pt, Blur=8pt+)
- **Card shadow**: Same ratio, slightly larger blur for more elevation
