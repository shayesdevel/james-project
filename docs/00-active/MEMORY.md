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

### MEM-004: Groups Assign Roles Pattern
**Date**: 2025-11-20
**Status**: ACCEPTED
**Deciders**: James + orchestrator
**Category**: [ARCHITECTURE]

**Decision**: Use "groups assign business roles" pattern for Keycloak authorization model

**Context**:
- Need to determine relationship between groups (External/Internal/Services) and business roles (User/Manager/Admin)
- Current broken state: Group A/B assign dozens of service roles with no business role mapping
- Target state: Meaningful groups with business role assignments

**Consequences**:
- ✅ **Positive**: Clear ownership and auditability, least privilege by default, simple to understand
- ✅ **Positive**: External Users can only be User role (reduces risk), Internal Users have flexibility
- ⚠️ **Negative**: Less flexible than separate dimensions (can't be External + Manager)
- 🔧 **Mitigation**: Business requirements fit this model (External users are customers, not managers)

**Alternatives Considered**:
1. **Separate dimensions**: Users independently assigned groups AND roles - too complex, harder to audit
2. **Nested hierarchy**: External Users can only be User, Internal Users only Manager/Admin - too rigid
3. **Roles-only (no groups)**: Every user directly assigned roles - loses organizational grouping benefits

**Related**:
- Design doc: `docs/authentication/03-target-design/group-role-mapping.md`
- Session journal: `docs/00-active/journal/session-02.md`

---

### MEM-005: Phased Authorization Granularity
**Date**: 2025-11-20
**Status**: ACCEPTED
**Deciders**: James + orchestrator
**Category**: [ARCHITECTURE]

**Decision**: Phase 1 implements service-level access only; Phase 2 adds controller-level granularity later

**Context**:
- Need to balance simplicity with future flexibility
- Service-level access: Business role grants access to entire microservice (simple)
- Controller-level access: Business role + permissions grant access to specific endpoints (granular)

**Consequences**:
- ✅ **Positive**: Phase 1 solves 80% of over-permissioning problem with 20% complexity
- ✅ **Positive**: Reduces migration timeline and scope
- ✅ **Positive**: Phase 2 can build on Phase 1 foundation (non-breaking)
- ⚠️ **Negative**: Temporary lack of endpoint-level granularity
- 🔧 **Mitigation**: Service-level access still enforces meaningful boundaries (User vs Manager vs Admin)

**Phase 1**: Manager role → access to reports-service (all endpoints)
**Phase 2**: Manager role + "reports:read" permission → GET /reports (specific endpoint)

**Related**:
- Simple design: `docs/authentication/03-target-design/simple-workflow-overview.md`
- Session journal: `docs/00-active/journal/session-02.md`

---

### MEM-006: 30-Week Phased Migration Strategy
**Date**: 2025-11-20
**Status**: ACCEPTED
**Deciders**: orchestrator
**Category**: [PROCESS]

**Decision**: 6-phase migration over 30 weeks with dual-mode operation supporting both old and new authorization models

**Context**:
- Zero downtime requirement for 15+ microservices
- Cannot "big bang" switch from Group A/B to new model
- Need rollback capability at every phase
- Users and services must migrate independently

**Implementation**:
- **Phase 0** (2 weeks): Pre-migration prep (audit, mapping, test environments)
- **Phase 1** (2 weeks): Keycloak setup (create groups, roles, token mappers)
- **Phase 2** (8 weeks): Dual-mode deployment (services accept both old and new auth)
- **Phase 3** (8 weeks): User migration (move users to new groups, add business roles to tokens)
- **Phase 4** (8 weeks): Service migration (remove old auth checks, Keycloak-only)
- **Phase 5** (2 weeks): Cleanup (remove Group A/B, reduce token size)

**Success Metrics**:
- Zero downtime throughout migration
- <1% authorization error rate
- 85% token size reduction (Phase 5)
- All 15+ services migrated successfully

**Rollback Plan**:
- Phases 2-3: <30 minutes (feature flag disable)
- Phase 4: 2-4 hours (redeploy dual-mode code)
- Phase 5: 1-3 days (restore from backup - delayed until 4+ weeks stable)

**Related**:
- Migration plan: `docs/authentication/04-migration-plan/migration-phases.md`
- Rollback strategy: `docs/authentication/04-migration-plan/rollback-strategy.md`
- Session journal: `docs/00-active/journal/session-02.md`

---

### MEM-007: Kong Architecture Verification Deferred
**Date**: 2025-11-20
**Status**: ACCEPTED
**Deciders**: orchestrator + James
**Category**: [CONSTRAINTS]

**Decision**: Flag Kong's exact role for verification; continue with documentation work that doesn't depend on Kong specifics

**Context**:
- James indicated Kong does "some" of what diagrams show, not everything
- Request flow position unclear (Kong before React UI?)
- SSL/TLS handling and x.509 certificate validation issues noted
- Exact capabilities uncertain: routing, token validation, role-based authz?

**Consequences**:
- ✅ **Positive**: Maintains momentum on documentation work
- ✅ **Positive**: Transparent about assumptions (verification notes on all diagrams)
- ⚠️ **Negative**: Issue #3 (spike findings) incomplete until Kong verified
- 🔧 **Mitigation**: All diagrams flagged with verification warnings, revisit when James available

**Verification Needed**:
- Kong's exact position in request flow
- What Kong does: routing, validation, authorization
- SSL/TLS termination and x.509 certificate handling
- Integration points with Keycloak and microservices

**Related**:
- Diagrams with notes: `docs/diagrams/current-state/current-auth-flow.md`
- Session journal: `docs/00-active/journal/session-02.md`
- Issue #3: https://github.com/shayesdevel/james-project/issues/3 (blocked on Kong verification)

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
| MEM-007 | 2025-11-20 | Kong Architecture Verification Deferred | ACCEPTED | [CONSTRAINTS] |
| MEM-006 | 2025-11-20 | 30-Week Phased Migration Strategy | ACCEPTED | [PROCESS] |
| MEM-005 | 2025-11-20 | Phased Authorization Granularity | ACCEPTED | [ARCHITECTURE] |
| MEM-004 | 2025-11-20 | Groups Assign Roles Pattern | ACCEPTED | [ARCHITECTURE] |
| MEM-003 | 2025-11-20 | No Worktree Isolation | ACCEPTED | [PROCESS] |
| MEM-002 | 2025-11-20 | Agent Roster (Documentation-Focused) | ACCEPTED | [ARCHITECTURE] |
| MEM-001 | 2025-11-20 | Framework Selection | ACCEPTED | [ARCHITECTURE] |

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

**2025-11-20 (Session 02)**: Authentication redesign spike completed
- Created MEM-004: Groups Assign Roles Pattern
- Created MEM-005: Phased Authorization Granularity (Phase 1 simple, Phase 2 granular)
- Created MEM-006: 30-Week Phased Migration Strategy
- Created MEM-007: Kong Architecture Verification Deferred
- Documented current broken state (Group A/B over-permissioning)
- Designed Phase 1 target model (External/Internal/Services groups → User/Manager/Admin roles)
- Created 6-phase migration plan with dual-mode operation
- Created 18 documentation files and 7 Mermaid diagrams
- GitHub issues #1, #2, #4, #5, #6 completed; #3 pending Kong verification

**2025-11-20 (Session 01)**: Project initialized with cognitive-framework v2.2
- Created MEM-001: Framework Selection
- Created MEM-002: Agent Roster (Documentation-Focused)
- Created MEM-003: No Worktree Isolation
- Established minimal agent roster (orchestrator, scribe, diagram)
- Disabled worktree isolation for documentation project
