# AI Development Constraints

## Hard Limits

### Code Changes
- **Max 200 LOC per step** (or ~20 minutes of work)
- **One feature/fix per commit**
- **No batch refactors** without explicit approval
- **Test coverage required** for new functionality

### Configuration Files
**NEVER modify without explicit approval:**
- `config/job_wizard/profile.yml`
- `config/job_wizard/experience.yml`
- `config/job_wizard/rules.yml`
- `.env` files
- `database.yml` (production section)
- `deploy.yml`

**Always propose diffs first, wait for confirmation.**

### Data Integrity
- **No fabricated data**: Skills, experience, credentials must be real
- **No external API keys** in commits (use Rails credentials)
- **SQLite only** for local development (no PostgreSQL requirement)
- **No production database migrations** without review

### Security
- **Scan before commit**: Use `scan_here` or Overcommit hooks
- **No secrets in code**: Use `.env` or Rails credentials
- **Review dependencies**: Check Gemfile/package.json changes
- **Audit external gems**: Verify before adding

## Workflow Constraints

### Planning Phase
- **3–5 clarifying questions** before implementation
- **Wait for answers** (no assumptions)
- **Document decisions** in `ai/work/plan-*.md`

### Implementation Phase
- **One step at a time** (no parallel changes)
- **Show diffs before applying**
- **Suggest verification commands** (don't auto-run)
- **Update tests** with every feature change

### Review Phase
- **Use review checklist** (`ai/_system/review_checklist.md`)
- **Identify blockers** before approval
- **Wait for human decision** (APPROVE/REVISE/REJECT)

## Tool Usage

### Commands to NEVER Auto-Run
- `git push` (especially with `--force`)
- `rails db:migrate` in production
- `bundle install` (may take time)
- `rails destroy` (destructive)
- Server commands (`rails s`, `npm run dev`)

### Commands Safe to Suggest
- `bundle exec rubocop -A` (auto-fix style)
- `bundle exec rspec` (run tests)
- `rails db:migrate` (local dev)
- `scan_here` (security scan)
- `git status`, `git diff` (read-only)

## Communication Style

### DO
- ✅ Show file paths relative to project root
- ✅ Use unified diff format for changes
- ✅ Explain WHY, not just WHAT
- ✅ Suggest next commands explicitly
- ✅ Ask clarifying questions upfront

### DON'T
- ❌ Assume requirements not stated
- ❌ Make large changes "while we're at it"
- ❌ Skip tests "for now"
- ❌ Modify configs silently
- ❌ Auto-run destructive commands

## Emergency Brake

If stuck in a bug loop:
```bash
ai_diagnose
```

This forces diagnostic mode:
1. Stop editing
2. Trace data flow
3. Prove root cause
4. Propose ONE fix
5. Wait for approval

---

*These constraints keep development safe, fast, and under human control.*

