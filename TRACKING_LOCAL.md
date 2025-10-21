# JobWizard - Local-Only Implementation Tracking

**Last Updated**: 2025-10-21  
**Context**: 🏠 Single-user macOS app (no deployment)  
**Focus**: Truth-safety, UX speed, filesystem workflow  
**Overall Progress**: 0/10 tasks complete

---

## Quick Reference

**What Matters for Local-Only**:
- ✅ Truth-safety (never fabricate)
- ✅ Fast PDF generation (<300ms)  
- ✅ Resilient fetchers (handle API outages)
- ✅ Finder integration (macOS workflow)
- ✅ SQLite + ActiveJob :async (simple stack)

**What Doesn't Matter**:
- ❌ Multi-user auth
- ❌ Production deployment
- ❌ CDN/HTTPS/CORS
- ❌ Redis/Sidekiq

---

## Phase 1: Truth-Safety & Core (P1) - Week 1

### 🔴 Step 1: Add Truth-Safety Tests
- **Status**: ⬜ Not started
- **Effort**: M (3-4 hours)
- **Priority**: Must prove core promise

**Goal**: Prove ResumeBuilder never fabricates skills

**Tasks**:
- [ ] Create `spec/services/job_wizard/resume_builder_spec.rb`
- [ ] Test: JD mentions "Blockchain" (not in experience.yml) → NOT in PDF
- [ ] Test: JD mentions "Rails" (in experience.yml) → IS in PDF
- [ ] Test: `allowed_skills=['Rails']` excludes React from PDF
- [ ] Test: Skill levels phrase correctly (expert/intermediate/basic)
- [ ] Test: Work history only shows experience.yml companies
- [ ] Add `spec/support/pdf_helper.rb` for text extraction
- [ ] All tests passing

**Verify**:
```bash
bundle exec rspec spec/services/job_wizard/resume_builder_spec.rb --format documentation
```

---

### 🔴 Step 2: Fix Path Traversal
- **Status**: ⬜ Not started
- **Effort**: S (1-2 hours)
- **Priority**: Protect macOS filesystem

**Goal**: Prevent malicious company names from writing outside OUTPUT_ROOT

**Tasks**:
- [ ] Update `slugify` to reject `..`, `/`, `\`, null bytes
- [ ] Add length limit (100 chars) to prevent filesystem issues
- [ ] Add OUTPUT_ROOT validation in `build_output_path`
- [ ] Raise `ArgumentError` for invalid chars
- [ ] Raise `SecurityError` for path escape attempts
- [ ] Add tests for path traversal attempts
- [ ] Test with `../../etc/passwd` → should error
- [ ] Test with valid names → should still work

**Verify**:
```bash
# Test traversal attempt
rails runner "
  begin
    JobWizard::PdfOutputManager.new(company: '../../etc', role: 'passwd')
    puts '❌ FAILED - should have raised error'
  rescue ArgumentError => e
    puts '✅ PASSED - rejected traversal: ' + e.message
  end
"
```

**Files**:
- `app/services/job_wizard/pdf_output_manager.rb` - Add validation
- `spec/services/job_wizard/pdf_output_manager_spec.rb` - Add tests

---

### 🔴 Step 3: Add File Upload Validation
- **Status**: ⬜ Not started
- **Effort**: S (1-2 hours)
- **Priority**: Prevent local DoS

**Goal**: Validate uploaded JD files (size, type, safety)

**Tasks**:
- [ ] Add 5MB size limit
- [ ] Add type validation (`.txt`, `.pdf`, `.doc`, `.docx`)
- [ ] Check Content-Type header (not just extension)
- [ ] Sanitize filenames (remove `../`, special chars)
- [ ] Show clear error messages for each rejection
- [ ] Add tests for oversized files
- [ ] Add tests for wrong file types
- [ ] Add tests for malicious filenames

**Verify**:
```bash
# Manual test in browser
1. Upload 10MB file → "File too large (max 5MB)"
2. Upload .exe file → "Invalid file type"
3. Upload valid .txt → Success
```

**Files**:
- `app/controllers/applications_controller.rb:216-231` - Update validation
- `spec/requests/applications_spec.rb` - Add upload tests

---

### 🔴 Step 4: Make Fetchers Resilient
- **Status**: ⬜ Not started
- **Effort**: S (2 hours)
- **Priority**: Job board shouldn't crash

**Goal**: Handle API failures gracefully (timeouts, 429, 500, malformed JSON)

**Tasks**:
- [ ] Wrap Greenhouse fetch in proper error handling
- [ ] Wrap Lever fetch in proper error handling
- [ ] Handle 429 rate limit → log warning, return []
- [ ] Handle 500 server error → log error, return []
- [ ] Handle timeout → log error, return []
- [ ] Handle malformed JSON → log error, return []
- [ ] Add tests for each error scenario (WebMock)
- [ ] Rake task `jobs:board` continues if one source fails
- [ ] Dashboard shows partial results if one fetcher fails

**Verify**:
```bash
# Stub API failure
rails runner "
  allow(HTTParty).to receive(:get).and_raise(Timeout::Error)
  result = JobWizard::Fetchers::Greenhouse.new.fetch('test')
  puts result.empty? ? '✅ Handled gracefully' : '❌ Should return []'
"

# Real test
bundle exec rspec spec/services/job_wizard/fetchers/greenhouse_spec.rb
```

**Files**:
- `app/services/job_wizard/fetchers/greenhouse.rb:13-22` - Better error handling
- `app/services/job_wizard/fetchers/lever.rb:13-22` - Better error handling
- `spec/services/job_wizard/fetchers/greenhouse_spec.rb` - New tests
- `spec/services/job_wizard/fetchers/lever_spec.rb` - New tests

---

### 🔴 Step 5: Add Controller Tests
- **Status**: ⬜ Not started
- **Effort**: M (6-8 hours)
- **Priority**: Core flows untested

**Goal**: Test main user flows (prepare → finalize, quick_create, download)

**Tasks**:
- [ ] Create `spec/requests/applications_controller_spec.rb`
- [ ] Test `POST /applications/prepare` stores session data
- [ ] Test `POST /applications/finalize` creates application + PDFs
- [ ] Test `POST /applications/quick_create` works from dashboard
- [ ] Test `GET /applications/:id` shows generated PDFs
- [ ] Test `GET /applications/:id/resume` downloads PDF
- [ ] Test session expiration handling
- [ ] Test skill selection flow
- [ ] Add `spec/system/generate_resume_spec.rb` for end-to-end test
- [ ] System test: paste JD → review → generate → download

**Verify**:
```bash
bundle exec rspec spec/requests/applications_controller_spec.rb
bundle exec rspec spec/system/generate_resume_spec.rb
```

**Files**:
- `spec/requests/applications_controller_spec.rb` - New
- `spec/system/generate_resume_spec.rb` - New
- `spec/support/factory_bot.rb` - Add factories

---

## Phase 2: UX & Performance (P2) - Week 2

### 🟡 Step 6: Add Loading States
- **Status**: ⬜ Not started
- **Effort**: M (3-4 hours)
- **Priority**: UX polish

**Goal**: Show feedback during 2-5s PDF generation

**Tasks**:
- [ ] Add loading spinner overlay during PDF generation
- [ ] Change button text to "⏳ Generating..."
- [ ] Disable button during processing (prevent double-submit)
- [ ] Add progress steps: Input (1/3) → Review (2/3) → Download (3/3)
- [ ] Auto-scroll to results after generation
- [ ] Add estimated time: "Usually takes 2-5 seconds"
- [ ] Turbo Stream for dynamic updates (no full page reload)
- [ ] Mobile-friendly loading overlay

**Verify**:
```bash
# Manual test
1. Paste JD, click Generate
2. Should immediately see spinner
3. Button should be disabled
4. After 2-3s, should auto-scroll to results
```

**Files**:
- `app/views/applications/new.html.erb` - Add loading overlay
- `app/views/shared/_progress_steps.html.erb` - New partial
- `app/javascript/controllers/loading_controller.js` - New Stimulus controller (optional)

---

### 🟡 Step 7: Cache YAML Configs
- **Status**: ⬜ Not started
- **Effort**: S (1-2 hours)
- **Priority**: 3x faster PDF generation

**Goal**: Parse experience.yml once, cache in memory

**Tasks**:
- [ ] Add class-level cache to ExperienceLoader
- [ ] Cache invalidation on file mtime change
- [ ] Profile.yml also cached
- [ ] Rails.cache.fetch with 1-hour expiration (optional)
- [ ] Verify 50ms → 0.5ms speedup on cache hit
- [ ] Add test showing cache works
- [ ] Manual cache clear method for development

**Verify**:
```bash
# Benchmark before/after
rails runner "
  require 'benchmark'
  Benchmark.bm do |x|
    x.report('first call')  { JobWizard::ExperienceLoader.new }
    x.report('cached call') { JobWizard::ExperienceLoader.new }
  end
"
# Should show 100x speedup on second call
```

**Files**:
- `app/services/job_wizard/experience_loader.rb:11-22` - Add caching
- `spec/services/job_wizard/experience_loader_spec.rb` - Add cache tests

---

### 🟡 Step 8: Add Database Indexes
- **Status**: ⬜ Not started
- **Effort**: S (1 hour)
- **Priority**: Faster dashboard

**Goal**: Speed up dashboard queries

**Tasks**:
- [ ] Add index on `applications.created_at DESC`
- [ ] Add index on `job_postings.source`
- [ ] Add composite index `[:remote, :posted_at]` for remote job filtering
- [ ] Run migration
- [ ] Verify query speed improvement (EXPLAIN ANALYZE)
- [ ] Dashboard load time improves (250ms → <100ms)

**Verify**:
```bash
# Check indexes
rails dbconsole
.schema applications
.schema job_postings

# Benchmark
rails runner "
  require 'benchmark'
  Benchmark.bm do |x|
    x.report('dashboard') { Application.order(created_at: :desc).limit(6).to_a }
  end
"
```

**Files**:
- `db/migrate/YYYYMMDD_add_local_performance_indexes.rb` - New migration

---

### 🟡 Step 9: Improve Error Messages
- **Status**: ⬜ Not started
- **Effort**: S (2-3 hours)
- **Priority**: Better debugging

**Goal**: Replace generic errors with actionable messages

**Tasks**:
- [ ] Create custom exception classes (ConfigError, SkillValidationError)
- [ ] Rescue specific exceptions in controllers
- [ ] Show helpful error messages per error type
- [ ] Config error → "Check your profile.yml"
- [ ] Skill error → "Some JD skills don't match experience.yml"
- [ ] PDF error → "Font issue - contact support"
- [ ] Add error recovery suggestions
- [ ] Log errors with context (not just exception message)

**Verify**:
```bash
# Manual test
1. Delete profile.yml
2. Try to generate PDF
3. Should see: "Configuration error: profile.yml not found. Please check config/job_wizard/profile.yml"
```

**Files**:
- `app/services/job_wizard/errors.rb` - New exception classes
- `app/controllers/applications_controller.rb:54-57` - Better rescue blocks

---

## Phase 3: Documentation (P3) - Week 3

### 🟢 Step 10: Create Local Documentation
- **Status**: ⬜ Not started
- **Effort**: M (4-5 hours)
- **Priority**: Reference for future

**Tasks**:
- [ ] Create `docs/ENV_VARS.md` - All 6 ENV variables documented
- [ ] Create `docs/LOCAL_ONLY.md` - Local setup guide ✅ DONE
- [ ] Create `bin/setup` script - Automated setup
- [ ] Update `README.md` - Add local-only quick start
- [ ] Add FAQ section to README
- [ ] Add troubleshooting section
- [ ] Document Finder integration workflow
- [ ] Document background job configuration (:async)
- [ ] Add shell aliases for common tasks
- [ ] Create `.env.example` file

**Verify**:
```bash
# Test bin/setup on fresh clone
git clone [repo] /tmp/jobwizard-test
cd /tmp/jobwizard-test
./bin/setup
# Should complete without errors, create example configs
```

**Files**:
- `docs/ENV_VARS.md` - New
- `docs/LOCAL_ONLY.md` - ✅ Already created
- `bin/setup` - New executable script
- `README.md` - Update
- `.env.example` - New

---

## Removed Tasks (Not Needed for Local-Only)

### 🚫 Authentication (Skipped)
**Why**: Single-user local app, no network exposure, no need for login

### 🚫 Production Deployment Guide (Skipped)
**Why**: Never deploying to production, Heroku, or VPS

### 🚫 Error Monitoring (Sentry/Rollbar) (Skipped)
**Why**: Local logs sufficient, no production errors to monitor

### 🚫 Multi-Environment Configuration (Skipped)
**Why**: Only development environment exists

---

## Progress Summary

### Phase 1: Truth-Safety & Core (Week 1)
- [ ] 0/5 tasks complete
- [ ] Estimated: 13-19 hours
- [ ] **Focus**: Prove core promise, protect filesystem

### Phase 2: UX & Performance (Week 2)
- [ ] 0/4 tasks complete
- [ ] Estimated: 7-11 hours
- [ ] **Focus**: Speed and polish

### Phase 3: Documentation (Week 3)
- [ ] 0/1 task complete (LOCAL_ONLY.md done!)
- [ ] Estimated: 4-5 hours
- [ ] **Focus**: Future reference

### **Overall**
- **Total Tasks**: 0/10 complete (0%)
- **Estimated Total**: 25-35 hours
- **Target Completion**: 3 weeks
- **Current Sprint**: Truth-Safety & Core

---

## Weekly Milestones

### Week 1: Truth-Safety ✅
- [ ] Truth-safety tests prove no fabrication
- [ ] Path traversal vulnerability fixed
- [ ] File uploads validated
- [ ] Fetchers handle API failures gracefully
- [ ] Controller tests cover main flows
- **Deliverable**: Trustworthy, resilient core

### Week 2: Speed & Polish 🚀
- [ ] Loading states during PDF generation
- [ ] YAML configs cached (50ms → 0.5ms)
- [ ] Database indexed (250ms → <100ms)
- [ ] Error messages helpful and actionable
- **Deliverable**: Fast, smooth UX

### Week 3: Documentation 📚
- [ ] ENV vars fully documented
- [ ] bin/setup works on fresh clone
- [ ] README has local-only quick start
- [ ] Troubleshooting guide complete
- **Deliverable**: Easy to maintain and extend

---

## Acceptance Criteria (All Tasks)

Every task must:
- ✅ Code changes implemented
- ✅ Tests written and passing
- ✅ Rubocop clean (no new offenses)
- ✅ Manual testing completed
- ✅ Documentation updated (if behavior changes)
- ✅ Works on fresh `bin/dev` restart

---

## Quick Commands

### Run All Tests
```bash
bundle exec rspec --format documentation
```

### Check Coverage
```bash
bundle exec rspec
open coverage/index.html
```

### Lint Code
```bash
bundle exec rubocop -A
```

### Verify Truth-Safety
```bash
./test/verify_truth_safety.sh  # (create this in Step 1)
```

### Benchmark Performance
```bash
./test/benchmark_local.sh  # (create this in Step 7)
```

---

## Current Sprint (Week 1)

**In Progress**: None  
**Up Next**: Step 1 (Truth-Safety Tests)  
**Blocked**: None

**This Week's Goal**: Complete Steps 1-5 (Truth-safety & core functionality)

---

**Last Review**: 2025-10-21 (Initial audit)  
**Next Review**: After Week 1 completion

