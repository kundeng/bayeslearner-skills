# Coding Patterns

Reference for `workflow-guardrails`: language-aware coding discipline —
design heuristics, boundary discipline, honest testing, refactoring rules,
and a short list of Python / TypeScript dos and donts.

Scope:

- cross-language design heuristics
- honest testing and verification patterns
- Python dos and donts
- TypeScript / JavaScript dos and donts

Out of scope:

- deep style guides, lint rule catalogs, or full framework tutorials
- anything already enforced by the project's linter, formatter, or type checker

## Design Heuristics (language-agnostic)

- **KISS.** Prefer the straightforward implementation until a real requirement
  forces complexity.
- **Rule of three.** Do not abstract on the second occurrence. Abstract on the
  third, and only when the shared shape is actually stable.
- **Separation of concerns.** Keep business logic separate from I/O, transport,
  and framework glue. If one function renders HTML, talks to a database, and
  emits metrics, split it.
- **Composition over inheritance.** Reach for inheritance only when there is a
  real is-a relationship with stable behavior.
- **Layered structure.** Favor a clear handler/API -> service -> repository
  shape over a ball of cross-calling modules.
- **Name for the reader.** A good name removes the need for a comment. Use
  comments only to record the non-obvious why.

## Boundary Discipline

- Validate inputs at the trust boundary (user input, API payloads, file data,
  inter-service calls). Do not sprinkle validation through the interior.
- Fail fast with specific errors at the boundary. Do not swallow errors to keep
  the happy path clean.
- Keep the boundary's contract explicit: types, required fields, allowed
  ranges, error shapes.
- Centralize cross-cutting concerns (retries, timeouts, logging, auth) in one
  place per boundary, not at every call site.

## Testing Patterns

- Test the real boundary, not a hallucinated one. If a function hits a database,
  decide consciously whether to exercise the database (integration) or the
  contract only (unit with a fake).
- Test sad paths and edge cases, not just the happy path. Include: empty
  inputs, oversized inputs, invalid types, timeouts, partial failures.
- Do not write empty tests, placeholder assertions, or tests that only check
  that a function runs without raising.
- Avoid over-mocking. If every collaborator is mocked, the test only verifies
  that the code calls mocks in a particular order, not that the behavior is
  correct.
- Prefer fakes or in-memory implementations over mocks when the collaborator
  has meaningful behavior worth exercising.
- For UI or browser flows, use real E2E or integration tooling (Agent Browser,
  Playwright, Cypress) and inspect real rendered state.

## Refactoring Rules

- Keep behavior identical while refactoring; prove it with tests that ran green
  before and after.
- Do not mix a refactor with a behavior change in the same commit.
- Refactor toward: removed duplication, clearer ownership, smaller public
  surface, easier-to-verify next task.
- Do not do drifty cleanup unrelated to the active workstream.

## Python Dos and Donts

Do:

- Use context managers (`with open(...) as f:`) for any resource that must be
  released: files, sockets, DB connections, locks.
- Prefer f-strings and explicit formatting over `%` or `str.format` chains.
- Use `dataclasses`, `TypedDict`, `pydantic`, or `attrs` for structured data
  instead of untyped dicts at boundaries.
- Use type hints on public functions and on any function whose argument shapes
  are not obvious from context.
- Centralize retries and timeouts (e.g., a `tenacity` policy or a wrapper
  class), not copy-pasted loops.
- Prefer `pathlib.Path` over raw string path manipulation.

Do not:

- Use bare `except:` or `except Exception:` without a narrow reason and a
  comment explaining it.
- Call blocking I/O (`requests`, `time.sleep`, sync DB drivers) inside an
  `async def` function. Use the async variant or run it in a thread executor.
- Mutate default mutable arguments (`def f(x=[])`). Use `None` and construct
  inside the body.
- Re-raise exceptions as bare `raise Exception(...)` and lose the stack.
- Mix config, side effects, and import-time work at module top level; prefer a
  small `main()` or factory function.
- Overuse inheritance for code reuse where a helper function or composition
  would do.

## TypeScript / JavaScript Dos and Donts

Do:

- Turn on `strict` (including `strictNullChecks`, `noImplicitAny`) and keep it
  on. Treat type errors as build failures.
- Parse and validate external data at the boundary (e.g., `zod`, `valibot`,
  `io-ts`) and narrow it into a typed domain model.
- Model absence with `undefined` or `null` deliberately; pick one per interface
  and stick with it.
- Use discriminated unions for state shapes
  (`type Result = { kind: "ok", value } | { kind: "err", error }`).
- Await every promise or explicitly mark it ignored. Unawaited promises are a
  common source of silent failures.
- Prefer `const` and immutable patterns; reach for `let` only with a reason.

Do not:

- Use `any`. If you are tempted, reach for `unknown` and narrow, or write a
  precise type.
- Use type assertions (`as Foo`) to paper over a type error you do not
  understand. Fix the type or narrow with a guard.
- Mix `async/await` with `.then()` chains in the same function without a
  reason.
- Swallow rejections with `.catch(() => {})`; log, rethrow, or convert to a
  typed error.
- Rely on truthy/falsy checks for optional-but-meaningful values like `0`,
  `""`, or `false`. Check against `undefined` or `null` explicitly.
- Export mutable module-level state from library code. Wrap it in a factory or
  class if it must exist.

## Concurrency and Async

- Do not hold a lock across an `await` or network call unless you mean to.
- Make timeouts explicit on every outbound network call.
- Cancel or clean up background tasks when the owning scope ends.
- Do not fire-and-forget tasks in long-running services without a registry that
  can observe and shut them down.

## Anti-Patterns

- Premature abstraction built on one or two examples.
- Mixed concerns (HTTP + DB + business rules in one function).
- Tests that only run the code and assert nothing meaningful.
- Tests that mock everything real and assert on call shapes.
- Boundary code with no input validation but heavy interior validation.
- Silent `except`/`catch` blocks that hide the failure from operators.
- Sync-in-async bugs, unawaited promises, unbounded retry loops.
- Inheritance hierarchies used for code reuse rather than real subtype
  relationships.
