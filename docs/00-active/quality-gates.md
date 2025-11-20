# Quality Gates - james-project

**Purpose**: Mandatory checkpoints all agents must pass before committing, merging, and completing work.

**Scope**: Applies to ALL agents (Documentation, Research, Diagram, Orchestrator)

**Note**: This project is documentation-focused (spike findings, architecture diagrams, decision logs). Quality gates emphasize documentation completeness, diagram validity, and session journals over code compilation/testing.

---

## Gate 0: Architecture Completeness (BEFORE First Work Session) - NEW v2.2

**When**: Once at project start, or when new agent joins project
**Purpose**: Ensure cognitive architecture is documented and accessible
**Who**: Orchestrator validates once, all agents verify on first session

### Project Documentation Exists
- [ ] Project CLAUDE.md exists and is current:
  ```bash
  ls ../../CLAUDE.md
  ```
- [ ] Contains: Project overview, agent roster, active patterns, protocol enforcement
- [ ] All placeholders (`{PLACEHOLDER}`) replaced with actual values
- [ ] Framework version documented

### Architecture Documentation Exists
- [ ] ARCHITECTURE.md exists and documents coordination model:
  ```bash
  ls ../../docs/00-active/ARCHITECTURE.md
  ```
- [ ] Contains: Multi-agent coordination model, active orchestration patterns
- [ ] Contains: Domain boundaries for all agents
- [ ] Contains: At least 1 architectural decision documented

### Decision History Initialized
- [ ] MEMORY.md exists and has initial decisions:
  ```bash
  ls ../../docs/00-active/MEMORY.md
  ```
- [ ] Contains: MEM-001 (Framework Selection) with date
- [ ] Contains: At least 2-3 setup decisions documented
- [ ] Format correct: Date, Status, Context, Consequences

### Agent Roster Matches Reality
- [ ] Agent roster in CLAUDE.md matches `.claude/agents/` directory:
  ```bash
  # List agents in CLAUDE.md
  grep -A 1 "Agent:" ../../CLAUDE.md

  # List agent contexts
  ls ../../.claude/agents/

  # Should match!
  ```
- [ ] All Tier 1 agents have context files
- [ ] All Tier 2 agents documented (even if not yet created)

### Quality Gates Documented
- [ ] This file (quality-gates.md) is customized for project
- [ ] Validation commands updated for tech stack
- [ ] All placeholders (`{PLACEHOLDER}`) replaced

**If ANY Gate 0 check fails**:
- STOP - architecture is incomplete
- See SETUP_CHECKLIST.md Steps 0.5, 5.5, 6.5
- Complete architecture documentation before starting work
- Re-run Gate 0 after completing documentation

**Why this gate matters**: Without architecture documentation, agents don't know how the project coordinates, which patterns are active, or why decisions were made. This causes 30-60 min of confusion per new agent/session.

---

## Gate 1: Pre-Flight Check (BEFORE Starting Work)

### Tool Verification
- [ ] Required tools installed and accessible:
  ```bash
  # Mermaid CLI for diagram validation (optional but recommended)
  mmdc --version || echo "Mermaid CLI not installed (install: npm install -g @mermaid-js/mermaid-cli)"

  # Markdown link checker (optional)
  markdown-link-check --version || echo "Link checker not installed (install: npm install -g markdown-link-check)"

  # Basic tools
  git --version
  ```

### Workspace Validation
- [ ] Working in correct directory (worktree for specialists, main repo for orchestrator)
- [ ] Verify location: `pwd` shows expected path
- [ ] On correct branch: `git branch --show-current`
- [ ] Clean starting state: `git status` (commit or stash existing changes)

### Documentation Access
- [ ] Can access quality gates: `ls ../../docs/00-active/quality-gates.md`
- [ ] Can access cognitive framework: `ls /home/shayesdevel/projects/cognitive-framework`
- [ ] Can access project docs: `ls ../../docs/00-active`

### Configuration Validation
- [ ] settings.json is schema-compliant (Claude Code official schema):
  ```bash
  # Check no deprecated fields
  ! grep -qE "customShellEnv|shellIntegration" .claude/settings.json

  # Check no framework fields in settings.json (should be in framework-config.json)
  ! grep -qE "projectName|worktreeRoot|issueTracking" .claude/settings.json

  # Check hook keys are PascalCase (not lowercase)
  ! grep -qE '"(session-start|session-end|pre-tool-use)"' .claude/settings.json

  # Validate JSON syntax
  jq empty .claude/settings.json
  ```
- [ ] If settings.json invalid: See `/home/shayesdevel/projects/cognitive-framework/.claude/SETTINGS_CREATION_PROTOCOL.md`
- [ ] Compare with reference: `/home/shayesdevel/projects/cognitive-framework/examples/project-configurations/cerberus/.claude/settings.json`

**If ANY pre-flight check fails: STOP and report error before starting work**

---

## Gate 2: During Documentation Work (Continuous Monitoring)

### File Hygiene (Check with `git status` frequently)
Prevent committing:
- ❌ IDE files: `.idea/`, `.vscode/` (unless project-standard), `.DS_Store`
- ❌ Temporary files: `*.tmp`, `*.swp`, `*~`, `.*.kate-swp`
- ❌ Large binary diagrams: `>500KB` (prefer text-based Mermaid over screenshots)
- ❌ Duplicate files: `file-old.md`, `backup-*.md`, `copy-of-*.md`

**Validation command**:
```bash
# Check for temporary/backup files
git status --porcelain | grep -E "\\.tmp$|\\.swp$|~$|-old\\.|backup-|copy-of-"
```

### Documentation Red Flags
Monitor for these issues while writing:
- ❌ **Broken links**: References to non-existent files or sections
- ❌ **Missing context**: Diagrams/findings without explanation
- ❌ **Vague summaries**: "We decided X" without rationale
- ❌ **Orphaned files**: Documents not linked from any index/README
- ❌ **Placeholder text**: `TODO`, `TBD`, `[Fill this in]` left uncommitted

**Validation command**:
```bash
# Check for placeholder text in staged files
git diff --cached | grep -i "TODO\|TBD\|FIXME\|\[Fill"

# Check for broken local links (manual review recommended)
grep -r "]\(.*\.md" docs/00-active/ | grep -v "http"
```

### Diagram Red Flags
Monitor Mermaid diagrams during creation:
- ❌ **Invalid syntax**: Diagram won't render
- ❌ **Orphaned nodes**: Nodes not connected to graph
- ❌ **Missing legends**: Complex diagrams without key/legend
- ❌ **Unclear labels**: Abbreviations without definition
- ❌ **Too complex**: >20 nodes (split into multiple diagrams)

**Validation command**:
```bash
# Extract and validate Mermaid syntax (requires mmdc)
# Find all mermaid code blocks and attempt to validate
find docs/00-active -name "*.md" -exec grep -l "```mermaid" {} \; | head -5
```

---

## Gate 3: Pre-Commit Validation (BEFORE `git commit`)

### Documentation Completeness
- [ ] All spike findings have clear summaries:
  ```bash
  # Check for findings without "Summary" section
  find docs/00-active/spikes -name "*.md" -exec grep -L "## Summary" {} \; || echo "All spikes have summaries"
  ```
- [ ] All diagrams have accompanying explanations (not standalone images)
- [ ] All decisions logged in MEMORY.md (if applicable)
- [ ] Session journal created (see below - MANDATORY)

### Diagram Validation
- [ ] All Mermaid diagrams render correctly:
  ```bash
  # Manual validation: View diagrams in GitHub preview or VS Code
  # Automated (if mmdc installed): Extract and validate syntax
  # For now: Manual review of mermaid blocks
  find docs/00-active -name "*.md" -exec grep -A 20 "```mermaid" {} \;
  ```
- [ ] Diagrams have titles/captions explaining purpose
- [ ] Complex diagrams include legends or node type definitions
- [ ] No orphaned nodes (all nodes connected to graph)

### Link Validation
- [ ] No broken internal links:
  ```bash
  # Manual review recommended, or use markdown-link-check if installed
  # Check for links to files that don't exist
  grep -r "]\(.*\.md" docs/00-active/ | grep -v "http" | head -20
  ```
- [ ] External links tested (at least once manually)
- [ ] Section anchors valid (e.g., `#summary` exists in target file)

### Git Hygiene
- [ ] **NO temporary/backup files in `git status`** (*.tmp, *-old.md, backup-*)
- [ ] **NO large binary files** (>500KB diagrams - use Mermaid instead)
- [ ] Meaningful commit message following project convention
- [ ] Verify changes: `git diff --cached` (review what you're committing)

### Spike Findings Validation (if applicable)
- [ ] Spike findings document includes:
  - Clear problem statement
  - Investigation approach/methodology
  - Key findings with evidence
  - Summary and recommendations
- [ ] All claims supported by references or examples
- [ ] Diagrams explain complex concepts visually

### Session Journal (MANDATORY - D014 Protocol)
- [ ] **Session journal entry created**: `docs/00-active/journal/session-{N}.md`
- [ ] Journal includes:
  - **What was accomplished**: Specific deliverables (spikes, diagrams, decisions)
  - **Decisions made**: Link to MEMORY.md entries
  - **Blockers encountered**: Issues and how resolved (or not)
  - **Spike findings**: Summary of research outcomes (if applicable)
- [ ] See D014 protocol: `/home/shayesdevel/projects/cognitive-framework/cognitive-core/quality-collaboration/protocols/quick-reference/D014-session-end-quick-ref.md`

**If ANY pre-commit check fails: Fix before committing**

---

## Gate 4: Pre-Merge Validation (BEFORE PR merge)

### Integration Testing
- [ ] All CI/CD checks passing
- [ ] No merge conflicts with base branch
- [ ] Branch rebased or merged with latest base
- [ ] Integration tests pass (if applicable):
  ```bash
  {INTEGRATION_TEST_COMMAND}
  ```

### Cross-Reference Check
- [ ] Changes don't break other agents' work
- [ ] API contracts maintained (if backend changed endpoints, frontend updated)
- [ ] Database migrations applied (if schema changed)

### Documentation Handoff
- [ ] PR description explains what changed and why
- [ ] Links to relevant GitHub issues
- [ ] Session journal referenced in PR for context

### Quality Review
- [ ] Code review requested (if multi-developer project)
- [ ] Validation gates explicitly confirmed in PR comments
- [ ] Test coverage maintained or improved

**If ANY pre-merge check fails: Block PR merge until resolved**

---

## Gate 5: Post-Merge Verification (AFTER PR merged)

### Tracking Updates
- [ ] GitHub issue status updated (closed or commented)
- [ ] Relevant project docs updated (SPRINT.md, NEXT.md, etc.)
- [ ] Session journal confirms task completion

### Environment Validation
- [ ] Main branch builds successfully after merge
- [ ] Integration environment still functional (if applicable)
- [ ] Database migrations applied (if backend changes merged):
  ```bash
  {MIGRATION_COMMAND}  # Example: alembic upgrade head
  ```

### Orchestrator Verification (D009)
- [ ] Verify commits exist: `git log {BRANCH} --oneline -5`
- [ ] Verify PR exists and closed: `gh pr view {PR_NUMBER}`
- [ ] Worktree clean: `cd {WORKTREE} && git status`

**If post-merge verification fails: Rollback or hotfix immediately**

---

## Agent-Specific Quality Gates

### Documentation Agent
**Pre-commit additions**:
- [ ] All new documents linked from appropriate index/README
- [ ] Documentation follows project structure conventions
- [ ] Placeholder text removed or documented as intentional
- [ ] Docs validation:
  ```bash
  # Check for broken links
  grep -r "]\(.*\.md" docs/00-active/ | grep -v "http"

  # Check for TODO/placeholder text
  git diff --cached | grep -i "TODO\|TBD\|FIXME"
  ```

### Research/Spike Agent
**Pre-commit additions**:
- [ ] Spike findings document includes clear summary section
- [ ] All claims supported by references or evidence
- [ ] Recommendations actionable (not vague suggestions)
- [ ] Spike validation:
  ```bash
  # Verify spike has required sections
  grep -E "## (Problem|Investigation|Findings|Summary)" docs/00-active/spikes/*.md

  # Check spike is linked from tracking docs
  grep -r "spikes/" docs/00-active/*.md
  ```

### Diagram Agent
**Pre-commit additions**:
- [ ] All diagrams use Mermaid (text-based, not binary screenshots)
- [ ] Diagrams have titles and explanatory text
- [ ] Complex diagrams include legends
- [ ] No orphaned nodes (all nodes connected)
- [ ] Diagram validation:
  ```bash
  # Find all Mermaid diagrams
  find docs/00-active -name "*.md" -exec grep -l "```mermaid" {} \;

  # If mmdc installed, validate syntax
  # mmdc -i diagram.mmd -o /dev/null (for each diagram file)
  ```

### Orchestrator (Documentation Project)
**Pre-commit additions**:
- [ ] Session journal references all deliverables from all agents
- [ ] MEMORY.md updated with architectural decisions
- [ ] All agent PRs merged and verified (D009 protocol)
- [ ] Cross-agent consistency (diagrams match documentation)
- [ ] Orchestrator validation:
  ```bash
  # Verify session journal exists
  ls docs/00-active/journal/session-*.md | tail -1

  # Verify MEMORY.md is current
  git log -1 --oneline docs/00-active/MEMORY.md

  # Check for uncommitted changes from agents
  git status --porcelain
  ```

---

## Definition of Done Checklist

**Work is NOT complete until ALL items checked**:
- [ ] ✅ Pre-flight check passed (Gate 1)
- [ ] ✅ File hygiene maintained during documentation work (Gate 2)
- [ ] ✅ Documentation completeness verified (Gate 3)
- [ ] ✅ All diagrams render correctly (Gate 3)
- [ ] ✅ No broken links (Gate 3)
- [ ] ✅ No temporary/backup files committed (Gate 3)
- [ ] ✅ Spike findings complete with summary (Gate 3, if applicable)
- [ ] ✅ **Session journal created** (Gate 3 - MANDATORY)
- [ ] ✅ CI/CD passing (Gate 4, if configured)
- [ ] ✅ No merge conflicts (Gate 4)
- [ ] ✅ PR merged (Gate 4)
- [ ] ✅ GitHub issue updated (Gate 5)
- [ ] ✅ Post-merge verification passed (Gate 5)

**Only report work as complete after ALL checkboxes ticked**

**Documentation-specific completion criteria**:
- All documents linked from index/README (not orphaned)
- All diagrams have explanatory text
- All spikes have clear summaries and recommendations
- Session journal documents all deliverables

---

## Enforcement

### Orchestrator Responsibility
- Verify ALL agents follow quality gates before merging PRs
- Run D009 verification on all "complete" reports
- Reject PRs that skip gates (binary files, missing session journals, failing tests)

### Sub-Agent Responsibility
- Review quality gates BEFORE starting work (Gate 1)
- Monitor file hygiene DURING work (Gate 2)
- Validate BEFORE committing (Gate 3)
- Confirm in PR description which gates passed

### Human Responsibility
- Review quality gates during project setup
- Customize {PLACEHOLDER} values for your tech stack
- Enforce gates during code review
- Update gates as project evolves

---

## Project Configuration

**All placeholders have been replaced** with james-project specifics:

### Paths
- **Cognitive Framework**: `/home/shayesdevel/projects/cognitive-framework`
- **Project Docs**: `docs/00-active/`
- **D014 Quick Reference**: `/home/shayesdevel/projects/cognitive-framework/cognitive-core/quality-collaboration/protocols/quick-reference/D014-session-end-quick-ref.md`
- **Session Journal Pattern**: `docs/00-active/journal/session-{N}.md`

### Tools (Optional but Recommended)
- **Mermaid CLI**: `npm install -g @mermaid-js/mermaid-cli` (diagram validation)
- **Markdown Link Checker**: `npm install -g markdown-link-check` (link validation)

### Validation Commands
- **Documentation completeness**: `find docs/00-active/spikes -name "*.md" -exec grep -L "## Summary" {} \;`
- **Diagram validation**: `find docs/00-active -name "*.md" -exec grep -l "\`\`\`mermaid" {} \;`
- **Link checking**: `grep -r "]\(.*\.md" docs/00-active/ | grep -v "http"`
- **Placeholder detection**: `git diff --cached | grep -i "TODO\|TBD\|FIXME"`

### Project Type
- **Focus**: Documentation and research (spike findings, architecture diagrams, decision logs)
- **No code compilation/testing**: Build and test gates removed
- **Primary artifacts**: Markdown documents, Mermaid diagrams, session journals

---

## Version

**Created**: 2025-11-20
**Last Updated**: 2025-11-20
**Version**: 1.0 (customized for documentation project)
**Adapted from**: Cognitive Framework v2.2 quality gates template
