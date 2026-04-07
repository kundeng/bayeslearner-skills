# /rrpa-explore and /rrpa-evidence

Observed facts:

- entry page starts on overall ranking
- durability sort is triggered by `td.durability a`
- sorted result state is represented by durability-specific URL pattern
- result rows live in `table tbody tr:not(.head)`
- numeric pagination controls are matched by `a.btn.btn-default[href*='p=']`

Expected exploitation shape:

- root rule performs the sort action
- page rule paginates numerically
- row rule extracts all visible ranking fields
