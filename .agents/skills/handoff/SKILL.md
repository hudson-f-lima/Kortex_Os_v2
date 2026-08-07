---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

When the task created or changed documentation, a decision, or an issue, append this exact section to the handoff:

```text
DOCUMENTATION_CHECK:
- [ ] O novo documento atende ao padrão Diátaxis (ou a exceção histórica foi registrada)?
- [ ] O frontmatter YAML foi preenchido quando aplicável?
- [ ] O docs/INDEX.md foi atualizado quando houve novo documento, estado ou navegação?
- [ ] Alguma ADR ou DEC foi criada, afetada ou superada?
```

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
