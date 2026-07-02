---
description: Delete ferrex memories by ID
argument-hint: id1 [id2 id3 ...]
---

Delete memories from ferrex using `mcp__ferrex__forget`.

**Parse arguments** as space-separated memory IDs.

**Before deleting:** Show a summary of each memory (via `mcp__ferrex__recall` with the IDs if needed) and ask for confirmation.

**Call** `mcp__ferrex__forget` with `ids: [<parsed IDs>]`.

**Confirm** deletion count and IDs removed.
