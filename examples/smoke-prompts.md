# Smoke prompts (subagent delegation verification)

Run these from Claude Code with this repo as the project root.

---

## 1) Architecture review

```
Use the architecture-system-design subagent to review the current MVVM structure and recommend whether the DiagramRenderer should be a protocol-based abstraction for testability.
```

## 2) Security review

```
Use the security-engineer subagent to check whether any user input paths (route digit text field) could produce unexpected behavior or crashes.
```

## 3) SDET — test strategy

```
Use the sdet subagent to propose a test strategy for the PlayCallParser and ConceptMatcher services. Focus on edge cases in side-aware route interpretation.
```

## 4) Product ownership

```
Use the product-owner subagent to draft 3 backlog items for the next iteration, prioritized by coaching workflow value.
```

## 5) Technical research

```
Use the technical-researcher subagent to compare Canvas vs Path-based rendering approaches for animated route playback in SwiftUI.
```
