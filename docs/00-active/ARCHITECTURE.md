# Architecture Documentation - james-project

**Purpose**: Document how agents coordinate, which patterns are active, and why architectural decisions were made
**Audience**: AI agents, human developers, future maintainers
**Last Updated**: 2025-11-20

---

## Multi-Agent Coordination Model

### Overview

This project uses a **multi-agent cognitive architecture** with 3 specialist agents coordinated by an orchestrator.

**Coordination Style**: Centralized
- **Orchestrator**: Makes high-level decisions, delegates to specialists, integrates work
- **Specialists**: Domain experts working in parallel on documentation and diagrams
- **Integration**: Orchestrator coordinates work, no PR process needed (documentation project)

### Agent Hierarchy

```
Orchestrator (Tier 0)
├── scribe (Tier 1 - Core)
└── diagram (Tier 1 - Core)
```

**Tier 0 (Orchestrator)**:
- Exclusive control of shared environment (main repo)
- Coordinates all specialist work
- Manages quality gates
- Integrates contributions

**Tier 1 (Core Specialists)**:
- Always active
- Work in parallel on their domains (documentation vs diagrams)
- Own their domain's output
- No PR process (collaborative documentation editing)

**Tier 2 (On-Demand Specialists)**:
- None defined (minimal documentation project)

---

## Active Orchestration Patterns

### Pattern Selection Rationale

Document WHY each pattern was chosen for this project.

### ✅ Active Patterns

#### 1. Parallel Domain Execution
**Status**: ACTIVE
**Source**: `../cognitive-framework/cognitive-core/orchestration/patterns/parallel-domain-execution.md`
**Speedup**: 2x (estimated)

**Description**: Scribe and diagram agents work simultaneously on separate domains

**Why chosen**:
- Documentation and diagrams are independent work streams
- Clear domain boundaries (scribe owns `docs/authentication/`, diagram owns `docs/diagrams/`)
- No worktree needed due to clear file separation

**When used**:
- Creating authentication documentation while generating flow diagrams
- Organizing spike findings while creating visual representations

**Evidence**: Will be tracked in session journals

---

#### 2. Research Delegation
**Status**: ACTIVE
**Source**: `../cognitive-framework/cognitive-core/orchestration/patterns/research-delegation.md`
**Speedup**: Division of labor

**Description**: Orchestrator delegates research/organization tasks to specialists

**Why chosen**:
- Scribe specializes in organizing documentation structure
- Diagram specializes in visual representation
- Orchestrator coordinates overall narrative

**When used**:
- Breaking down spike findings into organized documentation
- Creating comprehensive authentication flow documentation

---

### ❌ Considered But Not Used

#### Multi-way Audit
**Status**: NOT ACTIVE
**Reason**: Documentation project, no code review/audit needed

#### Wave-based Execution
**Status**: NOT ACTIVE
**Reason**: Simple dependency graph (documentation → diagrams), no complex waves needed

#### Time-Sensitive Updates
**Status**: NOT ACTIVE
**Reason**: No time-critical data feeds in documentation project

---

## Protocol Enforcement

### Mandatory Protocols

#### D009: Commit Verification
**Status**: ENFORCED
**Coverage**: All commits by all agents
**Automation**: Quality Gate 3
**Failure Mode**: Manual verification required before session end

**Implementation**:
- Agent reviews git diff before committing
- Orchestrator spot-checks agent commits
- No automated script (documentation project)

**Metrics**: Will track in session journals

---

#### D012: Git Attribution
**Status**: ENFORCED
**Format**: `Co-Authored-By: {AgentName} <agent@project.com>`
**Automation**: Git commit template

**Implementation**:
- All agent commits include Co-Authored-By line
- Orchestrator commits may include multiple agents
- Tracked via git log analysis

---

#### D013: Worktree Isolation
**Status**: NOT_USED
**Rationale**: Documentation project with clear domain separation

**Reason**:
- Project too small (3 agents total)
- Clear file boundaries (scribe: `docs/authentication/`, diagram: `docs/diagrams/`)
- Minimal risk of conflicts

**Alternative**:
- Orchestrator coordinates work
- Clear domain boundaries enforced
- Session journals track concurrent work

---

#### D014: Session End Protocol
**Status**: ENFORCED
**Purpose**: Structured handoff between sessions
**Location**: Session journals in `docs/00-active/journal/`

**Required elements**:
- Session summary
- Work completed
- Blockers encountered
- Next steps
- Handoff notes

---

### Optional Protocols

#### D009b: Post-PR Verification
**Status**: {ENABLED|DISABLED}
**Rationale**: {Why}

---

## Architectural Decisions (ADR-Style)

### Decision 1: {Decision Title - e.g., Use Worktree Isolation}
**Date**: {DATE}
**Status**: ACCEPTED
**Deciders**: {Who decided - e.g., Orchestrator + User}

**Context**:
{What was the situation? What problem were we solving?}

**Decision**:
{What did we decide to do?}

**Consequences**:
- **Positive**: {Benefit 1}, {Benefit 2}
- **Negative**: {Trade-off 1}, {Trade-off 2}
- **Mitigation**: {How we handle negative consequences}

**Alternatives Considered**:
1. {Alternative 1}: {Why rejected}
2. {Alternative 2}: {Why rejected}

---

### Decision 2: {Decision Title}
**Date**: {DATE}
**Status**: {PROPOSED|ACCEPTED|DEPRECATED|SUPERSEDED}

{Follow same format as Decision 1}

---

## Domain Boundaries & Responsibilities

### scribe - Documentation Organization
**Responsibility**: Organize and document authentication spike findings in structured markdown

**Domain Boundaries**:
- **Owns**: `docs/authentication/` directory, session journals
- **Collaborates**: With diagram agent on flow descriptions
- **Never touches**: Diagram files in `docs/diagrams/`

**Quality Gates**:
- Must pass: D009 verification, markdown formatting
- Validated by: Orchestrator review

**Key Decisions**:
- MEM-002: Agent Roster (Documentation-Focused)

---

### diagram - Visual Diagram Creation
**Responsibility**: Create authentication flow diagrams using Mermaid and PlantUML

**Domain Boundaries**:
- **Owns**: `docs/diagrams/` directory
- **Collaborates**: With scribe on flow understanding
- **Never touches**: Documentation files in `docs/authentication/`

**Quality Gates**:
- Must pass: D009 verification, diagram syntax validation
- Validated by: Orchestrator review, diagram rendering check

**Key Decisions**:
- MEM-002: Agent Roster (Documentation-Focused)

---

## Coordination Workflows

### Workflow 1: Authentication Documentation Creation
**Scenario**: Document authentication spike findings and create flow diagrams

**Steps**:
1. **Orchestrator**: Breaks work into documentation + diagrams
2. **Parallel Work**:
   - **scribe**: Organizes spike findings into `docs/authentication/`
   - **diagram**: Creates flow diagrams in `docs/diagrams/`
3. **Integration**:
   - Orchestrator reviews both outputs
   - No PR process (direct collaboration)
   - D009 verification by each agent
4. **Validation**:
   - Documentation is complete and organized
   - Diagrams render correctly and match documentation

**Pattern Used**: Parallel Domain Execution + Research Delegation
**Expected Speedup**: 2x vs sequential

---

### Workflow 2: Session Documentation (D014)
**Scenario**: End of session handoff and documentation

**Steps**:
1. **Orchestrator**: Initiates D014 session end protocol
2. **scribe**: Creates session journal in `docs/00-active/journal/`
3. **scribe**: Updates MEMORY.md if architectural decisions were made
4. **All agents**: Review session summary
5. **Orchestrator**: Validates session documentation complete

**Pattern Used**: Research Delegation (scribe handles documentation)
**Frequency**: End of every session (mandatory)

---

## Conflict Resolution Strategy

### Code Conflicts
**Prevention**:
- {How prevented - e.g., Worktree isolation, clear domain boundaries}
- {Communication - e.g., Agents announce PRs in session journal}

**Resolution**:
- {Who resolves - e.g., Orchestrator}
- {How resolved - e.g., Merge in dependency order, coordinate with affected agents}

### Design Conflicts
**Prevention**:
- {How prevented - e.g., Architecture decisions documented in MEMORY.md}
- {Review process - e.g., Orchestrator approves architectural changes}

**Resolution**:
- {Escalation path}
- {Decision authority - e.g., User decides on major architectural shifts}

---

## Quality Assurance Strategy

### Testing Hierarchy
**Unit Tests**:
- **Owner**: Each specialist agent for their domain
- **Coverage Target**: {Percentage}
- **Run Frequency**: Every commit (Gate 3)

**Integration Tests**:
- **Owner**: {Testing agent or orchestrator}
- **Coverage Target**: {Percentage}
- **Run Frequency**: Every PR (Gate 4)

**End-to-End Tests**:
- **Owner**: {Testing agent}
- **Coverage**: {Key user flows}
- **Run Frequency**: {When - e.g., before release}

### Code Review
**Process**:
- All specialist PRs reviewed by orchestrator
- {Additional reviewers if applicable}
- D009 verification mandatory

**Review Criteria**:
- {Criterion 1}
- {Criterion 2}

---

## Technical Constraints

### Hard Constraints
{Things that CANNOT be changed}
- {Constraint 1 - e.g., Must use PostgreSQL (client requirement)}
- {Constraint 2}

### Soft Constraints
{Things that SHOULD NOT be changed without good reason}
- {Constraint 1 - e.g., Prefer Django for consistency}
- {Constraint 2}

---

## Known Limitations

### Current Limitations
1. **{Limitation 1}**: {Description}
   - **Impact**: {How it affects the project}
   - **Workaround**: {If any}
   - **Future**: {Plans to address}

2. **{Limitation 2}**: {Description}

### Technical Debt
{Document significant technical debt}
- {Item 1}: {Why it exists, when to address}
- {Item 2}

---

## Metrics & Monitoring

### Velocity Metrics
{If tracking}
- **Baseline (single agent)**: {Metric}
- **Current (multi-agent)**: {Metric}
- **Speedup**: {Multiplier}

### Quality Metrics
- **Test Coverage**: {Percentage}
- **D009 Verification**: {Pass rate}
- **PR Cycle Time**: {Average}

### Agent Utilization
- **Parallel Sessions**: {Average concurrent agents}
- **Domain Distribution**: {Percentage by domain}

---

## Evolution & Future Considerations

### Planned Changes
{Upcoming architectural shifts}
- {Change 1}: {When, why}
- {Change 2}

### Scalability Considerations
{As project grows}
- {Consideration 1 - e.g., May need database specialist agent}
- {Consideration 2 - e.g., May split frontend into mobile + web agents}

### Framework Upgrades
**Current Framework Version**: v{VERSION}
**Upgrade Path**: {Plan for framework updates}
**Breaking Changes**: {Known issues to watch for}

---

## References

### Framework Documentation
- **Orchestration Patterns**: `{PATH_TO_COGNITIVE_FRAMEWORK}/cognitive-core/orchestration/patterns/`
- **Protocols**: `{PATH_TO_COGNITIVE_FRAMEWORK}/cognitive-core/quality-collaboration/protocols/`
- **Quick References**: `{PATH_TO_COGNITIVE_FRAMEWORK}/cognitive-core/quality-collaboration/quick-reference/`

### Project Documentation
- **Project Overview**: `../../CLAUDE.md`
- **Decision History**: `MEMORY.md`
- **Quality Gates**: `quality-gates.md`
- **Session Journals**: `journal/`

---

## Changelog

**2025-11-20**: Initial architecture documentation
- Documented 2 orchestration patterns (Parallel Domain Execution, Research Delegation)
- Documented 3 architectural decisions (Framework, Agent Roster, No Worktrees)
- Established domain boundaries for 2 core agents (scribe, diagram)
- Configured for documentation-focused project
