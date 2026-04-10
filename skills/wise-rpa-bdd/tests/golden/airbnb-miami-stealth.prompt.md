Scrape Airbnb vacation rental listings in Miami for a month-long stay in November.

Criteria:
- Location: Miami, Florida
- Dates: November 1-30 (monthly stay)
- Guests: 2 adults
- Property type: Entire home/apartment
- Bedrooms: 1
- Price: under $3,000/month
- Host: Superhost only

For each listing collect: property title, property name, nightly/monthly price,
rating, review count, and the listing URL.

Notes:
- Airbnb requires stealth mode (patchright + playwright-stealth)
- There is a "Got it" / pricing overlay modal on first load that must be dismissed
- Results are paginated with a "Next" button
- Some listings may have a "Guest favorite" badge — capture that if present
- Airbnb uses data-testid attributes extensively for UI elements
