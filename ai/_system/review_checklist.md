# Code Review Checklist

Use this checklist in **CRITIC** role to review all changes.

## 🔴 BLOCKERS (Must Fix Before Approval)

### Functionality
- [ ] Does the code do what the plan says?
- [ ] Are edge cases handled (nil, empty, invalid input)?
- [ ] Are error messages clear and actionable?
- [ ] Does it break existing functionality?

### Security
- [ ] No hardcoded secrets or API keys
- [ ] User input is sanitized (XSS, SQL injection)
- [ ] File uploads validated (if applicable)
- [ ] Authentication/authorization checked (if needed)

### Tests
- [ ] New functionality has test coverage
- [ ] Tests actually test the behavior (not just syntax)
- [ ] Tests pass locally
- [ ] Edge cases covered in tests

### Quality
- [ ] RuboCop/ESLint passes (or violations documented)
- [ ] No obvious code smells (giant methods, deep nesting)
- [ ] Variable/method names are clear
- [ ] Comments explain WHY, not WHAT

---

## 🟡 NITS (Suggestions, Not Blockers)

### Style
- [ ] Consistent with project conventions
- [ ] Readable by junior developer
- [ ] Could be simplified without losing clarity
- [ ] Magic numbers replaced with constants

### Performance
- [ ] No obvious N+1 queries
- [ ] No unnecessary database calls
- [ ] No expensive operations in loops
- [ ] Caching used where appropriate

### Maintainability
- [ ] Easy to modify later
- [ ] Dependencies are clear
- [ ] Would I understand this in 6 months?
- [ ] Could be extracted/reused if needed

---

## 🔵 RISKS (Document, Monitor)

### Data
- [ ] Schema changes require migration
- [ ] Existing data needs backfill?
- [ ] Could orphan records?
- [ ] Affects production data?

### Dependencies
- [ ] New gems/packages introduced
- [ ] Version constraints appropriate
- [ ] Known vulnerabilities in dependencies?

### Deployment
- [ ] Requires manual steps?
- [ ] Config changes needed?
- [ ] Affects running services?
- [ ] Rollback plan clear?

---

## VERDICT Format

```markdown
## CRITIC REVIEW

### ✅ PASSED
- [List what looks good]

### 🔴 BLOCKERS
- [Critical issues that MUST be fixed]

### 🟡 NITS
- [Suggestions for improvement]

### 🔵 RISKS
- [Potential issues to monitor]

### VERDICT: [APPROVE | REVISE | REJECT]

**Reasoning:** [1-2 sentences explaining the verdict]
```

---

## Example Usage

**ENGINEER** implements a step → **CRITIC** reviews using this checklist → produces verdict → human decides.

If **REVISE**: ENGINEER fixes blockers, CRITIC re-reviews.
If **APPROVE**: Human can apply changes.
If **REJECT**: Return to planning phase.

---

*This checklist ensures consistent, high-quality code reviews.*

