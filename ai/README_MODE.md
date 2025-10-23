# AI Mode System

This repo uses a **mode-based AI pair programming workflow** that controls how the AI collaborates with you.

## Modes

### 🤝 CO-DRIVER (Default)
**AI proposes, you approve**

Behavior:
1. AI creates a structured PLAN with identifiers (A1, A2, B1, B2, etc.)
2. Shows DIFF SUMMARY for each section (files changed + rationale)
3. **Waits for your approval** before applying changes
4. Implements approved sections in PR-sized commits
5. Updates `ai/tracking.md` after each section

**Best for:** Complex features, learning, when you want control

### ⚡ AUTOPILOT
**AI ships end-to-end**

Behavior:
1. Implements features in small, reviewable commits
2. Fixes failing tests automatically
3. Posts short milestone updates
4. **Only pauses** for ambiguity with data-loss risk

**Best for:** Urgent tasks, well-defined work, speed over control

---

## Switching Modes

### Check Current Mode
```bash
grep '^mode:' ai/mode.yml
# or
bin/ai_mode
```

### Switch to CO-DRIVER
```bash
bin/ai_mode co-driver
```

### Switch to AUTOPILOT
```bash
bin/ai_mode autopilot
```

---

## Commands You Can Use Anytime

### Mode Control
```
MODE?                              # AI re-reads ai/mode.yml and reports current mode
SWITCH MODE TO co-driver           # Update mode and continue
SWITCH MODE TO autopilot           # Update mode and continue
```

### Approval (CO-DRIVER mode)
```
APPROVE A1                         # Approve section A1
APPROVE A1,A2,B1                   # Approve multiple sections
APPROVE ALL                        # Approve all sections
APPROVE ALL EXCEPT A3,B2           # Approve all except specified sections
REVISE A2: use a service instead   # Request changes with notes
SKIP A3                            # Skip this section
```

### Utilities
```
SHOW DIFFS FOR <path>              # See detailed diffs for a file/directory
TODO: <note>                       # Append note to ai/tracking.md
RUN CHECKS                         # AI runs tests/linters and reports
ROLLBACK LAST COMMIT               # Undo last change
```

---

## Workflow Examples

### CO-DRIVER Example

**You:** "Add job skill assessment feature"

**AI:**
```
PLAN: Job Skill Assessment

A1. Add skill_assessments table migration
A2. Create SkillAssessment model with validations
A3. Add controller actions (create, update)
A4. Add view components for UI
A5. Add specs for model and controller

DIFF SUMMARY A1:
  db/migrate/xxx_create_skill_assessments.rb  [NEW, 15 lines]
  
Waiting for approval...
```

**You:** `APPROVE A1`

**AI:** [applies migration, commits, shows A2 diffs]

---

### AUTOPILOT Example

**You:** "Add job skill assessment feature"

**AI:**
```
MILESTONE 1: Database & Model
- Created skill_assessments migration
- Added SkillAssessment model with validations
- Tests: 8 passing
- Committed: feat(skills): add skill assessment model

MILESTONE 2: Controller & Views [in progress...]
```

---

## Configuration

**File:** `ai/mode.yml`

```yaml
mode: co-driver  # or: autopilot

approvals:
  require_diff_approval: true
  default_exclusions: []  # files to auto-approve (use with caution)
```

---

## Constraints

Both modes honor:
- ✅ **Local-only default:** SQLite, ActiveJob :async, no Redis/Sidekiq
- ✅ **Truth-only resumes:** Use `config/job_wizard/*.yml` only, never fabricate
- ✅ **Small commits:** PR-sized changes (~200 LOC or less)
- ✅ **Quality gates:** RuboCop/Overcommit must pass
- ✅ **Tests required:** All new features need specs

---

## Troubleshooting

### AI not respecting mode?
Say: `MODE?` to force re-read of `ai/mode.yml`

### Want more control?
```bash
bin/ai_mode co-driver
```

### Want speed?
```bash
bin/ai_mode autopilot
```

### Mode file corrupted?
Reset to default:
```bash
cat > ai/mode.yml <<EOF
mode: co-driver
approvals:
  require_diff_approval: true
  default_exclusions: []
EOF
```

---

*Mode system bootstrapped 2025-10-23*

