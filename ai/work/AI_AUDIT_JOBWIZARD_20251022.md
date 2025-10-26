# AI Audit: JobWizard
**Date**: October 22, 2025  
**Auditor**: AI Senior Rails Auditor  
**Repository**: JobWizard - Local-only Job Board & Résumé Tailoring Tool

---

## 🧭 Summary

JobWizard is a Rails 8 application designed exclusively for local use on macOS. It fetches job postings from Greenhouse and Lever APIs, filters for Ruby/Rails roles, and generates truth-only résumé and cover letter PDFs using user-defined YAML configuration files. The app includes sophisticated filtering (company blocklists, content filtering, security clearance detection), skill assessment per job, and comprehensive job status management.

**Current State**: The codebase is well-structured with solid Rails conventions, comprehensive services layer, and growing test coverage. Recent additions include filtering/rules engine, per-job skill assessments, and HTML sanitization. The app successfully balances feature richness with maintainability, though there are opportunities for refinement given its local-only nature.

**Key Observations**:
- **Strengths**: Clean service objects, truth-only PDF generation, comprehensive filtering system, good separation of concerns
- **Opportunities**: Database migration issue (UUID on SQLite), redundant async job complexity for local use, potential for better local file management, some test gaps
- **Local-First Win**: The constraint of being local-only opens up simplification opportunities (synchronous processing, direct file access, no auth needed)

---

## ⚙️ Code Quality

### Maintainability & DRYness

**✅ Strengths:**
1. **Service Objects**: Excellent use of service objects in `app/services/job_wizard/`. Each has a clear, single responsibility (e.g., `HtmlCleaner`, `RulesEngine`, `EffectiveSkillsService`).
2. **Consistent Naming**: Controllers, models, and services follow Rails conventions consistently.
3. **Separation of Concerns**: PDF generation, rules scanning, and skill detection are properly isolated.

**⚠️ Areas for Improvement:**

1. **Duplicate PDF Generation Code** (HIGH IMPACT)
   - `ApplicationsController#generate_pdfs` (lines 262-286)
   - `ApplicationsController#generate_pdfs_with_skills` (lines 233-260)
   - `JobsController#tailor` (lines 43-62)
   - `GeneratePdfsJob#perform` (lines 24-41)
   
   **Impact**: ~80 lines of duplication across 4 locations
   
   **Recommendation**: Extract to `JobWizard::ApplicationPdfGenerator` service:
   ```ruby
   class JobWizard::ApplicationPdfGenerator
     def initialize(application, allowed_skills: nil, job_posting: nil)
       @application = application
       @allowed_skills = allowed_skills
       @job_posting = job_posting
     end
     
     def generate!
       builder = JobWizard::ResumeBuilder.new(
         job_description: @application.job_description,
         allowed_skills: @allowed_skills,
         job_posting: @job_posting
       )
       manager = JobWizard::PdfOutputManager.new(
         company: @application.company,
         role: @application.role,
         timestamp: @application.created_at || Time.current
       )
       
       manager.ensure_directories!
       manager.write_resume(builder.build_resume)
       manager.write_cover_letter(builder.build_cover_letter)
       manager.update_latest_symlink!
       
       @application.update(output_path: manager.display_path, status: :generated)
     end
   end
   ```

2. **UUID Migration Issue** (CRITICAL BUG)
   - `db/migrate/20251021231000_create_job_skill_assessments.rb` uses `type: :uuid` but SQLite doesn't support UUID types
   - Current schema dump shows: `# Could not dump table "job_skill_assessments" because of following StandardError`
   - **Fix**: Change `t.references :job_posting, null: false, foreign_key: true, type: :uuid` to `t.integer :job_posting_id, null: false` in migration

3. **Skill Extraction Duplication** (MEDIUM IMPACT)
   - `JobsController#extract_skills_from_description` (lines 103-110) uses simple array matching
   - `ResumeBuilder#extract_skills_from_jd` (lines 135-150) uses comprehensive regex
   - **Recommendation**: Consolidate into `JobWizard::SkillDetector` (which already exists) and make it the single source of truth

4. **Inconsistent Error Handling**
   - Some controllers rescue StandardError, others don't
   - Recommendation: Add `rescue_from` at ApplicationController level for consistent local error display

### Suggested Service Refactors

1. **Create `JobWizard::JobStatusManager`**
   - Consolidate job status transitions (mark_applied!, mark_exported!, ignore)
   - Add state machine validation (e.g., can't mark as applied if already exported)
   - Include audit trail for status changes

2. **Extract `JobWizard::FetchCoordinator`**
   - Currently `lib/tasks/jobs.rake` has complex fetch logic (~220 lines)
   - Move business logic out of rake task into service for testability
   - Rake task becomes thin wrapper calling `FetchCoordinator.run(provider, slug)`

3. **Create `JobWizard::SkillAssessmentManager`**
   - Consolidate skill extraction, assessment, and effective skills calculation
   - Single entry point for skill-related operations
   - Better caching of extracted skills per job

### Test Coverage Recommendations

**Current Coverage**: Good service test coverage, some model tests, minimal controller/integration tests

**Missing Tests** (by priority):
1. **Integration Tests for PDF Generation Flow** - No end-to-end test covering: fetch job → tailor → verify PDFs exist on disk
2. **Controller Tests for FiltersController** - Basic request specs exist but missing edge cases
3. **System Tests for Job Board Workflow** - Only one navigation spec exists
4. **Rules Engine Integration with Fetchers** - Tests for RulesEngine exist, but not integrated with actual fetchers
5. **Skill Assessment Workflow** - No test covering: view job → assess skills → generate PDF with those assessments

**Specific Test Files to Create**:
```
spec/integration/pdf_generation_flow_spec.rb  # End-to-end PDF generation
spec/integration/job_filtering_flow_spec.rb   # Fetch → filter → display
spec/system/job_application_workflow_spec.rb  # Full user workflow
spec/services/job_wizard/application_pdf_generator_spec.rb  # New service
spec/lib/tasks/jobs_rake_spec.rb  # Rake task behavior
```

### Code Smells to Address

1. **Long Parameter Lists**
   - `JobWizard::ResumeBuilder.new(job_description:, allowed_skills:, job_posting:)`
   - Consider using a parameter object or builder pattern

2. **Feature Envy**
   - `ApplicationsController` knows too much about `PdfOutputManager` and `ResumeBuilder` internals
   - Solution: Proposed `ApplicationPdfGenerator` service

3. **Primitive Obsession**
   - Skills represented as arrays of strings everywhere
   - Consider `Skill` value object with `name`, `verified`, `proficiency` attributes

4. **Magic Strings**
   - Status strings like 'suggested', 'applied', 'exported' used inconsistently
   - Fixed in models with enum, but still raw strings in some service code

---

## 🧩 Features & UX

### High-Impact Usability Features

1. **"Open in Finder" Button for Generated PDFs** (HIGH IMPACT, LOW EFFORT)
   - Currently user sees "output_path" as text
   - Add button that calls `open` command to reveal PDF folder
   - Uses existing `FilesController#reveal` pattern
   - **Implementation**:
     ```ruby
     # In applications/show.html.erb
     <%= button_to "Open PDFs in Finder", 
       files_reveal_path(path: @application.output_path), 
       method: :post, 
       class: "btn-primary" %>
     ```

2. **Job Board Bulk Actions** (HIGH IMPACT, MEDIUM EFFORT)
   - Select multiple jobs and perform bulk actions (ignore, export all, block company)
   - Checkbox selection with "Select All" toggle
   - Action bar that appears when jobs are selected
   - Reduces repetitive clicking for managing many jobs

3. **PDF Preview Before Download** (MEDIUM IMPACT, MEDIUM EFFORT)
   - Use PDF.js or browser native PDF viewing
   - Allows quick review before applying
   - Show side-by-side résumé and cover letter
   - **Alternative**: Markdown preview of content before PDF generation

4. **Smart Job Deduplication** (MEDIUM IMPACT, LOW EFFORT)
   - Same job posted on multiple boards shows up multiple times
   - Add fuzzy matching on (company + title) with 90% similarity threshold
   - UI shows "Similar to X other jobs" with merge option

5. **Application Templates** (LOW IMPACT, HIGH VALUE)
   - Save different "profiles" (e.g., "Backend Heavy", "Full Stack", "Remote Only")
   - Each template has different skill emphasis, allowed_skills, company blocklists
   - Switch between templates when generating PDFs

6. **Job Notes & Tracking** (MEDIUM IMPACT, LOW EFFORT)
   - Add `notes` text field to `job_postings` and `applications`
   - Track: application date, follow-up dates, interview stages, salary discussed
   - Converts JobWizard into mini applicant tracking system

### Low-Impact Quality-of-Life Improvements

1. **Keyboard Shortcuts**
   - `j`/`k` for navigate jobs (Vim-style)
   - `t` for "Tailor & Export" selected job
   - `i` for ignore, `a` for mark applied
   - Use Stimulus controller for keyboard handling

2. **Dark Mode**
   - Add theme toggle (saves to localStorage)
   - Tailwind already supports dark mode classes
   - Minimal changes needed

3. **Job Count Badges**
   - Show counts in navigation: "Jobs (15)", "Blocked Companies (3)"
   - Updates live with Turbo Streams

4. **Recent Companies Quick Filter**
   - Sidebar showing recently seen companies
   - Click to filter jobs by company
   - Uses `JobPosting.group(:company).count`

5. **Export Applications to CSV**
   - Export all applications with metadata for external tracking
   - Headers: Company, Role, Applied Date, Status, PDF Path
   - One rake task: `rake jobs:export_csv`

6. **Syntax Highlighting for JD**
   - Highlight matched keywords (Ruby, Rails) in green
   - Highlight exclusion keywords (PHP, .NET) in red
   - Makes filtering logic visually obvious

### UI Polish Ideas

1. **Consistent Button Styles** (Partially Done)
   - Current: Mix of `button_to` and `link_to` with various Tailwind classes
   - Create helper methods:
     - `primary_button`, `secondary_button`, `danger_button`
     - Ensures consistency and easier redesign

2. **Loading States**
   - "Tailor & Export" shows spinner while generating PDFs
   - Use Turbo Frame with loading="lazy" attribute
   - Prevents duplicate clicks

3. **Empty States**
   - Better messaging when no jobs found
   - Show "No jobs match your filters" with suggestions
   - Onboarding for first-time use: "Add a job source first"

4. **Toast Notifications Instead of Flash**
   - Use Stimulus + Tailwind for slide-in toasts
   - Auto-dismiss after 3 seconds
   - Stack multiple notifications

5. **Job Card Hover States**
   - Show quick actions on hover (Apply, Ignore, Block)
   - Reduce visual clutter when not hovering
   - Better use of screen real estate

6. **Settings Organization**
   - Current `/settings/filters` could expand to tabs:
     - Filters & Blocklist
     - Profile & Experience
     - PDF Preferences
     - Export Settings

---

## 🧠 Architecture & Performance

### Local-Only Simplifications

**Since this app NEVER deploys**, you can simplify significantly:

1. **Remove Solid Queue / Async Job Complexity** (HIGH IMPACT)
   - Current: `GeneratePdfsJob` uses Solid Queue for async processing
   - **Reality**: PDF generation is ~200ms on local machine
   - **Recommendation**: Make PDF generation synchronous
   - **Benefits**:
     - Remove `solid_queue` gem dependency
     - Simpler error handling (no retry logic needed)
     - Instant feedback to user
     - One less background process running
   - **Implementation**: Just call `ApplicationPdfGenerator.new(...).generate!` directly

2. **Simplify File Storage** (MEDIUM IMPACT)
   - Current: Both database `output_path` AND file-on-disk
   - **Recommendation**: Make filesystem the source of truth
   - **Pattern**:
     ```ruby
     class Application
       def pdf_directory
         PdfOutputManager.directory_for(company: company, role: role, timestamp: created_at)
       end
       
       def resume_path
         File.join(pdf_directory, 'resume.pdf')
       end
       
       def pdfs_ready?
         File.exist?(resume_path) && File.exist?(cover_letter_path)
       end
     end
     ```
   - **Benefit**: Eliminates sync issues between DB and filesystem

3. **Skip Solid Cache** (LOW IMPACT)
   - Current: Using `solid_cache` for Rails caching
   - **Local-only**: Memory store is simpler and faster
   - **Change**: `config/environments/development.rb` → `config.cache_store = :memory_store`

4. **Remove Kamal/Thruster/Deployment Gems** (LOW IMPACT)
   - Current: Gemfile includes `kamal`, `thruster`, `Dockerfile`
   - **Recommendation**: Clean up unused deployment artifacts
   - **Benefit**: Faster `bundle install`, clearer intent

### SQLite Optimizations

**Current Setup**: Uses SQLite3, which is perfect for local-only

**Optimizations**:

1. **Enable WAL Mode** (MEDIUM IMPACT)
   ```ruby
   # config/database.yml
   default: &default
     adapter: sqlite3
     pool: 5
     timeout: 5000
     journal_mode: wal  # Write-Ahead Logging for better concurrency
   ```

2. **Add Appropriate Indexes** (LOW IMPACT)
   - Current: Good index coverage
   - Missing: `index_applications_on_output_path` for path lookups
   - Missing: `index_job_postings_on_created_at` for recent job sorting

3. **Database Cleanup Automation** (LOW IMPACT)
   - Auto-run `rake jobs:clean` monthly via launchd (macOS cron alternative)
   - Or add to `whenever` gem (though adds dependency)

4. **Vacuum on Startup** (LOW IMPACT)
   ```ruby
   # config/initializers/sqlite_maintenance.rb
   Rails.application.config.after_initialize do
     ActiveRecord::Base.connection.execute('PRAGMA optimize')
   end
   ```

### Performance Wins

1. **Memoize Expensive Calls** (MEDIUM IMPACT)
   - `RulesScanner.scan` called multiple times for same JD
   - Cache scan results on Application model: `memoize :scan_results`

2. **Eager Load Associations** (LOW IMPACT)
   - `JobPosting.includes(:job_skill_assessments)` in index
   - Prevents N+1 queries when showing skill counts

3. **Partial Caching for Job Cards** (LOW IMPACT)
   - Cache individual job card renders
   - Cache key: `[job, job.updated_at, job.status]`

---

## 🪄 AI & Automation

### YAML Validation

**Current State**: No validation of `profile.yml` or `experience.yml` on startup

**Recommendations**:

1. **JSON Schema Validation** (HIGH IMPACT)
   - Create schema files: `config/job_wizard/schemas/profile.schema.json`
   - Validate on app boot and before PDF generation
   - Gem: `json-schema` or `dry-validation`
   - **Example**:
     ```ruby
     # app/services/job_wizard/yaml_validator.rb
     class JobWizard::YamlValidator
       def validate_profile!
         schema = JSON.parse(File.read(Rails.root.join('config/job_wizard/schemas/profile.schema.json')))
         data = YAML.safe_load_file(CONFIG_PATH.join('profile.yml'))
         JSON::Validator.validate!(schema, data)
       rescue JSON::Schema::ValidationError => e
         raise "Profile YAML invalid: #{e.message}"
       end
     end
     ```

2. **YAML Lint Task** (LOW IMPACT)
   ```ruby
   # lib/tasks/yaml.rake
   task :yaml_lint => :environment do
     JobWizard::YamlValidator.new.validate_all!
     puts "✓ All YAML files valid"
   end
   ```

3. **Autocomplete for Skills in UI** (MEDIUM IMPACT)
   - When adding skills in `experience.yml`, show autocomplete
   - Source: Common tech skills list + already used skills
   - Prevents typos and inconsistency

### Prompt Chain Opportunities

**Current State**: Uses `WriterFactory` for cover letter generation

**Enhancements**:

1. **Résumé Bullet Point QA** (HIGH IMPACT)
   - After generating résumé, run QA pass:
     - Check: All skills mentioned are in `experience.yml`
     - Check: No fabricated job titles or dates
     - Check: Proper grammar and consistency
   - Output: Warnings before finalizing PDF

2. **JD Analysis Pre-Summary** (MEDIUM IMPACT)
   - Before fetching, analyze JD for:
     - Required vs. nice-to-have skills
     - Estimated salary range (if mentioned)
     - Remote/hybrid/onsite clarity
     - Team size indicators
   - Store in `job_postings.metadata` JSON field

3. **Cover Letter Tone Customization** (LOW IMPACT)
   - Add setting: "Tone" → Formal | Conversational | Technical
   - Pass to `Writer` for adjusted generation
   - Store preference per company or globally

4. **Multi-Model Fallback** (LOW IMPACT)
   - Current: Single writer factory
   - Enhancement: Try GPT-4 first, fallback to Claude if error
   - Local-only benefit: No API rate limit concerns

### Automation Ideas

1. **Auto-Fetch on Schedule** (MEDIUM IMPACT)
   - Create launchd plist to run `rake jobs:board` daily
   - Benefit: Always have fresh jobs without manual trigger
   - **Implementation**:
     ```xml
     <!-- ~/Library/LaunchAgents/com.jobwizard.fetch.plist -->
     <plist>
       <dict>
         <key>Label</key>
         <string>com.jobwizard.fetch</string>
         <key>ProgramArguments</key>
         <array>
           <string>/Users/USER/.rbenv/shims/rake</string>
           <string>jobs:board</string>
         </array>
         <key>StartCalendarInterval</key>
         <dict>
           <key>Hour</key>
           <integer>9</integer>
         </dict>
       </dict>
     </plist>
     ```

2. **Smart Notification on New Jobs** (LOW IMPACT)
   - After fetch, if new Ruby/Rails jobs found, send macOS notification
   - Use `terminal-notifier` gem
   - **Example**: "5 new Rails jobs from Airbnb"

3. **Application Deadline Tracker** (MEDIUM IMPACT)
   - Extract application deadlines from JDs (e.g., "Apply by Oct 30")
   - Store in `applications.deadline_at`
   - Show "Expiring Soon" badge on job cards

4. **Backup YAML Files to Git** (LOW IMPACT)
   - Auto-commit `config/job_wizard/*.yml` changes
   - Creates version history of your profile/experience
   - Script: `bin/yaml-backup`

---

## 🔍 Testing & Developer Experience

### Test Coverage Gaps

**Current Test Files** (from spec/):
- ✅ Good: Service objects (RulesEngine, ExperienceLoader, etc.)
- ✅ Good: Model validations
- ⚠️ Partial: Request specs (missing FiltersController edge cases)
- ❌ Missing: Controller unit tests
- ❌ Missing: Integration/system tests
- ❌ Missing: Rake task tests

**Priority Test Coverage to Add**:

1. **End-to-End Workflows** (CRITICAL)
   ```ruby
   # spec/system/application_generation_spec.rb
   RSpec.describe 'Generating an application', type: :system do
     it 'creates PDFs and makes them accessible' do
       visit root_path
       fill_in 'Job Description', with: sample_jd
       click_button 'Generate PDFs'
       
       expect(page).to have_content('PDFs generated')
       expect(File.exist?(latest_resume_path)).to be true
       expect(File.exist?(latest_cover_letter_path)).to be true
     end
   end
   ```

2. **Controller Isolation Tests** (HIGH PRIORITY)
   - Test each controller action independently
   - Mock service calls to focus on controller logic
   - Verify correct params handling and redirects

3. **Service Integration Tests** (MEDIUM PRIORITY)
   - Test service collaborations (e.g., RulesEngine + Fetchers)
   - Verify RulesEngine correctly rejects jobs at fetch time

4. **Migration Rollback Tests** (LOW PRIORITY)
   - Verify migrations are reversible
   - Test down migrations don't lose data

### RSpec Utilities

**Recommended Additions**:

1. **Shared Examples for PDF Generation**
   ```ruby
   # spec/support/shared_examples/pdf_generation.rb
   RSpec.shared_examples 'a PDF generator' do
     it 'creates resume.pdf' do
       subject.generate!
       expect(File.exist?(subject.resume_path)).to be true
     end
     
     it 'creates cover_letter.pdf' do
       subject.generate!
       expect(File.exist?(subject.cover_letter_path)).to be true
     end
   end
   ```

2. **Factory Traits for Common Scenarios**
   ```ruby
   # spec/factories/job_postings.rb
   FactoryBot.define do
     factory :job_posting do
       trait :remote do
         remote { true }
         location { 'Remote' }
       end
       
       trait :with_clearance do
         description { 'Requires active security clearance' }
       end
       
       trait :blocked do
         after(:create) do |job|
           BlockedCompany.create!(name: job.company, reason: 'test')
         end
       end
     end
   end
   ```

3. **Custom Matchers**
   ```ruby
   # spec/support/matchers/pdf_matchers.rb
   RSpec::Matchers.define :have_generated_pdfs do
     match do |application|
       application.pdfs_ready? &&
         File.exist?(application.resume_path) &&
         File.exist?(application.cover_letter_path)
     end
   end
   ```

### Justfile Enhancements

**Current Justfile**: Good coverage of basic tasks

**Recommended Additions**:

1. **Fast Feedback Loop**
   ```makefile
   # Run tests for recently changed files
   test-changed:
     git diff --name-only HEAD | grep _spec.rb | xargs bundle exec rspec
   
   # Run tests affected by service changes
   test-services:
     bundle exec rspec spec/services
   ```

2. **Database Tasks**
   ```makefile
   # Fresh database with sample data
   db-fresh:
     bin/rails db:drop db:create db:migrate db:seed
   
   # Restore from backup
   db-restore path:
     cp {{path}} storage/development.sqlite3
   ```

3. **Quality Checks**
   ```makefile
   # Run all checks before committing
   pre-commit: lint test yaml-lint
     echo "✓ All checks passed"
   
   # Check for N+1 queries
   bullet:
     BULLET=true bin/rails server
   ```

4. **PDF Generation Testing**
   ```makefile
   # Generate test PDFs with sample data
   test-pdfs:
     bin/rails runner 'script/generate_test_pdfs.rb'
   
   # Open most recent PDF output
   open-latest:
     open ~/Documents/JobWizard/Applications/Latest/
   ```

### Local Safety Scripts

**Recommended Scripts**:

1. **YAML Validation** (`script/validate_yaml.rb`)
   ```ruby
   #!/usr/bin/env ruby
   require_relative '../config/environment'
   
   validator = JobWizard::YamlValidator.new
   
   begin
     validator.validate_profile!
     validator.validate_experience!
     validator.validate_rules!
     puts "✓ All YAML files valid"
   rescue => e
     puts "✗ YAML validation failed: #{e.message}"
     exit 1
   end
   ```

2. **Rules Verification** (`script/verify_rules.rb`)
   ```ruby
   # Test all filtering rules against sample JDs
   # Ensure no false positives/negatives
   ```

3. **PDF Integrity Check** (`script/check_pdfs.rb`)
   ```ruby
   # Verify all applications have PDFs on disk
   # Report orphaned PDFs or missing files
   ```

4. **Database Backup** (`script/backup_db.sh`)
   ```bash
   #!/bin/bash
   DATE=$(date +%Y%m%d)
   cp storage/development.sqlite3 ~/Backups/jobwizard_$DATE.sqlite3
   echo "Backed up to ~/Backups/jobwizard_$DATE.sqlite3"
   ```

---

## 🧱 Next Steps

### Short-Term Improvements (Ranked by Impact/Effort)

#### Must-Fix (Critical)

1. **Fix UUID Migration** ⚡ (5 min)
   - Change `type: :uuid` to `t.integer` in job_skill_assessments migration
   - Re-run `rake db:migrate`
   - Verify `rake db:schema:dump` succeeds

#### High-Impact, Low-Effort

2. **Extract PDF Generation Service** 🎯 (30 min)
   - Create `ApplicationPdfGenerator` service
   - Refactor 4 duplicate implementations
   - Reduces code by ~60 lines

3. **Add "Open in Finder" Buttons** 🎯 (15 min)
   - Use existing `files_reveal_path` helper
   - Add to application show page and dashboard cards
   - Dramatically improves UX for accessing PDFs

4. **Remove Async Job Complexity** 🎯 (45 min)
   - Make PDF generation synchronous
   - Remove `solid_queue` gem and configuration
   - Delete `GeneratePdfsJob`
   - Simplifies architecture significantly

#### High-Impact, Medium-Effort

5. **Add Bulk Actions to Job Board** 🎯 (2 hours)
   - Checkbox selection for jobs
   - Bulk ignore, export, block company
   - Uses Stimulus controller for state management

6. **Comprehensive Integration Tests** 🧪 (3 hours)
   - End-to-end PDF generation test
   - Job filtering flow test
   - Skill assessment workflow test

7. **Consolidate Skill Extraction** 🔧 (1 hour)
   - Make `SkillDetector` the single source of truth
   - Remove duplicate extraction logic
   - Add caching of extracted skills per job

#### Medium-Impact, Low-Effort

8. **YAML Schema Validation** 🛡️ (1 hour)
   - Add JSON Schema for profile/experience YAML
   - Validate on app boot
   - Prevents runtime errors from typos

9. **Add Missing Database Indexes** ⚡ (10 min)
   - `applications.output_path`
   - `job_postings.created_at`
   - Improves query performance

10. **Keyboard Shortcuts** ⌨️ (1 hour)
    - Stimulus controller for j/k navigation
    - Hotkeys for common actions
    - Power-user feature

### Longer-Term Enhancements

#### Architecture

1. **Filesystem as Source of Truth** (4 hours)
   - Remove `output_path` from database
   - Calculate paths from filesystem
   - Eliminates sync issues

2. **State Machine for Job Status** (2 hours)
   - Use `aasm` or `state_machines` gem
   - Add transition validations and callbacks
   - Better audit trail

3. **Value Objects for Domain Concepts** (3 hours)
   - `Skill` value object
   - `JobStatus` value object
   - `PdfPaths` value object
   - Reduces primitive obsession

#### Features

4. **Application Templates** (4 hours)
   - Multiple profiles (Backend, Full-Stack, etc.)
   - Different skill emphasis per template
   - Switch template when generating PDFs

5. **Job Notes & Tracking** (3 hours)
   - Add notes field to jobs and applications
   - Track interview stages, follow-ups
   - Mini applicant tracking system

6. **Smart Deduplication** (3 hours)
   - Fuzzy matching on company + title
   - Show "Similar to X jobs" UI
   - Merge duplicate entries

#### Testing

7. **Achieve 90%+ Test Coverage** (8 hours)
   - Add all missing controller tests
   - Complete system test suite
   - Add rake task tests
   - Shared examples for common patterns

#### Developer Experience

8. **Enhanced Justfile** (1 hour)
   - Add all recommended tasks
   - Fast feedback loops
   - Quality gates

9. **Local Safety Scripts** (2 hours)
   - YAML validator
   - Rules verifier
   - PDF integrity checker
   - Database backup

#### AI/Automation

10. **Launchd Integration** (1 hour)
    - Auto-fetch jobs daily
    - macOS notifications for new jobs
    - Automatic YAML backups

---

## 📊 Metrics & Priorities

### Priority Matrix

```
High Impact, Low Effort (DO FIRST):
- Fix UUID migration ⚡
- Extract PDF generation service 🎯
- Add "Open in Finder" buttons 🎯
- Remove async job complexity 🎯

High Impact, Medium Effort (DO NEXT):
- Bulk actions for jobs
- Integration test suite
- Consolidate skill extraction

Medium Impact, Low Effort (QUICK WINS):
- YAML validation
- Database indexes
- Keyboard shortcuts

Low Impact / Long-term:
- Dark mode
- Export to CSV
- Advanced templates
```

### Estimated Impact

| Change | LOC Reduced | Time Saved/Week | UX Improvement |
|--------|-------------|-----------------|----------------|
| PDF Service | -60 | - | - |
| Remove Async | -100 | 5 min | High |
| Bulk Actions | +150 | 20 min | Very High |
| Open in Finder | +10 | 10 min | Very High |
| YAML Validation | +50 | 30 min | Medium |

---

## 🎯 Recommended Action Plan

### Week 1: Critical Fixes & Quick Wins
1. Fix UUID migration (5 min)
2. Extract PDF generation service (30 min)
3. Add "Open in Finder" buttons (15 min)
4. Remove async job complexity (45 min)
5. Add YAML schema validation (1 hour)

**Total Time: ~3 hours**  
**Impact: Removes critical bug, simplifies architecture, dramatically improves UX**

### Week 2: High-Impact Features
1. Add bulk actions to job board (2 hours)
2. Consolidate skill extraction (1 hour)
3. Add missing database indexes (10 min)
4. Keyboard shortcuts (1 hour)

**Total Time: ~4 hours**  
**Impact: Power-user features, better code quality**

### Week 3: Testing & Safety
1. End-to-end integration tests (3 hours)
2. Local safety scripts (2 hours)
3. Enhanced Justfile (1 hour)

**Total Time: ~6 hours**  
**Impact: Confidence in changes, faster iteration**

### Week 4: Polish & Automation
1. Job notes & tracking (3 hours)
2. Smart deduplication (3 hours)
3. Launchd integration (1 hour)

**Total Time: ~7 hours**  
**Impact: JobWizard becomes daily driver for job search**

---

## 📝 Final Thoughts

JobWizard is a well-crafted Rails application that successfully leverages its local-only constraint for simplicity. The codebase is maintainable, follows Rails conventions, and implements sophisticated features (filtering, skill assessment, PDF generation) with clean service objects.

**Key Takeaway**: The biggest opportunity is to **lean into the local-only nature** even more:
- Remove unnecessary complexity (async jobs, deployment artifacts)
- Embrace filesystem as source of truth
- Add local-specific conveniences (Finder integration, launchd automation, macOS notifications)
- Focus on power-user features (bulk actions, keyboard shortcuts, templates)

The recommended changes prioritize:
1. **Fix critical bugs** (UUID migration)
2. **Reduce complexity** (consolidate PDF generation, remove async)
3. **Improve UX** (Open in Finder, bulk actions)
4. **Increase confidence** (more tests, validation)

With these improvements, JobWizard will be an even more powerful, maintainable, and delightful tool for your job search workflow.

---

**End of Audit** | Generated: October 22, 2025


