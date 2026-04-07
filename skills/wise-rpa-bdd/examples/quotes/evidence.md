# /rrpa-evidence

## Confirmed Selectors

| Field | Locator | Extractor | Verified |
|-------|---------|-----------|----------|
| quote_text | `.text` | text | Yes |
| author | `small.author` | text | Yes |
| tags | `.tag` | grouped | Yes |

## Pagination Evidence

- Next button: `li.next a`
- Present on pages 1–9, absent on page 10
- Each page contains exactly 10 quote cards

## Container Evidence

- Quote card container: `.quote`
- Cards are direct children of the main content area
- Each card contains exactly one `.text`, one `small.author`, and zero or more `.tag` elements

## Sample Extracted Row

```
quote_text: "The world as we have created it is a process of our thinking. It cannot be changed without changing our thinking."
author: Albert Einstein
tags: [change, deep-thoughts, thinking, world]
```
