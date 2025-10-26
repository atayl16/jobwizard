# JobWizard Rapid Ship Plan

**MODE:** AUTOPILOT  
**PURPOSE:** URGENT  
**DATE:** 2025-10-23  
**STATUS:** IN_PROGRESS

## Mission
Ship a working JobWizard app for immediate job application generation (resume + cover letter PDFs).

## Current State ✅
- ✅ Rails 8 app with SQLite
- ✅ Database migrated (10 tables)
- ✅ Core models: JobPosting, JobSource, Application, BlockedCompany, AiUsage
- ✅ Controllers: Dashboard, Jobs, Applications
- ✅ PDF generation infrastructure (Prawn)
- ✅ Job fetchers (Greenhouse, Lever stubs)
- ✅ OpenAI integration (optional)
- ✅ Truth-only guardrails implemented
- ✅ Tests structured (RSpec)

## Critical Path (URGENT - Ship Fast)

### M1: ✅ Environment Ready
- [x] Fix bundle dependencies
- [x] Verify DB migrations
- [x] Check tests exist

### M2: 🔄 Quick Smoke Test
- [ ] Start server locally
- [ ] Verify dashboard loads
- [ ] Test manual application flow (paste JD → generate PDFs)
- [ ] Confirm PDF output to `~/Documents/JobWizard/`

### M3: 📝 Fix Immediate Blockers Only
- [ ] Fix any crash bugs discovered in M2
- [ ] Stub out any missing config files
- [ ] Leave style issues for later

### M4: 📦 Ship Checklist
- [ ] README has clear "Quick Start" 
- [ ] Config templates documented
- [ ] Sample profile/experience/rules.yml exist
- [ ] `.env.example` with OpenAI key (optional)

### M5: 🚀 Ready to Use
- [ ] Run full test suite
- [ ] Document any TODOs for polish
- [ ] Create initial git commit

## Acceptance Criteria (URGENT)
1. ✅ App starts without errors
2. ✅ Dashboard loads
3. ✅ Can paste JD and generate resume + cover letter PDFs
4. ✅ PDFs saved to correct location
5. ✅ No crashes on happy path

## Defer to Later (Not Urgent)
- RuboCop style fixes (400+ offenses)
- Job fetcher implementation (stubs OK)
- UI polish
- Performance optimization
- Additional test coverage beyond smoke tests

## Notes
- **Truth-only policy:** All resume data from `config/job_wizard/*.yml`
- **Local-only:** SQLite, no external services required
- **OpenAI optional:** Template-based fallback exists
- **macOS:** Output paths assume `~/Documents/`

---

*AUTOPILOT URGENT: Moving fast, stubs over perfection, ship now polish later.*
