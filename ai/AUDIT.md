# JobWizard Deep Audit - October 2025

**Date**: 2025-10-23  
**Scope**: Full repository scan for local-only compliance, security, UX, and code quality  
**Method**: Deep scan + existing audit reviews + live code inspection

---

## Executive Summary

**Current State**: JobWizard is a functional local-only Rails 8 app with:
- ✅ HTML sanitization (via `HtmlCleaner`)
- ✅ Truth-only PDF generation
- ✅ Local SQLite storage
- ✅ AI cost tracking (newly added)
- ⚠️ Missing: search, advanced filters, dedupe, fetch scheduling
- ⚠️ Partial: status management (enum exists but incomplete workflow)

**Risk Profile**:
- 🔴 **HIGH**: 1 item (path traversal in PDF output)
- 🟡 **MEDIUM**: 3 items (dedupe, status workflow, HTML edge cases)
- 🟢 **LOW**: 7 items (UX improvements, tests, docs)

---

## A) Security & Safety

### A1: HTML Sanitization - VERIFIED ✅ **[AUTO]**
**Status**: Already implemented correctly  
**File**: `app/services/job_wizard/html_cleaner.rb`  
**Risk**: LOW

**Current Implementation**:
```ruby
def self.clean(html_content)
  decoded = CGI.unescapeHTML(html_content)
  # Strip tags, decode entities, preserve spacing
  cleaned.gsub(/<[^>]+>/, '').gsub(/&nbsp;/, ' ')...
end
```

**Used By**:
- `Greenhouse.extract_description` ✅
- `Lever.extract_description` ✅  
- Smoke test exists: `test/smoke_test_job_description_cleaning.sh` ✅

**Action**: Add unit test, verify edge cases (nested entities, malformed HTML).

---

### A2: Path Traversal in PDF Output - HIGH RISK 🔴 **[AUTO]**
**File**: `app/services/job_wizard/pdf_output_manager.rb:79-91`  
**Risk**: HIGH  
**Attack**: `company = "../../etc"` could write outside intended directory

**Current Code**:
```ruby
def slugify(text)
  text.gsub(/[^a-zA-Z0-9\s-]/, '')  # Removes dots, but AFTER path check
      .gsub(/\s+/, '-')
end
```

**Fix** (apply immediately):
```ruby
def slugify(text)
  # Reject dangerous patterns FIRST
  raise ArgumentError, "Invalid path characters" if text.to_s =~ /\.\.|\//
  
  text.to_s.gsub(/[^a-zA-Z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .strip
      .downcase[0..100]  # Length limit
end
```

---

### A3: URL Validation in Job Listings - MEDIUM 🟡 **[AUTO]**
**File**: `app/views/jobs/show.html.erb:24`  
**Brakeman Warning**: "Potentially unsafe model attribute in link_to href"

**Current**:
```erb
<%= link_to "Apply →", @job.url, target: "_blank" %>
```

**Risk**: If `@job.url` contains `javascript:alert(1)`, XSS possible  
**Fix**: Validate URLs on save:
```ruby
# app/models/job_posting.rb
validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
```

---

### A4: Session Data Integrity - MEDIUM 🟡 **[AUTO]**
**File**: `app/controllers/applications_controller.rb:73-89`  
**Risk**: MEDIUM (local-only context reduces risk)

**Current**:
```ruby
session[:application_prepare] = {
  job_description: job_description,
  verified_skills: verified,
  # ...untrusted data
}
```

**Fix**: Sign session data or use encrypted cookies (Rails default is signed, but validate structure):
```ruby
prepare_data = session[:application_prepare]
unless prepare_data.is_a?(Hash) && prepare_data[:job_description].present?
  redirect_to new_application_path, alert: 'Invalid session data'
  return
end
```

---

## B) Correctness & Data

### B1: Duplicate Job Detection - MISSING 🟡 **[AUTO]**
**Risk**: MEDIUM  
**Problem**: Fetching same company multiple times creates duplicates

**Current**: No unique constraint on `(source, external_id)` or `(company, title, url)`

**Fix**:
```ruby
# Migration
add_index :job_postings, [:source, :external_id], unique: true, where: "external_id IS NOT NULL"

# Fetcher logic
def upsert_job(job_data)
  JobPosting.find_or_initialize_by(
    source: job_data[:source],
    external_id: job_data[:metadata][:greenhouse_id] || job_data[:metadata][:lever_id]
  ).tap do |job|
    job.assign_attributes(job_data)
    job.last_seen_at = Time.current
    job.save!
  end
end
```

---

### B2: Status Workflow Incomplete - MEDIUM 🟡 **[AUTO]**
**File**: `app/models/job_posting.rb`  
**Problem**: Status enum exists but workflow incomplete

**Current**:
- `status` enum: suggested/applied/ignored/exported ✅
- `mark_applied!`, `mark_exported!` exist ✅
- BUT: No `mark_ignored!`, no prevention of re-activation

**Fix**:
```ruby
# app/models/job_posting.rb
def mark_ignored!(reason: nil)
  update!(status: 'ignored', ignored_at: Time.current, notes: reason)
end

# In fetcher: never flip ignored -> suggested
def upsert_job(job_data)
  job = JobPosting.find_or_initialize_by(...)
  
  # Preserve manual statuses
  if job.persisted? && job.status.in?(%w[applied ignored exported])
    job.last_seen_at = Time.current
    job.save!(touch: false) # Don't reset status
  else
    job.assign_attributes(job_data.merge(status: 'suggested'))
    job.save!
  end
end
```

---

### B3: Timestamps & Posted Date - LOW 🟢 **[AUTO]**
**Problem**: `posted_at` not always extracted from API

**Fix**:
- Greenhouse: Use `updated_at` (already done ✅)
- Lever: Use `created_at` (already done ✅)
- Add `last_seen_at` to track "still active" ✅ (needs migration)

---

## C) UX & Accessibility

### C1: Search - MISSING 🟢 **[AUTO]**
**Priority**: HIGH for usability  
**Current**: No search on `/jobs`

**Implementation**:
```ruby
# Use simple LIKE (SQLite compatible, no FTS complexity for MVP)
scope :search, ->(query) {
  where("company LIKE ? OR title LIKE ? OR description LIKE ?",
        "%#{sanitize_sql_like(query)}%",
        "%#{sanitize_sql_like(query)}%",
        "%#{sanitize_sql_like(query)}%")
}

# Controller
@jobs = JobPosting.board_visible
@jobs = @jobs.search(params[:q]) if params[:q].present?
```

**Future**: Upgrade to FTS5 if search becomes slow (>1000 jobs).

---

### C2: Filters - PARTIAL 🟢 **[AUTO]**
**Current**: Remote filter exists via matcher  
**Missing**: Status, date range, score

**Fix**:
```ruby
# Add scopes
scope :posted_since, ->(days) { where("posted_at >= ?", days.days.ago) }
scope :min_score, ->(score) { where("score >= ?", score) }

# UI: dropdown for 7/14/30 days, score slider
```

---

### C3: Keyboard Shortcuts - LOW 🟢 **[ASK]**
**Nice-to-have**: `j/k` navigation, `/` search, `a` apply, `i` ignore  
**Effort**: MEDIUM (requires Stimulus controller)  
**Tag**: **[ASK]** - not critical for local-only use

---

### C4: "Check for New Jobs" Button - MISSING 🟢 **[AUTO]**
**Current**: Must run `rake jobs:fetch` manually  
**Fix**: Add button that enqueues `FetchJobsJob`

```ruby
# app/jobs/fetch_jobs_job.rb
class FetchJobsJob < ApplicationJob
  queue_as :default
  
  def perform
    JobWizard::JobFetcher.fetch_all  # Wrap existing rake task logic
  end
end

# Button in dashboard
<%= button_to "Check for New Jobs", fetch_jobs_path, method: :post, class: "..." %>
```

---

## D) Reliability & Jobs

### D1: Background Job Adapter - VERIFIED ✅ **[AUTO]**
**Current**: Using `:async` (in-memory) ✅  
**File**: `config/application.rb:27`

```ruby
config.active_job.queue_adapter = :async
```

**Risk**: Jobs lost on restart (acceptable for local-only)  
**Future**: Add `:solid_queue` if user wants persistence (Rails 8 default)

---

### D2: Idempotent Fetch - PARTIAL 🟡 **[AUTO]**
**Problem**: Running fetch twice creates dupes (see B1)  
**Fix**: Implement upsert logic (covered in B1)

---

### D3: Optional Dev Scheduler - MISSING 🟢 **[AUTO]**
**Request**: ENV-gated auto-fetch every N minutes

**Implementation**:
```ruby
# config/initializers/dev_scheduler.rb
if Rails.env.development? && ENV['JOB_WIZARD_SCHEDULE_FETCH'].present?
  interval = ENV['JOB_WIZARD_SCHEDULE_FETCH'] # e.g., "10m"
  seconds = interval.to_i * 60
  
  Thread.new do
    loop do
      sleep seconds
      FetchJobsJob.perform_later rescue nil
    end
  end
end
```

**Tag**: **[AUTO]** - simple, safe, ENV-gated

---

## E) Local-Only Compliance

### E1: No Hard Cloud Dependencies - VERIFIED ✅
**Status**: PASS  
- SQLite ✅
- ActiveJob :async ✅
- No Redis/Sidekiq unless optional ✅
- No hosted services ✅

---

### E2: OpenAI Dependency - VERIFIED ✅
**Status**: Optional with fallback ✅  
**File**: `app/services/job_wizard/writers/open_ai_writer.rb`

Falls back to `TemplatesWriter` if key missing ✅

---

## F) Code Health

### F1: Test Coverage - LOW 🟢 **[AUTO]**
**Current**: 1.51% line coverage (from test run)  
**Target**: 60%+ for critical paths

**Priority Tests**:
1. `HtmlCleaner` unit tests (edge cases)
2. Fetcher dedupe logic
3. Status workflow (prevent re-activation)
4. PDF path slugify validation
5. Search/filter scopes

---

### F2: Rubocop - NEEDS RUN 🟢 **[AUTO]**
**Action**: Run `bundle exec rubocop -A` and fix

---

### F3: Missing Service Tests - MEDIUM 🟢 **[AUTO]**
**Files Missing Tests**:
- `app/services/jd/summarizer.rb` ❌
- `app/services/jd/skill_extractor.rb` ❌
- `app/services/ai_cost/recorder.rb` ❌

---

## Implementation Priority

### IMMEDIATE (Auto-implement now):
1. ✅ A2: Path traversal fix (slugify validation)
2. ✅ B1: Dedupe migration + upsert logic
3. ✅ B2: Status workflow completion
4. ✅ C1: Search implementation
5. ✅ C2: Filter additions
6. ✅ C4: "Check for New Jobs" button
7. ✅ F1: Critical tests (HtmlCleaner, dedupe, status)
8. ✅ F2: Rubocop fixes

### DEFERRED (Ask user first):
- C3: Keyboard shortcuts (**[ASK]**)
- D3: Dev scheduler (simple, will implement)

---

## Summary of Changes Needed

| ID | Task | Files | Lines | Risk | Auto? |
|----|------|-------|-------|------|-------|
| A2 | Path traversal fix | pdf_output_manager.rb | ~5 | 🔴 HIGH | ✅ |
| A3 | URL validation | job_posting.rb | ~3 | 🟡 MED | ✅ |
| B1 | Dedupe logic | migration, fetchers | ~40 | 🟡 MED | ✅ |
| B2 | Status workflow | job_posting.rb, fetchers | ~30 | 🟡 MED | ✅ |
| B3 | Timestamps | migration | ~5 | 🟢 LOW | ✅ |
| C1 | Search | jobs_controller, view | ~25 | 🟢 LOW | ✅ |
| C2 | Filters | job_posting.rb, view | ~30 | 🟢 LOW | ✅ |
| C4 | Fetch button | job, controller, view | ~35 | 🟢 LOW | ✅ |
| D3 | Dev scheduler | initializer | ~15 | 🟢 LOW | ✅ |
| F1 | Tests | spec/ | ~200 | 🟢 LOW | ✅ |
| F2 | Rubocop | various | ~50 | 🟢 LOW | ✅ |

**Total Estimate**: ~440 lines changed, 8-10 commits

---

## Not Implementing (Out of Scope)

1. **Authentication** - Local-only app, single user assumed
2. **Keyboard shortcuts** - Not critical, requires significant JS
3. **FTS5 search** - Simple LIKE sufficient for now (<1000 jobs)
4. **Virus scanning** - Local files only, low risk

---


