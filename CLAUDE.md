# james-project

**Purpose**: Document spike findings and create authentication flow diagrams for James
**Tech Stack**: Documentation-focused (Markdown, Mermaid diagrams, PlantUML)
**Framework**: cognitive-framework v2.2 (Nov 2025)
**Status**: Development

---

## Quick Orient

**What**: Documentation project to capture authentication spike findings and create visual flow diagrams
**Who**: James (internal development team)
**Architecture**: Multi-agent cognitive framework with 3 specialist agents coordinated by orchestrator

---

## Cognitive Architecture Overview

This project uses the **cognitive-framework** for multi-agent orchestration. Multiple specialist AI agents work in parallel, each with domain expertise, coordinated by an orchestrator agent.

### Framework Version & Patterns

**Framework**: cognitive-framework v2.2
**Location**: `../cognitive-framework/`
**Active Orchestration Patterns**:
- [x] Parallel domain execution (4x speedup) - Documentation and diagrams in parallel
- [ ] Multi-way audit (4x speedup)
- [x] Research delegation (division of labor) - Scribe organizes, Diagram creates visuals
- [ ] Time-sensitive updates (2.1x speedup)
- [ ] Epic closure (2x speedup)
- [ ] Wave-based execution (1.3-1.5x speedup)

**Check active patterns in**: `docs/00-active/ARCHITECTURE.md`

---

## Agent Roster

### Tier 0: Orchestrator
**Agent**: orchestrator
**Context**: `.claude/agents/orchestrator.md`
**Worktree**: main (shared environment - exclusive control)
**Role**: Coordinates all specialist agents, manages quality gates, orchestrates parallel work

### Tier 1: Core Specialists (Always Active)

**scribe**
- **Context**: `.claude/agents/scribe.md`
- **Worktree**: Not using worktrees (documentation project, minimal conflicts)
- **Domain**: Documentation organization, session journals, decision capture

**diagram**
- **Context**: `.claude/agents/diagram.md`
- **Worktree**: Not using worktrees (documentation project, minimal conflicts)
- **Domain**: Visual diagram creation (Mermaid, PlantUML), authentication flow visualization

### Tier 2: On-Demand Specialists (Activated as needed)

None currently defined (documentation project is minimal complexity)

---

## Protocol Enforcement

This project enforces the following **D-series protocols** from the cognitive framework:

### Critical Protocols (Mandatory)

**D009: Commit Verification**
- **Purpose**: Prevent hallucinations, verify all changes
- **When**: After every commit, before PR
- **Quick Ref**: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/D009-quick-ref.md`
- **Full Protocol**: `../cognitive-framework/cognitive-core/quality-collaboration/protocols/D009.md`

**D012: Git Attribution**
- **Purpose**: Track agent contributions in commit history
- **Format**: `Co-Authored-By: {AgentName} <agent@james-project.com>`
- **Quick Ref**: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/D012-quick-ref.md`

**D013: Worktree Isolation**
- **Purpose**: Enable true parallel work without conflicts
- **Status**: DISABLED (documentation project, minimal conflicts)
- **Quick Ref**: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/D013-quick-ref.md`

**D014: Session End Protocol**
- **Purpose**: Structured handoff between sessions
- **Quick Ref**: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/D014-quick-ref.md`

### Optional Protocols

**D009b: Post-PR Verification**
- **Purpose**: Integration validation after merge
- **Status**: {ENABLED|DISABLED}

---

## Quality Gates

All agents must pass these gates before committing, merging, or completing work:

**Gate 0**: Architecture Completeness (BEFORE starting work)
- [ ] This CLAUDE.md is current and accurate
- [ ] ARCHITECTURE.md documents active patterns
- [ ] Agent roster matches reality

**Gate 1**: Pre-Flight Check (BEFORE starting work)
- [ ] Tools verified
- [ ] Workspace validated
- [ ] Documentation accessible
- [ ] Configuration valid

**Gate 2**: During Development (Continuous)
- [ ] File hygiene maintained
- [ ] Testing as you go
- [ ] Documentation updated

**Gate 3**: Pre-Commit Verification (BEFORE git commit)
- [ ] All tests pass
- [ ] Code reviewed
- [ ] D009 verification completed

**Gate 4**: Pre-PR Quality (BEFORE creating PR)
- [ ] Integration tests pass
- [ ] Documentation complete
- [ ] Conflicts resolved

**Full Gates**: `docs/00-active/quality-gates.md`

---

## Project Structure

```
james-project/
├── .claude/
│   ├── agents/               ← Agent context files
│   ├── hooks/                ← Session hooks
│   └── settings.json         ← Claude Code configuration
├── docs/
│   ├── 00-active/
│   │   ├── ARCHITECTURE.md   ← Architecture decisions
│   │   ├── MEMORY.md         ← Decision history
│   │   ├── quality-gates.md  ← Quality checkpoints
│   │   └── journal/          ← Session history
│   ├── 01-archive/           ← Completed sessions
│   ├── authentication/       ← Authentication spike findings
│   └── diagrams/             ← Visual flow diagrams (Mermaid, PlantUML)
├── framework-config.json     ← Framework settings
└── CLAUDE.md                 ← This file
```

---

## Worktree Strategy

**Status**: NOT_USING_WORKTREES

**Rationale**:
- Documentation-focused project with minimal file conflicts
- Only 2 core agents (scribe, diagram) working in separate domains
- Scribe focuses on markdown docs, Diagram focuses on diagram files
- Clear domain separation makes worktree overhead unnecessary

**Conflict Prevention**:
- Scribe owns `docs/authentication/` directory
- Diagram owns `docs/diagrams/` directory
- Orchestrator coordinates integration

---

## Supporting Documentation

### Architecture & Decisions
- **ARCHITECTURE.md**: `docs/00-active/ARCHITECTURE.md` - How agents coordinate, which patterns are active
- **MEMORY.md**: `docs/00-active/MEMORY.md` - Architectural decisions, trade-offs, constraints
- **Quality Gates**: `docs/00-active/quality-gates.md` - Mandatory checkpoints

### Framework References
- **Framework Root**: `../cognitive-framework/`
- **Orchestration Patterns**: `../cognitive-framework/cognitive-core/orchestration/patterns/`
- **Protocols**: `../cognitive-framework/cognitive-core/quality-collaboration/protocols/`
- **Quick References**: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/`

### Session History
- **Active Journal**: `docs/00-active/journal/` - Current session notes
- **Archive**: `docs/01-archive/` - Completed sessions

---

## Common Workflows

### Starting New Session (Any Agent)
1. Read latest session journal: `docs/00-active/journal/session-{N}.md`
2. Check quality gates: `docs/00-active/quality-gates.md`
3. Review MEMORY for recent decisions: `docs/00-active/MEMORY.md`
4. Run Gate 0 validation (architecture completeness)
5. Run Gate 1 validation (pre-flight check)
6. Begin work

### Creating Feature (Specialist Agent)
1. Receive task from orchestrator
2. Work in assigned worktree (if using worktree isolation)
3. Follow TDD: test → code → verify
4. Run Gate 2 checks continuously
5. Run Gate 3 before commit (D009 verification)
6. Create PR with agent attribution (D012)
7. Handoff to orchestrator

### Orchestrating Multi-Agent Work (Orchestrator Only)
1. Break epic into domain-specific tasks
2. Delegate to specialist agents (parallel when possible)
3. Monitor progress via agent updates
4. Coordinate merges and integration
5. Run D009b post-PR verification
6. Update session journal

### Ending Session (Any Agent)
1. Complete current work or reach stopping point
2. Run D014 session end protocol
3. Update session journal with progress
4. Document any decisions in MEMORY.md
5. Create handoff notes for next session

---

## Onboarding New Agents

### For AI Agents
1. **Read this file first** (CLAUDE.md) - understand project architecture
2. **Read ARCHITECTURE.md** - understand coordination patterns
3. **Read MEMORY.md** - understand recent decisions
4. **Read quality-gates.md** - understand mandatory checkpoints
5. **Read latest session journal** - understand current state
6. **Review your agent context** - `.claude/agents/{your-agent}.md`
7. **Run Gate 0 and Gate 1** - verify setup before starting

### For Human Developers
1. Read CLAUDE.md (this file)
2. Review ARCHITECTURE.md for coordination model
3. Check MEMORY.md for major decisions
4. Review recent session journals for context
5. Ask orchestrator for current priorities

---

## Issue Tracking & Communication

**Platform**: GitHub
**Repository**: https://github.com/shayesdevel/james-project
**Project Board**: N/A (small documentation project)

**Communication Channels**:
- Session journals: `docs/00-active/journal/`
- GitHub issues/PRs: https://github.com/shayesdevel/james-project

---

## Metrics & Velocity

**Target Setup Time**: <30 minutes (framework v2.2)
**Active Patterns**: 2 orchestration patterns (Parallel domain execution, Research delegation)
**Parallel Agents**: 2 Tier 1 agents (can work simultaneously)
**Expected Velocity**: 2x speedup from parallelization (scribe + diagram work in parallel)

---

## Key Constraints & Trade-offs

Document in `docs/00-active/MEMORY.md`, but quick summary:

- **Worktree isolation**: Disabled (documentation project, clear domain separation)
- **Agent count**: 3 agents (orchestrator + scribe + diagram) - minimal for documentation needs
- **Tech stack choices**: Markdown + Mermaid/PlantUML for portability and simplicity
- **Framework patterns**: Parallel execution and research delegation for 2x velocity

---

## Version Info

**Project Version**: 1.0
**Framework Version**: v2.2
**Last Updated**: 2025-11-20
**Last Updated By**: orchestrator

---

## Emergency Contacts & Escalation

**Framework Issues**: https://github.com/shayesdevel/cognitive-framework/issues
**Project Lead**: shayesdevel
**Escalation Path**: GitHub issues on james-project repo
