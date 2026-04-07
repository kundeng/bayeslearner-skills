# /rrpa-explore

## Site Structure

- Entry URL: `https://quotes.toscrape.com/`
- Quote cards render immediately on page load (no JS SPA)
- Pagination via "Next" button at bottom of each page

## DOM Observations

- Quote cards: `.quote` selector matches each card
- Quote text: `.text` within each card
- Author: `small.author` within each card
- Tags: repeated `.tag` elements within each card
- Next page link: `li.next a`

## Pagination

- 10 quotes per page
- "Next" button present on all pages except the last
- At least 10 pages available (100+ quotes total)

## State and Auth

- No login required
- No session or cookie gates
- Content is static HTML, no dynamic JS loading
