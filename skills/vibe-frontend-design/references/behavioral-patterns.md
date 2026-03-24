# Human Behavioral Patterns for UI Design

*Extracted from "Designing Interfaces" (Tidwell, Brewer, Valencia)*

This reference documents 13 recurring human behavioral patterns that interfaces should support. Unlike UI component patterns, these are descriptions of how people commonly think and act when using software. Design should accommodate them through interface choices, architecture, features, and documentation.

---

## 1. Safe Exploration

**Core Desire:** "Let me explore without getting lost or getting into trouble."

People learn interfaces more readily when experimentation is low-risk. Exploration fails when errors have disproportionate costs, even if those costs are merely irritating.

### Why It Works

Exploration is a natural learning strategy. If users can try actions, inspect outcomes, and reverse mistakes, they build confidence and understanding. If every misstep feels costly, they become cautious and learn less.

### Discouraging Consequences

- Unexpected pop-ups
- Erased data
- Disruptive auto-playing media
- Broken navigation expectations

### Design Requirements

- Make action consequences legible
- Make mistakes reversible wherever possible
- The lower the perceived cost of a wrong action, the more likely users will explore

### Supported Usability Heuristics

- Visibility of system status
- Match between system and real world
- User control and freedom

### Examples

- **Image editing with undo:** A photographer applies filters, dislikes the result, and uses Undo repeatedly to return to the prior state. This allows trial without commitment.
- **Predictable web navigation:** A visitor clicks around a homepage knowing the browser Back button will restore the previous state. Predictability lowers the cost of curiosity.

---

## 2. Instant Gratification

**Core Desire:** "I want to accomplish something now, not later."

Users become more confident and engaged when the first moments of use yield a visible success. Early payoff matters disproportionately because it establishes both trust in the product and confidence in the user.

### Typical Blockers

- Registration walls
- Long instructions
- Slow loading
- Advertising interruptions
- Requests for personal data before value is shown

### Design Requirements

1. Predict the likely first task
2. Make that task extremely easy
3. Remove blockers before the user experiences value

### General Principle

**Give value before asking for value in return.** The system should often defer asks such as email address, payment commitment, or profile completion until the user has already experienced usefulness.

### Examples

If the likely first goal is creation, expose the creation surface immediately (blank canvas, visible call to action, tools nearby). If the likely first goal is task completion, make the starting point explicit and obvious.

---

## 3. Satisficing

**Core Attitude:** "This is good enough. I don't want to spend more time learning to do it better."

Users typically do not evaluate every possible option. They scan quickly, notice a plausible action, and try it. Herbert Simon's term **satisficing** describes choosing an option that is sufficient rather than optimal when further analysis costs time or effort.

### Why Satisficing Is Rational

Complex interfaces impose cognitive parsing costs. Reading everything carefully is work. So users use efficient heuristics:

- Scan for a likely option
- Choose the first acceptable path
- Backtrack only if necessary

This behavior depends on Safe Exploration: if mistakes are recoverable, fast guessing is economical.

### Design Implications

1. **Provide clear calls to action.** Tell users where to begin: type here, drag here, tap here.
2. **Make labels short and unambiguous.** Buttons, links, and menu items should support correct first-guess interpretation.
3. **Use layout to communicate meaning.** Position, grouping, and visual form can be processed faster than text.
4. **Make movement and recovery easy.** Wrong first choices are inevitable; return paths should be obvious.

### Persistent Workarounds

Users often continue using an old, merely adequate method even after a better one appears. Once someone has learned Path A, switching to Path B has a cognitive cost:

> Users switch only if: benefit(Path B) > learning cost + habit-breaking cost

Even inefficient behaviors can be rational. Design implication: make the better path's value obvious enough to justify relearning.

### Design Requirements

- Provide escape hatches for recovery from wrong turns
- Reduce visual and conceptual complexity (cluttered interfaces push novices toward suboptimal habits)

---

## 4. Changes in Midstream

**Core Reality:** "I changed my mind about what I was doing."

Users do not always pursue a single stable goal. They may be diverted, discover a better opportunity, or suspend one task to handle another. The interface should support **goal switching** rather than assuming uninterrupted linear progress.

### Design Requirements

1. **Allow branching and lateral movement.** Give users access to alternative pages, functions, and destinations.
2. **Avoid unnecessarily choice-poor environments.** Locking users into a narrow path is justified only when the task truly requires focus or constraint.
3. **Support reentrance.** Users should be able to pause and later resume unfinished work.

### Reentrance

Reentrance means a process can be started, interrupted, and resumed without losing meaningful state.

**Example:** A lawyer begins filling out a form on an iPad, a client arrives, the device is turned off, and later the lawyer returns expecting the entered information still to be there.

### Ways to Support Reentrance

1. **Persist typed values in forms and dialogs.** Preserve partial state so resumption is possible.
2. **Avoid unnecessary modality.** Nonmodal interfaces can be moved aside instead of closed.
3. **Support multiple simultaneous projects.** Builder-style applications can keep several workspaces open.

### Reentrance as State Preservation

A resumable task can be modeled as: `resume point = (task identity, partial inputs, UI state, user intent cues)`

---

## 5. Deferred Choices

**Core Reaction:** "I don't want to answer that now; just let me finish!"

Users resist questions that are not immediately necessary to their current objective, especially when:

- The choice is optional
- The user lacks enough information to answer well
- The answer has no immediate effect
- The interruption delays visible progress

### Examples

- **Overlong registration flows:** A user who only wants to post once may be forced through questions about screen name, email, privacy preferences, avatar, and self-description.
- **New project setup in creative tools:** Some decisions are required early (project name), while others may not yet be knowable (storage destination).
- **Premature metadata requests:** A music-writing tool asking for title, key, and tempo before composition begins asks for decisions that may emerge only through creation.

### Design Rules

1. **Minimize up-front questions.** Ask only what is necessary to proceed.
2. **Mark required versus optional clearly.** Let users skip optional inputs without penalty.
3. **Separate critical from noncritical options.** Present the short list first; hide or defer the long list.
4. **Use good defaults.** Provide a usable starting value when appropriate.
5. **Make deferred fields easy to revisit later.** Provide obvious return paths such as "Edit Project."
6. **Delay identity requests until value has been demonstrated.** Let users browse, shop, or even purchase before account creation if possible.

### Tradeoff: Defaults Are Not Free

Even when the system pre-fills a field, the user must inspect it. The cognitive cost is reduced, not eliminated:

> cost(prefill) < cost(empty field) but cost(prefill) > 0

Defaults are beneficial only when the likelihood of correctness is high enough to justify the user's verification effort.

---

## 6. Incremental Construction

**Core Creative Behavior:** "Let me change this. That doesn't look right; let me change it again. That's better."

People rarely create complex artifacts in a single linear pass. They work iteratively:

- Create a partial version
- Inspect it
- Test it
- Revise it
- Branch or restart if needed

This process can be top-down or bottom-up, forward-moving or backtracking, composed of many small edits rather than a few large ones.

### Core Loop for Builder Interfaces

`edit → preview/test → evaluate → revise`

A strong builder interface minimizes the latency in this cycle.

### Design Requirements

1. **Make small edits easy.** Users think in partial experiments, not just finished wholes.
2. **Keep save and change operations lightweight.** If committing progress is costly, experimentation declines.
3. **Provide constant feedback on the whole artifact.** Local edits are judged against global coherence.
4. **Minimize compile/render/test delay.** Waiting breaks concentration and discourages iteration.

### Flow State

When tools support incremental work well, users may enter **flow**: deep, sustained absorption in the task where time fades and the activity becomes intrinsically rewarding. Poor tools disrupt flow because they force attention back onto the tool itself.

Even a delay of about half a second can break concentration after a small change.

### Loop Duration

The quality of a builder tool can be approximated by: `T_loop = T_edit + T_system_response + T_evaluation`

As system response time grows, the user's cognitive continuity degrades.

---

## 7. Habituation

**Core Expectation:** "That gesture works everywhere else; why doesn't it work here, too?"

Repeated use turns many actions into reflexes: Ctrl-S to save, browser Back to return, Return to confirm dialogs, standard touch gestures on mobile devices.

Habituation improves efficiency because users no longer consciously deliberate before acting. But it also makes inconsistency dangerous.

### Benefits

- Faster operation
- Reduced cognitive load
- Smoother expert performance
- Support for flow

### Risks

If a familiar action fails—or worse, triggers something destructive—in a special mode or exceptional context, the user must suddenly re-engage cognitively and perhaps repair damage.

### Design Rules

1. **Honor cross-application conventions when they are established.** Example: Ctrl-X, Ctrl-V, Ctrl-S.
2. **Maintain consistency within the application.** Avoid cases where the same gesture usually means Action X but in one mode means Action Y.
3. **Ensure mobile gestures do expected things.** Users generalize gesture behavior across apps on a platform.

### Confirmation Dialogs Often Fail Because of Habituation

If users repeatedly perform intended actions that trigger a confirmation dialog, dismissing the dialog becomes automatic. Then the dialog no longer forces reflection when it truly matters:

> More frequent confirmations → less protective power

One workaround: randomizing button locations so users must read before clicking. Better solution: avoid routine confirmation dialogs unless the stakes truly justify them.

---

## 8. Microbreaks

**Core Situation:** "I'm waiting for the train. Let me do something useful for two minutes."

People often interact with software during brief fragments of downtime. This is especially important on mobile devices because they are immediately accessible.

### Typical Microbreak Activities

- Checking email
- Reading feeds
- Scanning news
- Watching a short video
- Quick web search
- Reading a book
- Playing a short game

### Design Requirements for Microbreak Support

1. **Fast launch.** Reach useful activity almost immediately.
2. **Fast content loading.** Fresh, readable content should appear quickly.
3. **Retained authentication.** Avoid repeated sign-in prompts.
4. **State restoration.** Resume books, videos, games, and other activities where the user left off.
5. **Efficient triage tools.** Show enough per item for quick decisions and allow rapid star/delete/respond actions.

### Engineering Implication

The first screen matters disproportionately. Especially for feed-based apps, useful content must appear immediately; delays destroy the value proposition of the microbreak.

---

## 9. Spatial Memory

**Core Reaction:** "I swear that button was here a minute ago. Where did it go?"

People often remember **where** things are rather than what they are called. Spatial memory is especially strong when users themselves arrange items or repeatedly encounter them in fixed positions.

### Examples

- Files on a desktop
- Predictable button placement in dialog boxes
- Toolbar item locations
- Swipable mobile screens positioned "off to the side"

### Design Consequences

1. **Keep important controls in stable locations.** Location itself becomes part of the retrieval cue.
2. **Be careful with responsive enabling or dynamic insertion.** Filling blank space is usually harmless; moving existing controls may disrupt recall.
3. **Let users arrange objects when practical.** Self-arrangement strengthens memory for position.
4. **Avoid dynamic menu reordering unless clearly beneficial.** "Helpful" compaction or reordering can destroy learned navigation patterns.
5. **Keep navigation menus stable across pages.** Consistency supports both habituation and spatial recall.

### Cognitive Privilege

Beginning and end positions are cognitively privileged: items at the start or end of lists and menus are more noticeable and memorable than items in the middle.

---

## 10. Prospective Memory

**Core Strategy:** "I'm putting this here to remind myself to deal with it later."

Prospective memory is remembering to do something in the future by leaving cues in the environment. People routinely compensate for imperfect memory by arranging reminders externally.

### Examples from Daily Life and Software

- Placing a book by the door
- Leaving an email visible to answer later
- Setting calendar alarms
- Keeping a flagged message in the inbox
- Bookmarks for later reading
- Sticky notes
- Open windows
- Desktop document piles
- Trello cards and Kanban boards

### Important Design Insight

Many software tools support prospective memory not because they were designed explicitly as reminder systems, but because they are flexible and permissive. They allow users to appropriate artifacts for reminder purposes.

**Flexibility is often more valuable than "smart cleanup."**

### What Designers Should Avoid

1. Do not auto-close apparently idle windows
2. Do not automatically clean up files or objects presumed useless
3. Do not auto-organize or auto-sort unless requested

The system may interpret clutter as waste, while the user is using it as a memory aid.

### What Designers Can Do Positively

1. **Retain half-finished forms** to remind users where they left off
2. **Show recently edited objects** to expose unfinished work cues
3. **Provide bookmark-like object lists** to support future-return intentions
4. **Support many workspaces** to let unfinished tasks remain visible or resumable
5. **Create artifacts for unfinished tasks** tied to pending work

---

## 11. Streamlined Repetition

**Core Complaint:** "I have to repeat this how many times?"

When users must perform the same action repeatedly, the interface should compress the work. The goal is to reduce repetition from many manual operations to either one action per instance, or ideally one action for the entire set.

### Examples

- **Find and Replace:** Specify old phrase and new phrase, then perform one click per occurrence with review, or Replace All for a single bulk action
- **Photoshop actions:** A multi-step transformation (resize, crop, brighten, save) recorded once and replayed for many images
- **Shell scripting:** Commands typed once can be recalled, looped, placed into scripts, executed as a single command
- **Other compression tools:** Copy/paste, desktop shortcuts, browser bookmarks, keyboard shortcuts

### General Principle

Repeated work should be transformed from raw repetition into abstraction:

> n repeated operations → parameterized command or reusable procedure

### Why Observation Matters

Users may not report repetitive work because it has become invisible to them. Direct observation reveals repetitive labor that users themselves no longer notice.

---

## 12. Keyboard Only

**Core Demand:** "Please don't make me use the mouse."

Keyboard-only support matters for at least three groups:

- Users with physical difficulty using a mouse
- Expert users minimizing hand travel
- Users relying on assistive technologies that interact through keyboard APIs

A keyboard-accessible system must not reserve any necessary function for mouse-only input.

### Standard Techniques

1. **Keyboard shortcuts, accelerators, mnemonics** (e.g., Ctrl-S) for fast access to common commands
2. **Keyboard list navigation** — Arrow keys and modifiers can move and multiselect items
3. **Tab traversal** — Tab moves focus forward; Shift-Tab moves backward
4. **Keyboard-manipulable controls** — Radio buttons, combo boxes, and similar controls should respond to arrows, Return, or space
5. **Default button** — Return activates the page/dialog's primary "done" action

### Especially Important for Data Entry

In high-throughput forms, moving from keyboard to mouse is costly. Some such systems even advance focus automatically rather than requiring Tab.

### Limitation

Highly spatial tools, such as graphics editors, are harder to make fully keyboard-driven, though not impossible.

---

## 13. Social Media, Social Proof, and Collaboration

**Core Question:** "What did everyone else say about this?"

People are influenced by peers. They are more likely to watch, buy, join, share, comment, or trust when they see that others—especially people they know—have done so. This is **social proof**.

### Effects of Social Design

Adding a social layer can increase:

- Engagement
- Participation
- Virality
- Community formation
- User retention and growth

### Examples of Social Functionality

**User-generated reviews and comments:** These expose the "wisdom of the crowd." Systems can also reward highly valued contributors.

**Social objects:** Posts, images, videos, check-ins, and similar artifacts become focal objects around which sharing, rating, and discussion occur.

**Collaboration:** Modern productivity tools support geographically and temporally distributed work through:

- Discussion threads
- Document review
- Video conferencing
- Live and asynchronous communication
- Status tracking

### Design Implication

Social features are not mere decoration. They can materially affect decision-making, motivation, and belonging. In some software, the social layer is as important as the primary functional layer.

---

## Summary: How These Patterns Connect

These behavioral patterns reinforce one another:

| Pattern | Reinforces |
|---------|-----------|
| Safe Exploration → cheap recovery | enables users to willingly satisfice |
| Instant Gratification | makes first satisficing choice more likely to succeed |
| Deferred Choices | preserves momentum by minimizing early interruptions |
| Incremental Construction | supports trial-and-error learning when combined with reversibility |
| Habituation + Spatial Memory | together create efficient expert performance |

### The Four-Part Foundation

Successful interaction design rests on four linked elements:

1. **Context** — who the users are, what domain they inhabit, and what skill they bring
2. **Goals** — what outcomes, tasks, and workflows the software should support
3. **Research** — how those users and goals are discovered empirically
4. **Behavioral patterns** — recurring human tendencies that interfaces should accommodate

---

## References

- Jenifer Tidwell, Charles Brewer, Aynne Valencia — *Designing Interfaces*, pattern-based interaction design for screen interfaces
- Jakob Nielsen — usability heuristics including visibility, match, and user control
- Herbert Simon — satisficing: people rationally settle for adequate methods when switching costs exceed expected gains
- Steve Krug — users avoid unnecessary cognitive effort; interfaces should minimize thinking before acting
- Mihaly Csikszentmihalyi — creative work becomes deeply engaging when tools support uninterrupted flow
- Christian Crumlish and Erin Malone — social interfaces harness participation, social proof, and group interaction as core UX forces
