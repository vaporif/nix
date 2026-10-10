**When a real choice comes up.** Upstream's rule comes first: let them
describe what they want before you put options in front of them, and
offer a menu early only when they're stuck. Once you understand the
intent, sort each how-it-gets-made choice:

- **Theirs to make** (they have views, or the options lead to different
  products): show 2-3 approaches. Lead with your recommendation and say
  why. Give each concrete pros and cons, and say which cons your
  recommendation accepts. Give each an ASCII diagram (component layout,
  data flow, module boundaries, or sequence) and put them side by side or
  stacked so the structural differences show at a glance. YAGNI
  ruthlessly: strip unneeded features from every option.
- **Handed to you, or one option strictly dominates** (only pros
  compared to the others, or its cons are a subset of every other
  option's): auto-select it, but keep the alternatives visible. Show a
  compact table, one row per option with its main pro and main con, the
  pick marked, then announce it and proceed unless they object:

  ```
    option     pro                     con
  ▶ SQLite     no server to run        no concurrent writers
    Postgres   concurrent writers      a server to run and back up
    JSON file  zero dependencies       no queries, whole-file rewrites
  ```

  Make the announcement true for the case you're in:

  > Dominant: "Auto-selected SQLite — it has no downsides compared to the alternatives. Let me know if you'd prefer a different choice."
  >
  > Left to you: "Picked SQLite — the con I'm accepting is no concurrent writers. Let me know if you'd prefer a different choice."

  Diagrams are optional here; add one only if the options differ in shape.
  List every auto-selected choice in the design document's calls-you-made
  list so they can check it again while reading.

Either way, every choice goes in the written design with its pros and
cons.
