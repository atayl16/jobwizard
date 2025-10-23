# Claude AI Collaboration Guide

**How we work together on JobWizard**

---

## Core Principles

### 🎯 Small, Reviewable Changes
- Each change ≤200 LOC or ~20 minutes of work
- PR-sized commits with clear messages (`feat:`, `fix:`, `chore:`)
- Tests included with every feature change

### 🛡️ Truth-Only Guardrails
**Critical for JobWizard resumes/cover letters:**
- All content from `config/job_wizard/{profile,experience,rules}.yml`
- **Never fabricate** skills, experience, or credentials
- Flag unverified skills, don't include them
- Changes to YAML files require explicit approval

### 🏠 Local-First Development
- SQLite (not PostgreSQL) for local dev
- ActiveJob :async (no Redis/Sidekiq)
- No hard external dependencies
- Production paths only when explicitly requested

### ✅ Quality Gates
- RuboCop must pass (or violations documented)
- Tests pass before committing
- Overcommit hooks enforced
- Security scans clean

---

## Mode-Based Workflow

**Current mode:** Read from `ai/mode.yml` at session start

### CO-DRIVER Mode
1. Create structured PLAN (A1, A2, B1, etc.)
2. Show DIFF SUMMARY per section
3. Wait for `APPROVE` / `REVISE` / `SKIP`
4. Implement approved sections
5. Update `ai/tracking.md`

### AUTOPILOT Mode
1. Implement end-to-end
2. Small, atomic commits
3. Fix failing tests automatically
4. Post milestone updates
5. Only pause for data-loss ambiguity

**Switch modes:** `bin/ai_mode co-driver` or `bin/ai_mode autopilot`

---

## Prompt Snippets

### 🗺️ PLAN Template

```markdown
PLAN: <Feature Name>

**Scope:** [1-2 sentences]

**Steps:**
A1. [First step, ~50 LOC]
A2. [Second step, ~50 LOC]
A3. [Third step, ~50 LOC]

**Tests:**
- Unit: [what to test]
- Integration: [what to test]

**Acceptance:**
- [ ] Feature works as described
- [ ] Tests pass
- [ ] RuboCop clean
```

### 🔍 DIFF REVIEW Template

```markdown
DIFF SUMMARY A1: <Step Name>

Files changed:
  app/models/foo.rb           [MODIFIED, +15/-3]
  spec/models/foo_spec.rb     [NEW, +42]

Rationale:
- [Why this change is needed]
- [What it accomplishes]

Risks:
- [None | List any concerns]

Waiting for: APPROVE A1 | REVISE A1: <notes> | SKIP A1
```

### ⚙️ IMPLEMENT Template

```markdown
## IMPLEMENTED: A1 - <Step Name>

**Changes:**
```diff
# app/models/foo.rb
+ def new_method
+   # implementation
+ end
```

**Tests:**
```diff
# spec/models/foo_spec.rb
+ describe '#new_method' do
+   it 'works' do
+     expect(subject.new_method).to eq('expected')
+   end
+ end
```

**Verification:**
```bash
bundle exec rspec spec/models/foo_spec.rb
bundle exec rubocop app/models/foo.rb
```

**Commit:** `feat(foo): add new_method for bar feature`
```

### 🐛 DEBUG Template

```markdown
## DEBUG: <Problem Description>

**Symptoms:**
- [What's broken]
- [Error message]

**Root Cause:**
- [Why it's happening]

**Fix:**
```diff
# file.rb
- old_code
+ new_code
```

**Test Added:**
[Spec that proves bug is fixed]

**Verification:**
```bash
bundle exec rspec spec/path/to/test.rb
```
```

---

## Accepted Commands

```
MODE?                              # Re-read ai/mode.yml
SWITCH MODE TO <co-driver|autopilot>
APPROVE A1 / APPROVE ALL / APPROVE ALL EXCEPT A3
REVISE A2: <notes>
SKIP A3
SHOW DIFFS FOR <path>
TODO: <note>
RUN CHECKS
ROLLBACK LAST COMMIT
```

---

## Protected Files (Require Explicit Approval)

**Never modify without confirmation:**
- `config/job_wizard/profile.yml`
- `config/job_wizard/experience.yml`
- `config/job_wizard/rules.yml`
- `config/job_wizard/sources.yml`
- `.env` files
- `config/database.yml` (production)
- `config/deploy.yml`
- `config/master.key`

**Always show diffs first, wait for approval.**

---

## Emergency Brake: ai_diagnose

If AI gets stuck in a bug loop:

```bash
ai_diagnose
```

Or say: `DIAGNOSE: <problem>`

This forces diagnostic-only mode:
1. Stop editing
2. Trace data flow
3. Prove root cause
4. Propose ONE fix location
5. Wait for approval

---

## Commit Message Format

```
<type>(<scope>): <subject>

<body - optional>

<footer - optional>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `refactor:` Code restructure (no behavior change)
- `test:` Add/update tests
- `docs:` Documentation only
- `chore:` Tooling, config, etc.
- `perf:` Performance improvement

**Examples:**
```
feat(skills): add skill assessment to job postings
fix(pdf): correct resume formatting for long experience entries
refactor(services): extract common job filtering logic
test(fetchers): add specs for Greenhouse API error handling
docs(readme): add OpenAI setup instructions
chore(ai): bootstrap mode workflow
```

---

## Testing Strategy

### Required Coverage
- **Unit tests:** All service objects, models
- **Integration tests:** Controller actions, API endpoints
- **System tests:** Critical user flows (optional)

### Test Commands
```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/job_posting_spec.rb

# Run specific example
bundle exec rspec spec/models/job_posting_spec.rb:42

# With coverage
COVERAGE=true bundle exec rspec
```

---

## Quality Checks

### Before Committing
```bash
# Auto-fix style issues
bundle exec rubocop -A

# Run tests
bundle exec rspec

# Security scan
bundle exec brakeman -q
bundle exec bundler-audit check
```

### Using Justfile
```bash
just lint      # RuboCop
just test      # RSpec
just sec       # Security scans
```

---

## Documentation Maintenance

### Update These Files
- `ai/plan.md` - Current feature plan, milestones
- `ai/tracking.md` - Session log, decisions, TODOs
- `ai/QUICK_START.md` - User-facing quick start guide
- `README.md` - Keep in sync with new features

### After Major Changes
- Update acceptance criteria in `ai/plan.md`
- Document decisions in `ai/tracking.md`
- Add usage examples to `README.md` if needed

---

## Session Workflow

### Start of Session
1. Read `ai/mode.yml` → determine behavior
2. Read `ai/tracking.md` → understand current state
3. Read `ai/plan.md` → see what's in progress
4. Report: MODE, status, ready for instruction

### During Session
- **CO-DRIVER:** Plan → Diffs → Approval → Implement → Update tracking
- **AUTOPILOT:** Implement → Test → Commit → Milestone update

### End of Session
- Update `ai/tracking.md` with progress
- Mark completed milestones in `ai/plan.md`
- Document any decisions or TODOs
- Clear "next steps" for continuation

---

## Common Patterns

### Adding a New Feature
1. Plan the work (3-7 steps)
2. Start with migration (if needed)
3. Add model + validations
4. Add service layer
5. Add controller actions
6. Add views/UI
7. Add tests for each layer

### Fixing a Bug
1. Write failing test first
2. Identify root cause
3. Apply minimal fix
4. Verify test passes
5. Check for similar issues

### Refactoring
1. Ensure tests are green first
2. Make one small change
3. Run tests
4. Repeat until done
5. Document tradeoffs

---

*Last updated: 2025-10-23*
*JobWizard AI Collaboration Guide*

