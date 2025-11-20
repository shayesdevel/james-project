# Agent Contexts

**Purpose**: Copy agent templates from cognitive framework domain specializations
**Status**: Template - Customize for your project

---

## Quick Start

### Step 1: Choose Your Domain

See `../../DOMAIN_SELECTION.md` to select the appropriate domain specialization for your project.

**Available domains**:
- `domain-specializations/software-development/` - Full-stack software development
- *(Add more domains as they're created)*

### Step 2: Select Agents

See `cognitive-core/agent-roles/roster-selection.md` for guidance on agent roster sizing.

**Recommended starting roster** (3 agents minimum):
- Backend specialist
- Frontend specialist
- Testing specialist

**Optional specialists** (add as needed):
- Database specialist
- DevOps specialist
- QA specialist
- Security specialist
- Documentation specialist

### Step 3: Copy Templates

```bash
# Navigate to cognitive framework repo
cd /path/to/cognitive-framework

# Copy agent templates (example: software development domain)
cp domain-specializations/software-development/agent-templates/backend-agent-template.md \
   {YOUR_PROJECT}/.claude/agents/backend-context.md

cp domain-specializations/software-development/agent-templates/frontend-agent-template.md \
   {YOUR_PROJECT}/.claude/agents/frontend-context.md

cp domain-specializations/software-development/agent-templates/testing-agent-template.md \
   {YOUR_PROJECT}/.claude/agents/testing-context.md

# Optional: Database specialist
# cp domain-specializations/software-development/agent-templates/database-agent-template.md \
#    {YOUR_PROJECT}/.claude/agents/database-context.md

# Optional: DevOps specialist
# cp domain-specializations/software-development/agent-templates/devops-agent-template.md \
#    {YOUR_PROJECT}/.claude/agents/devops-context.md
```

### Step 4: Fill Placeholders

Open each agent context file and replace `{PLACEHOLDER}` values with your project-specific details.

**See**: `domain-specializations/software-development/quick-start.md` for detailed placeholder replacement guide.

---

## Agent File Naming

**Convention**: `{role}-context.md`

**Examples**:
- `backend-context.md`
- `frontend-context.md`
- `testing-context.md`
- `database-context.md`
- `devops-context.md`

---

## Verification

After copying and customizing agents:

✅ All `{PLACEHOLDER}` values filled in
✅ Each agent context <100 lines
✅ Agent domain boundaries clearly defined
✅ Validation gates configured for your project
✅ Quick refs referenced (not inlined)

---

**Next**: See `../../../SETUP_CHECKLIST.md` for complete project setup workflow
