# Execution

Use this file when running, validating, selecting, or post-processing Robot
Framework suites.

Source basis: Robot Framework User Guide sections on execution, dry run,
selection, output files, argument files, task execution, and Rebot.

## Default Loop

For new or changed suites, prefer this loop:

1. `robot --dryrun path/to/suite.robot`
2. targeted real run
3. inspect `log.html`, `report.html`, and `output.xml`
4. use `rebot` only when you need post-processing, merging, or reshaping

## Basic Commands

```bash
robot tests/
robot path/to/suite.robot
robot -t "Login Works" tests/
robot -i smoke tests/
robot -e slow tests/
robot --variable ENV:dev tests/
robot --outputdir results tests/
```

Prefer exact suite or tag selection while iterating. Full-tree runs are for
later.

## Dry Run

Use dry run first when the question is "is this suite syntactically and
structurally valid?"

```bash
robot --dryrun path/to/suite.robot
```

Why:

- catches syntax and data-shape problems early
- avoids executing library keywords
- it is the fastest safe validation step for generated or heavily edited suites

Do not confuse dry run with a real behavioral test pass.

Dry run is especially useful after:

- large AI-generated edits
- refactors that move keywords into resources
- variable-file reshaping
- template conversion

## Output Files

Robot Framework generates result artifacts such as:

- `output.xml`
- `log.html`
- `report.html`

Treat `output.xml` as the machine-readable source of truth.

If another tool or agent will consume results, use `output.xml` instead of
scraping HTML logs.

## Selection Patterns

Prefer narrow runs while iterating:

```bash
robot -t "Specific Case" suite.robot
robot -i smoke suite.robot
robot -i smokeANDapi tests/
robot -e flaky tests/
```

Use tags intentionally. They are the cleanest way to support:

- smoke runs
- environment-specific subsets
- slow vs fast suites
- ownership or feature slices

### Tag taxonomy that tends to age well

- execution speed: `smoke`, `slow`
- surface or domain: `api`, `ui`, `billing`
- environment or dependency: `requires-db`, `requires-browser`
- lifecycle or stability: `wip`, `flaky`

Avoid tag chaos. A small stable taxonomy beats dozens of one-off tags.

### Tag patterns (AND / OR / NOT)

```bash
robot -i smokeANDapi tests/          # both tags required
robot -i smokeORapi tests/           # either tag
robot -i "NOTslow" tests/            # exclude pattern
robot -i "smokeANDNOTflaky" tests/   # combined
```

### Reserved tags (RF 6+)

| Tag | Effect |
|---|---|
| `robot:exclude` | test is excluded from execution entirely |
| `robot:skip` | test is skipped (value is the skip reason) |
| `robot:noncritical` | failure does not fail the suite |

### Test Tags vs deprecated settings

`Test Tags` replaces both `Force Tags` and `Default Tags` (deprecated since RF
6.0). Use `Test Tags` in new code.

## Argument Files

When command lines grow large, use argument files:

```
# args/dev.args
--variable    ENV:dev
--variable    DB_HOST:localhost
--include     smoke
--outputdir   results/dev
--loglevel    DEBUG
```

Invoke with:

```bash
robot --argumentfile args/dev.args tests/
```

Multiple argument files can be combined. Lines starting with `#` are comments.
Environment variables expand inside them.

## Parallel Execution

Robot Framework itself is single-threaded. For parallel runs, use `pabot`:

```bash
pabot --processes 4 tests/
pabot --processes 4 --testlevelsplit tests/
```

`pabot` splits suites or tests across processes and merges outputs afterward.
Tag selection and variable passing work as with `robot`.

## Rebot

Use `rebot` when you need to:

- regenerate reports/logs
- combine outputs
- merge outputs
- reshape the reporting layer after execution

```bash
rebot results/output.xml
rebot --output merged.xml results1.xml results2.xml
```

Use combine/merge intentionally:

- combine when collecting separate runs into one report set
- merge when later results should augment earlier outputs for the same suites

## Debugging Pattern

When a suite fails:

1. reproduce with the narrowest selection possible
2. check whether the failure is syntax, missing import, variable issue, or
   runtime/library behavior
3. run dry run if the structure may be wrong
4. inspect logs and the exact failing keyword path
5. only then refactor keywords or libraries

If you are changing both suite and library code, validate the suite shape first
with `--dryrun` before blaming runtime behavior.

## Good Agent Behavior

- emit the exact command used
- choose small targeted runs while iterating
- do not claim semantic correctness from `--dryrun`
- keep result directories explicit if multiple runs are involved
- mention whether the run executed tests or only validated structure
