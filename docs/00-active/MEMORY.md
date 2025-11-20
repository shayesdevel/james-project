# Project Memory - james-project

**Purpose**: Track architectural decisions, trade-offs, and constraints so future agents/developers understand WHY things are the way they are
**Format**: Lightweight decision log (ADR-style)
**Audience**: All agents, future maintainers
**Last Updated**: 2025-11-20

---

## How to Use This File

**For AI Agents**:
- Read this file when starting a new session
- Add new decisions when making significant architectural choices
- Update status when revisiting past decisions

**For Humans**:
- Document major decisions here
- Link to detailed discussions (PRs, issues, session journals)
- Keep it current - archive old decisions to ARCHITECTURE.md

---

## Decision Log

### MEM-001: Framework Selection
**Date**: 2025-11-20
**Status**: ACCEPTED
**Deciders**: shayesdevel
**Category**: [ARCHITECTURE]

**Decision**: Use cognitive-framework v2.2 for multi-agent orchestration

**Context**:
- Documentation project needs organized structure for spike findings and diagrams
- Multi-agent approach allows parallel work on documentation and visuals
- Framework provides proven patterns for coordination and quality gates

**Consequences**:
- ✅ **Positive**: 2x velocity from parallel work (scribe + diagram), structured documentation
- ⚠️ **Negative**: Framework overhead for small documentation project
- 🔧 **Mitigation**: Minimal agent roster (3 total), no worktree complexity

**Related**:
- Framework: `../cognitive-framework/`
- Setup session: `docs/00-active/journal/session-01.md`

---

### MEM-002: Agent Roster (Documentation-Focused)
**Date**: 2025-11-20
**Status**: ACCEPTED
**Deciders**: orchestrator + shayesdevel
**Category**: [ARCHITECTURE]

**Decision**: Use minimal agent roster (orchestrator + scribe + diagram) instead of full software development roster

**Context**:
- Project is documentation-focused, not code development
- Need organized documentation (scribe) and visual diagrams (diagram agent)
- No need for backend, frontend, testing, database agents from software development domain

**Consequences**:
- ✅ **Positive**: Lower overhead, faster setup, appropriate for documentation project
- ⚠️ **Negative**: Limited to documentation tasks (not a software project)
- 🔧 **Mitigation**: Clear scope - this is for documenting spike findings, not building software

**Alternatives Considered**:
1. **Full software development roster**: Too complex for documentation project
2. **Single agent**: Would sacrifice parallel work benefits (scribe + diagram in parallel)
3. **Custom domain agents**: Considered but documentation + diagram agents cover needs

**Related**:
- Agent roster: `../../CLAUDE.md` (Agent Roster section)
- Framework domain guide: `../cognitive-framework/DOMAIN_SELECTION.md`

---

### MEM-003: No Worktree Isolation
**Date**: 2025-11-20
**Status**: ACCEPTED
**Deciders**: orchestrator
**Category**: [PROCESS]

**Decision**: Disable D013 worktree isolation for this project

**Context**:
- Documentation project with only 2 core agents (scribe, diagram)
- Clear domain separation: scribe owns `docs/authentication/`, diagram owns `docs/diagrams/`
- Minimal risk of file conflicts given distinct work areas

**Consequences**:
- ✅ **Positive**: Simpler setup, no worktree management overhead, faster onboarding
- ⚠️ **Negative**: Potential conflicts if agents overlap (unlikely given domains)
- 🔧 **Mitigation**: Orchestrator coordinates, clear domain boundaries enforced

**Alternatives Considered**:
1. **Enable worktree isolation**: Overkill for documentation project with clear domains
2. **Hybrid approach**: Some agents in worktrees - adds complexity without benefit

**Related**:
- D013 protocol: `../cognitive-framework/cognitive-core/quality-collaboration/protocols/D013.md`
- Worktree strategy: `../../CLAUDE.md` (Worktree Strategy section)

---

## Decision Status Definitions

**PROPOSED**: Decision suggested but not yet accepted
**ACCEPTED**: Decision made and active
**DEPRECATED**: Decision no longer valid but kept for history
**SUPERSEDED**: Decision replaced by newer decision (link to new one)

---

## Decision Categories

Tag decisions with categories for easier navigation:

**[ARCHITECTURE]**: System structure, patterns, coordination
**[TECH_STACK]**: Technology choices (languages, frameworks, tools)
**[PROCESS]**: Development workflows, quality gates, protocols
**[CONSTRAINTS]**: Hard/soft constraints, non-negotiables
**[TRADE-OFFS]**: Explicit trade-offs accepted

---

## Quick Reference: Recent Decisions

| ID | Date | Title | Status | Category |
|----|------|-------|--------|----------|
| MEM-001 | 2025-11-20 | Framework Selection | ACCEPTED | [ARCHITECTURE] |
| MEM-002 | 2025-11-20 | Agent Roster (Documentation-Focused) | ACCEPTED | [ARCHITECTURE] |
| MEM-003 | 2025-11-20 | No Worktree Isolation | ACCEPTED | [PROCESS] |

---

## Archived Decisions

{When MEMORY.md grows too large, move old ACCEPTED decisions to ARCHITECTURE.md}

Moved to ARCHITECTURE.md:
- MEM-XXX: {Title} ({DATE}) - See ARCHITECTURE.md section {REFERENCE}

---

## Templates for Common Decision Types

### Architecture Decision Template
```markdown
### MEM-XXX: {Decision Title}
**Date**: {DATE}
**Status**: ACCEPTED
**Deciders**: {WHO}
**Category**: [ARCHITECTURE]

**Decision**: {What we decided}

**Context**: {Why we needed to decide}

**Consequences**:
- ✅ Positive: {Benefits}
- ⚠️ Negative: {Trade-offs}
- 🔧 Mitigation: {How we handle negatives}

**Alternatives**:
1. {Alt 1}: {Why not}
2. {Alt 2}: {Why not}

**Related**: {Links}
```

### Technology Choice Template
```markdown
### MEM-XXX: {Tech Choice}
**Date**: {DATE}
**Status**: ACCEPTED
**Category**: [TECH_STACK]

**Decision**: Use {TECHNOLOGY} for {PURPOSE}

**Context**:
- Problem: {What needed to be solved}
- Requirements: {Must-haves}
- Constraints: {Limitations}

**Why {TECHNOLOGY}**:
- {Reason 1}
- {Reason 2}
- {Reason 3}

**Alternatives Evaluated**:
| Technology | Pros | Cons | Why Not Chosen |
|------------|------|------|----------------|
| {Alt 1} | {Pros} | {Cons} | {Reason} |
| {Alt 2} | {Pros} | {Cons} | {Reason} |

**Migration Path**: {If replacing existing tech, how to migrate}
```

### Process Decision Template
```markdown
### MEM-XXX: {Process Change}
**Date**: {DATE}
**Status**: ACCEPTED
**Category**: [PROCESS]

**Decision**: {New process or workflow}

**Context**: {Why change was needed}

**Implementation**:
- {Step 1}
- {Step 2}
- {Step 3}

**Success Metrics**: {How we know it's working}

**Rollback Plan**: {If it doesn't work}
```

---

## Lessons Learned

{Document significant lessons that aren't full decisions but worth remembering}

### Lesson 1: {Title}
**Date**: {DATE}
**Context**: {What happened}
**Lesson**: {What we learned}
**Action**: {What we changed}
**Related**: {Link to session journal or issue}

---

## Anti-Patterns to Avoid

{Document things we tried that didn't work}

### ❌ {Anti-Pattern Name}
**Tried**: {When}
**Problem**: {What went wrong}
**Never Again**: {Why}
**Instead Do**: {Correct approach}

---

## Future Considerations

{Things we're not deciding now but should revisit}

### Future-001: {Consideration}
**Why Deferred**: {Reason}
**Revisit When**: {Condition - e.g., "When we reach 10 agents"}
**Context**: {What we know now}
**Options**: {Potential approaches when we revisit}

---

## Changelog

**2025-11-20**: Project initialized with cognitive-framework v2.2
- Created MEM-001: Framework Selection
- Created MEM-002: Agent Roster (Documentation-Focused)
- Created MEM-003: No Worktree Isolation
- Established minimal agent roster (orchestrator, scribe, diagram)
- Disabled worktree isolation for documentation project
