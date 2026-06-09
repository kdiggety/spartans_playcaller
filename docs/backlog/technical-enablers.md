# Technical Enablers Backlog

## Promote persist() throws across all PlayLibraryStore callers

`save()`, `delete(at:)`, and `deleteAll()` currently swallow persist errors with `print`. Promote to propagate the error so the UI can surface it.

**Trigger:** When adding coach feedback/error surfaces to non-edit paths (e.g., save confirmation animation).

**Source:** library-edit-delete implementation plan, Task 7 backlog requirement.
