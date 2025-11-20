# Path Reference Guide - james-project

**Purpose**: Prevent path reference errors when agents work in main repository

**Note**: This project does NOT use worktrees (documentation project with clear domain separation). All agents work in main repository.

---

## Directory Structure

```
/home/shayesdevel/projects/
├── cognitive-framework/                    # Framework repo
│   ├── cognitive-core/
│   ├── domain-specializations/
│   └── templates/
└── james-project/                          # Project repo (all agents work here)
    ├── .claude/
    │   ├── agents/                         # Agent context files
    │   │   ├── orchestrator.md
    │   │   ├── scribe.md
    │   │   └── diagram.md
    │   └── settings.json
    ├── docs/
    │   ├── 00-active/
    │   │   ├── ARCHITECTURE.md
    │   │   ├── MEMORY.md
    │   │   ├── quality-gates.md
    │   │   └── journal/
    │   ├── 01-archive/
    │   ├── authentication/                 # Scribe's domain
    │   └── diagrams/                       # Diagram agent's domain
    ├── framework-config.json
    ├── PATH_REFERENCE_GUIDE.md
    └── CLAUDE.md
```

**Key insight**: No worktrees needed. All agents work in `/home/shayesdevel/projects/james-project/`

---

## Path Patterns by Location

### From Main Repository (`~/projects/james-project/`)

**All agents work here** (orchestrator, scribe, diagram)

| Target | Path from Main Repo | Explanation |
|--------|---------------------|-------------|
| Cognitive framework | `../cognitive-framework/` | One level up to /projects/, then into framework |
| Project docs | `./docs/00-active/` | Local directory (current repo) |
| Project .claude | `./.claude/` | Local directory (current repo) |
| Agent contexts | `./.claude/agents/` | Local directory (current repo) |
| Authentication docs | `./docs/authentication/` | Scribe's domain |
| Diagram files | `./docs/diagrams/` | Diagram agent's domain |

**Testing from main repo**:
```bash
cd ~/projects/james-project
ls ../cognitive-framework/                  # Framework (should list cognitive-core/, etc.)
ls ./docs/00-active/                        # Project docs (should list quality-gates.md, etc.)
ls ./.claude/agents/                        # Agent contexts (should list orchestrator.md, etc.)
```

---

### No Worktrees for This Project

**Rationale**: Documentation project with clear domain separation makes worktrees unnecessary.

**Domain Boundaries**:
- **scribe**: Works in `./docs/authentication/` and session journals
- **diagram**: Works in `./docs/diagrams/`
- **orchestrator**: Coordinates from main repo

All agents use the same paths since they all work in `/home/shayesdevel/projects/james-project/`

---

## Common Path Patterns for james-project

### ✅ CORRECT: Framework from main repo (all agents)
```markdown
# In agent context file
- D009 Protocol: `../cognitive-framework/cognitive-core/quality-collaboration/protocols/D009.md`
- Quick Refs: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/`
```

### ✅ CORRECT: Project resources from main repo (all agents)
```markdown
# In agent context file
- Quality gates: `./docs/00-active/quality-gates.md`
- Session journals: `./docs/00-active/journal/`
- Agent contexts: `./.claude/agents/`
```

### ✅ CORRECT: Domain-specific paths
```markdown
# For scribe agent
- Work area: `./docs/authentication/`

# For diagram agent
- Work area: `./docs/diagrams/`
```

---

## Path Reference Templates for Agent Contexts

### For All Agents (all work in main repo)

```markdown
## Key References

**Framework References** (from main repo):
- D009 Verification: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/d009-verification-quick-ref.md`
- D014 Session End: `../cognitive-framework/cognitive-core/quality-collaboration/quick-reference/d014-session-end-quick-ref.md`
- Orchestration Patterns: `../cognitive-framework/cognitive-core/orchestration/patterns/`

**Project References** (from main repo):
- Quality Gates: `./docs/00-active/quality-gates.md`
- Session Journals: `./docs/00-active/journal/`
- MEMORY: `./docs/00-active/MEMORY.md`
- ARCHITECTURE: `./docs/00-active/ARCHITECTURE.md`
- Project Settings: `./.claude/settings.json`
```

---

## Path Validation (BEFORE Committing Agent Contexts)

**CRITICAL**: Test ALL paths from main repository BEFORE committing agent context file

### Step 1: Test Paths from Main Repo
```bash
cd ~/projects/james-project

# Test framework access (ONE level up)
ls ../cognitive-framework/ || echo "❌ ERROR: Framework path broken"

# Test project docs (local)
ls ./docs/00-active/ || echo "❌ ERROR: Docs path broken"

# Test .claude (local)
ls ./.claude/settings.json || echo "❌ ERROR: .claude path broken"

# Test domain directories
ls ./docs/authentication/ || echo "⚠️  WARNING: Authentication dir not created yet"
ls ./docs/diagrams/ || echo "⚠️  WARNING: Diagrams dir not created yet"
```

### Step 2: If ANY Test Fails
1. **STOP** - Do not commit agent context yet
2. Fix paths in agent context file
3. Re-run tests until all pass
4. THEN commit agent context

---

## Path Validation Script

**Location**: `scripts/validate-agent-paths.sh` (if needed)

**Note**: Since all agents work in main repo, path validation is simpler:

```bash
#!/bin/bash
# Validate all agent context path references from main repo

cd ~/projects/james-project

echo "Testing paths for james-project agents..."

# Framework (ONE level up)
if [ -d "../cognitive-framework" ]; then
  echo "✅ Framework path: ../cognitive-framework/"
else
  echo "❌ Framework path broken: ../cognitive-framework/"
fi

# Project docs (local)
if [ -d "./docs/00-active" ]; then
  echo "✅ Docs path: ./docs/00-active/"
else
  echo "❌ Docs path broken: ./docs/00-active/"
fi

# .claude (local)
if [ -f "./.claude/settings.json" ]; then
  echo "✅ .claude path: ./.claude/"
else
  echo "❌ .claude path broken: ./.claude/"
fi

# Domain directories
if [ -d "./docs/authentication" ]; then
  echo "✅ Authentication domain: ./docs/authentication/"
else
  echo "⚠️  Authentication dir not created yet: ./docs/authentication/"
fi

if [ -d "./docs/diagrams" ]; then
  echo "✅ Diagrams domain: ./docs/diagrams/"
else
  echo "⚠️  Diagrams dir not created yet: ./docs/diagrams/"
fi

echo ""
echo "Path validation complete."
```

---

## Quick Reference Chart

| Resource | Path from Main Repo (All Agents) |
|----------|-----------------------------------|
| Framework | `../cognitive-framework/` |
| Project docs | `./docs/00-active/` |
| .claude config | `./.claude/` |
| Scribe domain | `./docs/authentication/` |
| Diagram domain | `./docs/diagrams/` |

**Memory trick**:
- Framework is **ONE level up**: `../cognitive-framework/`
- Project resources are **local**: `./docs/`, `./.claude/`
- All agents use the same paths (no worktrees)

---

## Troubleshooting

### Symptom: Agent reports "cannot find quality-gates.md"

**Diagnosis**: Path error in agent context

**Fix**:
1. All agents work in main repo: `/home/shayesdevel/projects/james-project/`
2. Use local path: `./docs/00-active/quality-gates.md`

### Symptom: Agent reports "cannot find cognitive-framework"

**Diagnosis**: Framework path error

**Fix**:
1. Framework is sibling to project at `/projects/` level
2. Use: `../cognitive-framework/`
3. Verify: `ls ../cognitive-framework/` should show `cognitive-core/`

### Symptom: "No such file or directory" errors for quick-refs

**Diagnosis**: Incorrect framework path depth

**Fix**:
1. From main repo: `../cognitive-framework/cognitive-core/...`
2. NOT `../../cognitive-framework/...` (too deep)
3. NOT `./cognitive-framework/...` (not deep enough)

---

## Version

**Created**: 2025-11-20
**Last Updated**: 2025-11-20
**Version**: 1.0
**Project**: james-project (no worktrees)

**Critical Lesson Source**: LESSONS_FROM_INTERVIEW_PREP_DEPLOYMENT.md - Critical Lesson 3
**Adaptation**: Simplified for documentation project without worktree isolation
