# /rrpa-explore and /rrpa-evidence

Observed facts:

- each section has a sidebar or nav listing section-local pages
- discovery works by BFS collection of matching nav links
- extraction requires resolving entry URLs from discovered records
- page content can be modeled as title plus article HTML

Expected exploitation shape:

- separate discovery resources per section
- separate extraction resources consuming the discovered URLs
- nested and flat output artifacts
