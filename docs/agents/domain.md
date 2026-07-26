# Domain Docs

This file describes how engineering skills consume the repository’s domain documentation.

## Before exploring, read these

- `CONTEXT.md` at the repository root.
- `CONTEXT-MAP.md` at the root if it exists; it points to context-specific `CONTEXT.md` files.
- Relevant ADRs under `docs/adr/`.

If these files do not exist, proceed silently. Do not require them to be created before normal development. The domain-modeling workflow creates them when terminology or architectural decisions need to be recorded.

## File structure

VoxFlow uses a single-context layout:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-example-decision.md
│       └── 0002-example-decision.md
└── lib/
```

`CONTEXT.md` contains the shared domain vocabulary and model. `docs/adr/` contains repository-wide architectural decisions.

## Use the glossary’s vocabulary

When naming a domain concept in issue titles, proposals, hypotheses, tests, or implementation notes, use the terminology defined in `CONTEXT.md`.

If a required concept is absent, reconsider whether the new term is necessary or record the gap for the domain-modeling workflow.

## Flag ADR conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly instead of silently overriding the decision:

> Contradicts ADR-0007, but may be worth reopening because…
