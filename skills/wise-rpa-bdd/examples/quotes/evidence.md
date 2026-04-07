# /rrpa-explore and /rrpa-evidence

Observed facts:

- entry URL loads quote cards immediately
- quote cards are matched by `.quote`
- quote text is in `.text`
- author is in `small.author`
- tags are repeated `.tag` elements
- pagination uses `li.next a`

Expected exploitation shape:

- one resource starting at the entry URL
- page expansion via next button
- element expansion over `.quote`
- nested and flat artifacts emitted from the item rule
