# JobWizard - Implementation Tracking (Local-Only)

**Last Updated**: 2025-10-21  
**Context**: 🏠 Single-user macOS app (no production deployment)  
**Sprint**: Truth-Safety & UX (Weeks 1-3)  
**Overall Progress**: 0/10 tasks complete

---

## Legend

- 🔴 **P1** - Critical for truth-safety or local functionality
- 🟡 **P2** - High value for local UX
- 🟢 **P3** - Nice to have, polish

**Status**:
- ⬜ Not started
- 🟦 In progress
- ✅ Complete
- ⛔ Blocked
- 🚫 Skipped (not needed for local-only)

---

## Phase 1: Truth-Safety & Core Functionality (P1 - Must Fix) - Week 1

### 🔴 Step 1: Add Truth-Safety Tests
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P1 - CRITICAL
- **Effort**: M (3-4 hours)
- **Risk**: HIGH - Core promise untested
- **Depends On**: None
- **Blocks**: None

**Description**:
Write comprehensive tests proving ResumeBuilder NEVER fabricates skills or experience not present in experience.yml.

**Acceptance Criteria**:
- [ ] `spec/services/job_wizard/resume_builder_spec.rb` created
- [ ] Test: JD skill NOT in experience.yml → skill NOT in PDF
- [ ] Test: JD skill IS in experience.yml → skill IS in PDF
- [ ] Test: `allowed_skills` filter correctly excludes unchecked skills
- [ ] Test: Skill levels (expert/intermediate/basic) phrase correctly
- [ ] Test: Work history only includes companies from experience.yml (no fabrication)
- [ ] Test: `not_claimed_skills` correctly identifies unverified skills
- [ ] PDF text extraction helper added (`spec/support/pdf_helper.rb`)
- [ ] All tests passing and green
- [ ] Coverage for ResumeBuilder increases to 80%+

**Files to Create**:
- `spec/services/job_wizard/resume_builder_spec.rb` - New comprehensive test
- `spec/support/pdf_helper.rb` - PDF text extraction utilities

**Testing**:
```bash
# Run truth-safety tests
bundle exec rspec spec/services/job_wizard/resume_builder_spec.rb

# Verify coverage
open coverage/index.html
# Check ResumeBuilder shows 80%+ coverage
```

**Example Test**:
```ruby
it 'never fabricates skills not in experience.yml' do
  jd = "Looking for Blockchain and Solidity expert with Ruby experience"
  builder = described_class.new(job_description: jd)
  
  pdf_text = extract_text_from_pdf(builder.build_resume)
  
  # Ruby is in experience.yml → should appear
  expect(pdf_text).to include('Ruby')
  
  # Blockchain and Solidity NOT in experience.yml → should NOT appear
  expect(pdf_text).not_to include('Blockchain')
  expect(pdf_text).not_to include('Solidity')
  
  # Verify not_claimed_skills tracks what was excluded
  expect(builder.not_claimed_skills).to include('Blockchain', 'Solidity')
end
```

**Resources**:
- pdf-inspector gem: https://github.com/prawnpdf/pdf-inspector
- RSpec best practices: https://rspec.info/

---

### 🔴 Step 2: Fix Path Traversal Vulnerability
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P1 - CRITICAL (Local Filesystem Protection)
- **Effort**: S (1-2 hours)
- **Risk**: HIGH - Could overwrite system files on macOS
- **Depends On**: None
- **Blocks**: None

**Description**:
Fix path traversal vulnerability in `PdfOutputManager#slugify` to prevent malicious company/role names from writing files outside the designated output directory.

**Acceptance Criteria**:
- [ ] `slugify` method rejects `..` (parent directory traversal)
- [ ] `slugify` method rejects `/` and `\` (absolute/relative path separators)
- [ ] `slugify` method rejects null bytes and special chars
- [ ] `slugify` truncates to 100 characters max
- [ ] `build_output_path` validates result is within `OUTPUT_ROOT`
- [ ] `ArgumentError` raised with helpful message for invalid characters
- [ ] `SecurityError` raised if computed path escapes OUTPUT_ROOT
- [ ] Tests verify all rejection cases
- [ ] Tests verify existing valid company names still work
- [ ] Manual test with malicious input: `../../etc/passwd`

**Files to Modify**:
- `app/services/job_wizard/pdf_output_manager.rb:79-91` - `slugify` method
- `app/services/job_wizard/pdf_output_manager.rb:93-107` - `build_output_path` validation
- `spec/services/job_wizard/pdf_output_manager_spec.rb` - Add security tests

**Testing**:
```bash
# Manual test
1. Paste JD with company "../../etc"
2. Click generate
3. Should see error: "Invalid company name - special characters not allowed"
4. Try company with 500 characters
5. Should be truncated to 100 chars in path

# Automated test
bundle exec rspec spec/services/job_wizard/pdf_output_manager_spec.rb:security
```

**Code Snippet**:
```ruby
# app/services/job_wizard/pdf_output_manager.rb
def slugify(text)
  # Reject path traversal attempts FIRST
  if text =~ /\.\.|\/|\\|\x00/
    raise ArgumentError, "Invalid characters in name (/../ or / not allowed)"
  end
  
  # Slugify and truncate
  text.gsub(/[^a-zA-Z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .strip
      .downcase[0..100]
end

def build_output_path
  # ... existing path logic ...
  
  # CRITICAL: Validate result is within OUTPUT_ROOT
  unless path.to_s.start_with?(JobWizard::OUTPUT_ROOT.to_s)
    raise SecurityError, "Path traversal detected: #{path}"
  end
  
  path
end
```

---

### 🔴 Step 3: Sanitize Filesystem Paths
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P1 - CRITICAL
- **Effort**: S (1-2 hours)
- **Risk**: HIGH - Path traversal, arbitrary file write
- **Depends On**: None
- **Blocks**: None

**Description**:
Fix path traversal vulnerability in `PdfOutputManager#slugify` where user-controlled company/role names are used in filesystem paths.

**Acceptance Criteria**:
- [ ] `slugify` method rejects `..` (parent directory)
- [ ] `slugify` method rejects `/` and `\` (path separators)
- [ ] `slugify` method rejects null bytes
- [ ] `slugify` truncates to 100 characters max
- [ ] `build_output_path` validates result is within `OUTPUT_ROOT`
- [ ] `ArgumentError` raised for invalid characters
- [ ] `SecurityError` raised if path escapes OUTPUT_ROOT
- [ ] Tests verify each rejection case
- [ ] Existing PDFs still accessible after fix
- [ ] Error messages helpful to users

**Files to Modify**:
- `app/services/job_wizard/pdf_output_manager.rb:79-91` - `slugify`
- `app/services/job_wizard/pdf_output_manager.rb:93-107` - `build_output_path`
- `spec/services/job_wizard/pdf_output_manager_spec.rb` - Add security tests

**Testing**:
```bash
# Manual test
1. Paste JD with company "../../etc"
2. Should see error: "Invalid company name (special characters not allowed)"
3. Paste JD with 500-character company name
4. Should be truncated to 100 chars

# Automated test
bundle exec rspec spec/services/job_wizard/pdf_output_manager_spec.rb:security
```

**Code Snippet**:
```ruby
# app/services/job_wizard/pdf_output_manager.rb
def slugify(text)
  # Reject path traversal attempts
  if text =~ /\.\.|\/|\\|\x00/
    raise ArgumentError, "Invalid characters detected (path traversal attempt)"
  end
  
  # Slugify and truncate
  text.gsub(/[^a-zA-Z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .strip
      .downcase[0..100]
end

def build_output_path
  # ... existing logic ...
  
  # Validate result
  unless path.to_s.start_with?(JobWizard::OUTPUT_ROOT.to_s)
    raise SecurityError, "Path traversal detected: #{path}"
  end
  
  path
end
```

---

### 🔴 Step 4: Add CSRF Protection to Session Flow
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P1 - MEDIUM
- **Effort**: S (1 hour)
- **Risk**: MEDIUM - Session hijacking
- **Depends On**: Step 1 (authentication)
- **Blocks**: None

**Description**:
Protect prepare/finalize flow from session tampering by re-validating skill detection in the finalize step.

**Acceptance Criteria**:
- [ ] `finalize` action re-runs `SkillDetector` on JD from session
- [ ] User skill selections validated against fresh detection results
- [ ] Invalid skill selections rejected with error message
- [ ] Session data structure validated (has required keys)
- [ ] Session timeout handled gracefully (redirect with message)
- [ ] Tests verify tampered session data is rejected
- [ ] Tests verify expired session redirects correctly
- [ ] CSRF token present in forms

**Files to Modify**:
- `app/controllers/applications_controller.rb:92-138` - `finalize` action
- `spec/requests/applications_spec.rb` - Add session tampering tests

**Testing**:
```bash
# Manual test
1. Complete prepare step
2. Use browser dev tools to modify session cookie
3. Add fake skill to verified_skills array
4. Submit finalize form
5. Should see error: "Invalid skill selection"

# Automated test
bundle exec rspec spec/requests/applications_spec.rb:session_tampering
```

**Code Snippet**:
```ruby
# app/controllers/applications_controller.rb
def finalize
  prepare_data = session[:application_prepare]
  
  # Validate session structure
  unless prepare_data.is_a?(Hash) && prepare_data[:job_description].present?
    return redirect_to new_application_path, alert: 'Invalid session data'
  end
  
  # Re-detect skills (don't trust session)
  detector = JobWizard::SkillDetector.new(prepare_data[:job_description])
  fresh_analysis = detector.analyze
  
  # Validate user selections
  selected_verified = Array(params[:verified_skills])
  invalid_selections = selected_verified - fresh_analysis[:verified]
  
  if invalid_selections.any?
    return redirect_to new_application_path, 
      alert: "Invalid skill selection: #{invalid_selections.join(', ')}"
  end
  
  # Continue with PDF generation...
end
```

---

### 🔴 Step 5: Validate YAML Configuration
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P1 - MEDIUM
- **Effort**: S (2 hours)
- **Risk**: MEDIUM - YAML injection, code execution
- **Depends On**: None
- **Blocks**: None

**Description**:
Replace unsafe `YAML.load_file` with `YAML.safe_load` and add schema validation on Rails boot.

**Acceptance Criteria**:
- [ ] All `YAML.load_file` replaced with `YAML.safe_load`
- [ ] Permitted classes whitelist defined (Symbol, Date, Time only)
- [ ] Schema validator created for profile.yml and experience.yml
- [ ] Validation runs on `rails server` boot
- [ ] Invalid config prevents app from starting (fail-fast)
- [ ] Helpful error messages for common config errors
- [ ] Tests verify schema validation works
- [ ] Tests verify safe_load rejects malicious YAML
- [ ] Documentation updated with valid config examples

**Files to Modify**:
- `app/services/job_wizard/experience_loader.rb:61-63` - Use safe_load
- `app/services/job_wizard/resume_builder.rb:97-98` - Use safe_load
- `app/validators/job_wizard/config_validator.rb` - New validator
- `config/initializers/job_wizard.rb` - Add boot-time validation
- `spec/validators/job_wizard/config_validator_spec.rb` - New tests

**Testing**:
```bash
# Manual test
1. Add malicious YAML to experience.yml: `!!ruby/object:Gem::Installer`
2. Restart Rails
3. Should see error: "Invalid YAML: Disallowed class Gem::Installer"
4. Fix YAML
5. App boots successfully

# Automated test
bundle exec rspec spec/validators/job_wizard/config_validator_spec.rb
```

**Code Snippet**:
```ruby
# app/services/job_wizard/experience_loader.rb
def load_yaml
  return {} unless File.exist?(@experience_path)
  
  YAML.safe_load(
    File.read(@experience_path),
    permitted_classes: [Symbol, Date, Time],
    permitted_symbols: [],
    aliases: false
  ) || {}
rescue Psych::DisallowedClass => e
  Rails.logger.error "YAML security violation: #{e.message}"
  raise JobWizard::ConfigError, "Invalid YAML configuration: #{e.message}"
end

# config/initializers/job_wizard.rb
Rails.application.config.after_initialize do
  validator = JobWizard::ConfigValidator.new
  validator.validate!  # Raises error if invalid
end
```

---

## Phase 2: Performance & Stability (P2 Quick Wins) - Week 2

### 🟡 Step 6: Add Eager Loading and Indexes
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P2 - HIGH
- **Effort**: S (2 hours)
- **Risk**: LOW - Performance degradation
- **Depends On**: None
- **Blocks**: None

**Description**:
Fix N+1 queries on dashboard and add missing database indexes for frequently queried columns.

**Acceptance Criteria**:
- [ ] `ApplicationsController#new` uses `.includes(:job_posting)`
- [ ] Migration adds `index :applications, :created_at`
- [ ] Migration adds `index :job_postings, :source`
- [ ] Migration adds composite index `[:company, :created_at]`
- [ ] Migration adds partial index `[:remote, :posted_at]` for remote jobs
- [ ] Bullet gem added to detect future N+1 queries
- [ ] Dashboard page load < 100ms (from ~250ms)
- [ ] SQL query log shows 2 queries instead of 7
- [ ] Tests verify eager loading works
- [ ] Production index creation tested (no downtime)

**Files to Modify**:
- `app/controllers/applications_controller.rb:20-24` - Add eager loading
- `db/migrate/YYYYMMDD_add_performance_indexes.rb` - New migration
- `Gemfile` - Add `bullet` gem (development group)
- `config/environments/development.rb` - Configure Bullet

**Testing**:
```bash
# Manual test
1. Seed database with 100 applications, 50 job postings
2. Visit http://localhost:3000
3. Check Rails log - should see 2 queries, not 7
4. Check Bullet notifications - should be clean

# Benchmark
rails runner "
  Benchmark.bm do |x|
    x.report('before') { Application.order(created_at: :desc).limit(6).map(&:job_posting) }
    x.report('after') { Application.includes(:job_posting).order(created_at: :desc).limit(6).to_a }
  end
"

# Automated test
bundle exec rspec spec/performance/dashboard_spec.rb
```

**Migration**:
```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :applications, :created_at, order: { created_at: :desc }
    add_index :job_postings, :source
    add_index :applications, [:company, :created_at]
    add_index :job_postings, [:remote, :posted_at], where: "posted_at IS NOT NULL"
  end
end
```

---

### 🟡 Step 7: Add Critical Test Coverage
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P2 - HIGH
- **Effort**: L (12-16 hours)
- **Risk**: HIGH - Regressions, production bugs
- **Depends On**: None
- **Blocks**: None

**Description**:
Write tests for untested critical paths: Controllers, ResumeBuilder, Fetchers, and integration tests.

**Acceptance Criteria**:
- [ ] `spec/requests/applications_controller_spec.rb` created (100+ lines)
- [ ] Tests cover: `prepare`, `finalize`, `quick_create`, `show`, `download_*`
- [ ] `spec/services/job_wizard/resume_builder_spec.rb` created
- [ ] Tests verify truth-safety: only experience.yml skills in PDFs
- [ ] Tests verify skill level phrasing (expert/intermediate/basic)
- [ ] Tests verify `allowed_skills` filter works
- [ ] `spec/services/job_wizard/fetchers/greenhouse_spec.rb` created
- [ ] `spec/services/job_wizard/fetchers/lever_spec.rb` created
- [ ] Tests cover error handling (429, 500, timeout, malformed JSON)
- [ ] Tests verify HTML entity cleaning works
- [ ] `spec/system/generate_resume_spec.rb` created
- [ ] End-to-end test: paste JD → review skills → download PDF
- [ ] SimpleCov configured, shows coverage report
- [ ] Overall coverage increases from 25% → 60%+
- [ ] CI runs tests on every commit

**Files to Create**:
- `spec/requests/applications_controller_spec.rb` - Request specs
- `spec/services/job_wizard/resume_builder_spec.rb` - Service specs
- `spec/services/job_wizard/fetchers/greenhouse_spec.rb` - Fetcher specs
- `spec/services/job_wizard/fetchers/lever_spec.rb` - Fetcher specs
- `spec/system/generate_resume_spec.rb` - System specs
- `spec/support/pdf_helper.rb` - PDF text extraction helper
- `spec/support/factory_bot.rb` - Test factories
- `.github/workflows/test.yml` - CI configuration

**Testing**:
```bash
# Run all new tests
bundle exec rspec spec/requests/applications_controller_spec.rb
bundle exec rspec spec/services/job_wizard/resume_builder_spec.rb
bundle exec rspec spec/services/job_wizard/fetchers/
bundle exec rspec spec/system/generate_resume_spec.rb

# Check coverage
open coverage/index.html
```

**Priority Tests** (in order):
1. ResumeBuilder truth-safety test (never fabricate)
2. ApplicationsController prepare/finalize flow
3. PdfOutputManager path traversal prevention
4. Fetchers error handling
5. Integration test for happy path

---

### 🟡 Step 8: Add Error Monitoring
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P2 - MEDIUM
- **Effort**: S (1-2 hours)
- **Risk**: MEDIUM - Undetected errors in production
- **Depends On**: None
- **Blocks**: None

**Description**:
Set up error monitoring (Sentry or Rollbar) to catch and alert on production errors.

**Acceptance Criteria**:
- [ ] Sentry gem added and configured
- [ ] DSN configured in Rails credentials (not ENV)
- [ ] Breadcrumbs capture user flow (prepare → finalize)
- [ ] Custom error grouping for PDF generation errors
- [ ] User context attached (user_id, application_id)
- [ ] Test error sent to Sentry successfully
- [ ] Error notifications configured (email/Slack)
- [ ] Performance monitoring enabled (optional)
- [ ] Source maps configured for JavaScript errors
- [ ] PII scrubbing configured (no resume content in logs)

**Files to Modify**:
- `Gemfile` - Add `gem 'sentry-ruby'`, `gem 'sentry-rails'`
- `config/initializers/sentry.rb` - Configure Sentry
- `app/controllers/applications_controller.rb` - Add error context
- `config/credentials.yml.enc` - Add Sentry DSN

**Testing**:
```bash
# Manual test
1. Trigger intentional error: delete profile.yml
2. Try to generate PDF
3. Check Sentry dashboard - should see error logged
4. Verify breadcrumbs show: new → prepare → finalize → error
5. Verify user context present

# Test Sentry integration
rails runner "Sentry.capture_message('Test from JobWizard')"
```

**Configuration**:
```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = Rails.application.credentials.sentry_dsn
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1  # 10% of requests
  
  # Filter PII
  config.before_send = lambda do |event, hint|
    # Remove job_description from context (may contain sensitive info)
    event.extra.delete(:job_description)
    event
  end
  
  # Custom error grouping
  config.before_send = lambda do |event, hint|
    if hint[:exception].is_a?(JobWizard::ConfigError)
      event.fingerprint = ['{{ default }}', 'config-error']
    end
    event
  end
end
```

---

## Phase 3: UX & DevEx (P3 Nice to Haves) - Week 3

### 🟢 Step 9: Add Loading States and Progress Indicators
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P3 - MEDIUM
- **Effort**: M (4-6 hours)
- **Risk**: LOW - User confusion
- **Depends On**: None
- **Blocks**: None

**Description**:
Add visual feedback during PDF generation to prevent user confusion and duplicate submissions.

**Acceptance Criteria**:
- [ ] Loading spinner displays during PDF generation
- [ ] Button changes to "⏳ Generating..." with disabled state
- [ ] Progress steps shown: Input (1/3) → Review (2/3) → Download (3/3)
- [ ] Estimated time remaining shown ("Usually takes 2-5 seconds")
- [ ] Success animation when PDFs ready
- [ ] Auto-scroll to results section after generation
- [ ] Turbo Streams used for real-time updates (no full page reload)
- [ ] Form submission prevented during processing (no double-submit)
- [ ] Tests verify loading states appear and disappear
- [ ] Mobile-friendly loading overlay

**Files to Modify**:
- `app/views/applications/new.html.erb` - Add loading overlay
- `app/views/applications/prepare.html.erb` - Add progress steps
- `app/views/applications/show.html.erb` - Add success animation
- `app/views/shared/_progress_steps.html.erb` - New partial
- `app/javascript/controllers/loading_controller.js` - New Stimulus controller

**Testing**:
```bash
# Manual test
1. Paste JD and click "Generate"
2. Should immediately see spinner overlay
3. Should see "Generating PDFs... (Usually takes 2-5 seconds)"
4. Button should be disabled
5. After 2-3s, should auto-scroll to results
6. Should see success animation

# System test
bundle exec rspec spec/system/loading_states_spec.rb
```

---

### 🟢 Step 10: Create Comprehensive Documentation
- **Status**: ⬜ Not started
- **Owner**: me
- **Priority**: P3 - MEDIUM
- **Effort**: M (4-6 hours)
- **Risk**: LOW - Developer friction
- **Depends On**: None
- **Blocks**: None

**Description**:
Create missing documentation: ENV vars reference, deployment guide, bin/setup script, and enhanced README.

**Acceptance Criteria**:
- [ ] `docs/ENV_VARS.md` created with all 6 environment variables documented
- [ ] `docs/DEPLOYMENT.md` created with Heroku, Fly.io, and VPS instructions
- [ ] `docs/CONFIGURATION.md` created with YAML structure examples
- [ ] `bin/setup` script created and executable
- [ ] `bin/setup` creates example config files from templates
- [ ] `bin/setup` validates configuration before starting
- [ ] README.md updated with features list, how-it-works, FAQ
- [ ] README.md has architecture diagram (ASCII or Mermaid)
- [ ] README.md has screenshots (at least 3)
- [ ] YARD docstrings added to all services (40+ methods)
- [ ] `yard doc` generates clean documentation
- [ ] TROUBLESHOOTING.md created with common errors
- [ ] New developer can set up app in < 10 minutes

**Files to Create/Modify**:
- `docs/ENV_VARS.md` - New
- `docs/DEPLOYMENT.md` - New
- `docs/CONFIGURATION.md` - New
- `docs/TROUBLESHOOTING.md` - New
- `bin/setup` - New
- `README.md` - Update
- `Gemfile` - Add `yard` gem (development group)
- All service files - Add YARD docstrings

**Testing**:
```bash
# Manual test
1. Clone repo to new directory
2. Run ./bin/setup
3. Should complete without errors
4. Should create example config files
5. Should prompt for customization
6. Run bin/dev
7. Should start successfully

# Documentation test
yard doc
open doc/index.html
# Should see clean API documentation
```

**bin/setup Template**:
```bash
#!/usr/bin/env bash
set -e

echo "🧙 JobWizard Setup"
echo "=================="
echo ""

# Check Ruby version
required_ruby="3.3.4"
current_ruby=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ "$current_ruby" != "$required_ruby" ]; then
  echo "⚠️  Ruby $required_ruby required (current: $current_ruby)"
  echo "   Install: rbenv install $required_ruby"
  exit 1
fi

echo "✓ Ruby $required_ruby detected"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
bundle install

# Setup database
echo ""
echo "🗄️  Setting up database..."
bin/rails db:prepare

# Create output directory
echo ""
echo "📁 Creating output directory..."
mkdir -p ~/Documents/JobWizard/Applications

# Check for config files
echo ""
echo "⚙️  Checking configuration..."
for file in profile experience rules; do
  config_file="config/job_wizard/${file}.yml"
  example_file="${config_file}.example"
  
  if [ ! -f "$config_file" ]; then
    if [ -f "$example_file" ]; then
      echo "   Creating $config_file from example..."
      cp "$example_file" "$config_file"
      echo "   ⚠️  Edit $config_file with your information"
    else
      echo "   ❌ $config_file missing (no example found)"
    fi
  else
    echo "   ✓ $config_file exists"
  fi
done

# Run smoke tests
echo ""
echo "🧪 Running smoke tests..."
if bundle exec rspec spec/models spec/services --format progress; then
  echo "   ✓ All tests passed"
else
  echo "   ⚠️  Some tests failed - check configuration"
fi

# Success!
echo ""
echo "============================================"
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit config/job_wizard/profile.yml with your resume info"
echo "  2. Edit config/job_wizard/experience.yml with your work history"
echo "  3. Run 'bin/dev' to start the server"
echo "  4. Visit http://localhost:3000"
echo ""
echo "Optional: Fetch sample jobs"
echo "  rake 'jobs:fetch[greenhouse,instacart]'"
echo ""
echo "📚 Documentation: See README.md and docs/"
echo "============================================"
```

---

## Progress Summary

### Phase 1: Security Lockdown (Week 1)
- [ ] 0/5 tasks complete
- [ ] Estimated: 10-15 hours
- [ ] Status: ⬜ Not started

### Phase 2: Performance & Stability (Week 2)
- [ ] 0/3 tasks complete
- [ ] Estimated: 15-24 hours
- [ ] Status: ⬜ Not started

### Phase 3: UX & DevEx (Week 3)
- [ ] 0/2 tasks complete
- [ ] Estimated: 8-12 hours
- [ ] Status: ⬜ Not started

### **Overall**
- **Total Tasks**: 0/10 complete (0%)
- **Estimated Total**: 40-50 hours
- **Target Completion**: 3 weeks
- **Current Blocker**: None - ready to start Step 1

---

## Weekly Milestones

### Week 1 (Security)
- [ ] Authentication implemented
- [ ] File upload validation
- [ ] Path traversal fixed
- [ ] Session security hardened
- [ ] YAML validation added
- **Goal**: App secured for multi-user deployment

### Week 2 (Performance & Tests)
- [ ] Database optimized (indexes, eager loading)
- [ ] Test coverage > 60%
- [ ] Error monitoring live
- **Goal**: Production-ready stability

### Week 3 (Polish)
- [ ] Loading states polished
- [ ] Documentation complete
- [ ] New developer can onboard in < 10 min
- **Goal**: Excellent developer experience

---

## Acceptance Criteria Template

Each task must meet:
- ✅ Code changes implemented and reviewed
- ✅ Tests written and passing (green)
- ✅ Documentation updated (if needed)
- ✅ Rubocop clean (no new offenses)
- ✅ Manual testing completed (checklist verified)
- ✅ Performance benchmarked (if applicable)
- ✅ Security reviewed (for P1 tasks)
- ✅ Deployed to staging and tested

---

## Risk Management

### High-Risk Tasks
1. **Step 1 (Authentication)**: May break existing features
   - **Mitigation**: Test in separate branch, comprehensive testing
2. **Step 7 (Tests)**: Large effort, may discover bugs
   - **Mitigation**: Write tests incrementally, fix bugs as found
3. **Step 3 (Path Traversal)**: May break existing PDF access
   - **Mitigation**: Test with existing data, provide migration path

### Dependencies
```
Step 1 (Auth) ─┬─> Step 4 (Session Security)
               └─> Step 8 (Error Monitoring - user context)

Step 6 (Indexes) ──> Step 7 (Tests - performance assertions)

All steps ──> Step 10 (Documentation)
```

---

## Notes

- **Checkboxes**: Check off ✅ as you complete each acceptance criterion
- **Blockers**: Update status to ⛔ if blocked, add reason
- **Time Tracking**: Log actual hours spent vs. estimate
- **Reviews**: Each P1 task needs security review before merging

**Last Review**: 2025-10-21 (Initial audit)  
**Next Review**: After Week 1 completion

