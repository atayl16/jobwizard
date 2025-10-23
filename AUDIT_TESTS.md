# Test Coverage Audit - JobWizard

**Date**: 2025-10-21  
**Focus**: Existing tests, missing critical specs, flaky test risks

---

## Current Test Coverage

| Category | Files | Tests | Coverage | Status |
|----------|-------|-------|----------|--------|
| **Models** | 3/3 | ✅ Basic | ~60% | 🟡 PARTIAL |
| **Services** | 4/10 | ⚠️ Partial | ~30% | 🔴 CRITICAL |
| **Controllers** | 0/5 | ❌ None | 0% | 🔴 CRITICAL |
| **Jobs** | 0/1 | ❌ None | 0% | 🟡 MEDIUM |
| **Views** | 0/20 | ❌ None | 0% | 🟢 LOW |
| **Integration** | 0 | ❌ None | 0% | 🔴 CRITICAL |
| **TOTAL** | **7/39** | — | **~25%** | 🔴 CRITICAL |

---

## High-Priority Missing Tests (P2)

| Area | Missing Test | Why Critical | Fix Summary | Effort |
|------|--------------|--------------|-------------|--------|
| **ResumeBuilder** | Truth-safety verification | Core promise: never fabricate skills | Test that only `experience.yml` skills appear in PDFs | M |
| **ApplicationsController** | `prepare` → `finalize` flow | Most complex user path, session handling | Test skill selection, session validation | M |
| **PdfOutputManager** | Path traversal prevention | Security-critical filesystem ops | Test `slugify` rejects `..`, `/`, etc. | S |
| **Fetchers** | API error handling | Silent failures break job board | Test 429, 500, timeout, malformed JSON | M |
| **RulesScanner** | Red-flag detection accuracy | US-only jobs should warn, not block | Test all rules from `rules.yml` | S |
| **SkillDetector** | False positive/negative rates | Over-detection adds fake skills | Test with real job descriptions | M |

---

## Detailed Findings

### 1. No ResumeBuilder Tests (CRITICAL)

**File**: `app/services/job_wizard/resume_builder.rb` (253 lines)  
**Current Tests**: None  
**Lines Tested**: 0%

**Missing Critical Tests**:
```ruby
# spec/services/job_wizard/resume_builder_spec.rb (MISSING)
RSpec.describe JobWizard::ResumeBuilder do
  describe '#build_resume' do
    it 'only includes skills from experience.yml' do
      # Given: JD mentions "Blockchain" (not in experience.yml)
      jd = "Senior Blockchain Developer with Ruby on Rails"
      builder = described_class.new(job_description: jd)
      
      # When: Generate PDF
      pdf_text = PDF::Inspector::Text.analyze(builder.build_resume).strings.join(' ')
      
      # Then: Blockchain NOT in PDF, Rails IS in PDF
      expect(pdf_text).not_to include('Blockchain')
      expect(pdf_text).to include('Ruby on Rails')
    end
    
    it 'respects allowed_skills filter' do
      jd = "Need Rails, React, and Python skills"
      builder = described_class.new(
        job_description: jd,
        allowed_skills: ['Rails', 'React']  # Exclude Python
      )
      
      pdf_text = PDF::Inspector::Text.analyze(builder.build_resume).strings.join(' ')
      
      expect(pdf_text).to include('Rails')
      expect(pdf_text).to include('React')
      expect(pdf_text).not_to include('Python')
    end
    
    it 'phrases skills by level correctly' do
      # Expert: "Deep experience with X"
      # Intermediate: "Working proficiency with X"
      # Basic: "Familiar with X"
      # (Test each level)
    end
    
    it 'never fabricates work history' do
      jd = "5 years at Google required"
      builder = described_class.new(job_description: jd)
      
      pdf_text = PDF::Inspector::Text.analyze(builder.build_resume).strings.join(' ')
      
      # Should only show actual companies from experience.yml
      expect(pdf_text).not_to include('Google')
      expect(pdf_text).to include('Daily Kos')  # Real company
    end
  end
  
  describe '#build_cover_letter' do
    it 'uses TemplatesWriter by default' do
      # Test cover letter generation
    end
    
    it 'includes only verified skills in cover letter' do
      # Similar to resume test
    end
  end
end
```

**Effort**: M (4-6 hours)  
**Risk**: HIGH - Core product promise untested

---

### 2. No Controller Tests (CRITICAL)

**File**: `app/controllers/applications_controller.rb` (263 lines)  
**Current Tests**: None  
**Lines Tested**: 0%

**Missing Critical Tests**:
```ruby
# spec/requests/applications_spec.rb (MISSING)
RSpec.describe 'Applications', type: :request do
  describe 'POST /applications/prepare' do
    it 'stores skill analysis in session' do
      post prepare_applications_path, params: {
        company: 'Instacart',
        role: 'Engineer',
        job_description: 'Rails developer needed'
      }
      
      expect(session[:application_prepare]).to be_present
      expect(session[:application_prepare][:company]).to eq('Instacart')
    end
    
    it 'detects verified vs unverified skills' do
      jd = 'Need Rails (verified) and Blockchain (unverified)'
      post prepare_applications_path, params: { job_description: jd }
      
      prepare_data = session[:application_prepare]
      expect(prepare_data[:verified_skills]).to include('Rails')
      expect(prepare_data[:unverified_skills]).to include('Blockchain')
    end
  end
  
  describe 'POST /applications/finalize' do
    before do
      # Set up session from prepare step
      session[:application_prepare] = {
        company: 'Test Co',
        role: 'Engineer',
        job_description: 'Rails and React',
        verified_skills: ['Rails', 'React'],
        unverified_skills: []
      }
    end
    
    it 'creates application with selected skills' do
      expect {
        post finalize_applications_path, params: {
          verified_skills: ['Rails']  # User unchecks React
        }
      }.to change(Application, :count).by(1)
      
      app = Application.last
      # Verify only Rails in PDF, not React
    end
    
    it 'rejects if session expired' do
      session[:application_prepare] = nil
      
      post finalize_applications_path
      expect(response).to redirect_to(new_application_path)
      expect(flash[:alert]).to match(/session expired/i)
    end
    
    it 'generates PDFs synchronously' do
      expect(JobWizard::ResumeBuilder).to receive(:new).and_call_original
      expect(JobWizard::PdfOutputManager).to receive(:new).and_call_original
      
      post finalize_applications_path, params: { verified_skills: ['Rails'] }
    end
  end
  
  describe 'GET /applications/:id/resume' do
    let(:application) { create(:application) }
    
    it 'sends PDF with descriptive filename' do
      get resume_application_path(application)
      
      expect(response.headers['Content-Disposition']).to match(/Resume_.*\.pdf/)
    end
    
    # TODO: Add authorization test when auth is implemented
    # it 'returns 403 if not current user's application'
  end
end
```

**Effort**: L (8-12 hours)  
**Risk**: HIGH - No coverage of main user flow

---

### 3. No PdfOutputManager Security Tests (HIGH)

**File**: `spec/services/job_wizard/pdf_output_manager_spec.rb` (exists)  
**Current Tests**: Basic path creation  
**Missing Tests**: Security validation

**Add to Existing Spec**:
```ruby
# spec/services/job_wizard/pdf_output_manager_spec.rb
RSpec.describe JobWizard::PdfOutputManager do
  describe '#slugify' do
    it 'rejects path traversal attempts' do
      expect {
        described_class.new(company: '../../etc', role: 'passwd')
      }.to raise_error(ArgumentError, /Invalid characters/)
    end
    
    it 'rejects absolute paths' do
      expect {
        described_class.new(company: '/etc/passwd', role: 'evil')
      }.to raise_error(ArgumentError)
    end
    
    it 'truncates long names to prevent filesystem limits' do
      long_name = 'A' * 500
      manager = described_class.new(company: long_name, role: 'Engineer')
      
      expect(manager.instance_variable_get(:@company_slug).length).to be <= 100
    end
  end
  
  describe '#build_output_path' do
    it 'validates result is within OUTPUT_ROOT' do
      # Mock OUTPUT_ROOT for test
      allow(JobWizard::OUTPUT_ROOT).to receive(:to_s).and_return('/safe/path')
      
      manager = described_class.new(company: 'Test', role: 'Engineer')
      
      # Path should start with OUTPUT_ROOT
      expect(manager.output_path.to_s).to start_with('/safe/path')
    end
  end
  
  describe '#update_latest_symlink!' do
    it 'validates symlink target is within OUTPUT_ROOT' do
      # Test symlink security
    end
  end
end
```

**Effort**: S (2-3 hours)  
**Risk**: HIGH - Path traversal vulnerability untested

---

### 4. No Fetcher Error Handling Tests (MEDIUM)

**Files**:
- `app/services/job_wizard/fetchers/greenhouse.rb` (untested)
- `app/services/job_wizard/fetchers/lever.rb` (untested)

**Missing Tests**:
```ruby
# spec/services/job_wizard/fetchers/greenhouse_spec.rb (MISSING)
RSpec.describe JobWizard::Fetchers::Greenhouse do
  describe '#fetch' do
    it 'handles 429 rate limit' do
      stub_request(:get, /greenhouse/).to_return(status: 429)
      
      result = described_class.new.fetch('airbnb')
      expect(result).to eq([])
      # Should log error, not crash
    end
    
    it 'handles 500 server error' do
      stub_request(:get, /greenhouse/).to_return(status: 500)
      
      expect {
        described_class.new.fetch('airbnb')
      }.not_to raise_error
    end
    
    it 'handles timeout' do
      stub_request(:get, /greenhouse/).to_timeout
      
      result = described_class.new.fetch('airbnb')
      expect(result).to eq([])
    end
    
    it 'handles malformed JSON' do
      stub_request(:get, /greenhouse/).to_return(body: 'not json')
      
      expect {
        described_class.new.fetch('airbnb')
      }.not_to raise_error
    end
    
    it 'cleans HTML entities from descriptions' do
      stub_request(:get, /greenhouse/).to_return(
        body: { jobs: [{ content: '&lt;p&gt;Test&lt;/p&gt;' }] }.to_json
      )
      
      result = described_class.new.fetch('test')
      expect(result.first[:description]).not_to include('&lt;')
      expect(result.first[:description]).to include('Test')
    end
  end
end
```

**Effort**: M (4-6 hours per fetcher)  
**Risk**: MEDIUM - Job board breaks silently

---

### 5. Insufficient RulesScanner Tests (MEDIUM)

**File**: `spec/services/job_wizard/rules_scanner_spec.rb` (exists)  
**Current Tests**: Basic skill detection  
**Missing Tests**: All rules from `rules.yml`

**Add to Existing Spec**:
```ruby
# spec/services/job_wizard/rules_scanner_spec.rb
RSpec.describe JobWizard::RulesScanner do
  describe 'red flags' do
    it 'warns on US-only for remote role' do
      jd = 'Remote position. US citizens only.'
      result = scanner.scan(jd)
      
      # Should warn (not block) per requirements
      expect(result[:warnings]).to include(
        hash_including(message: /US.*only/)
      )
      expect(result[:blocking]).to be_empty
    end
    
    it 'blocks unpaid positions' do
      jd = 'Unpaid internship opportunity'
      result = scanner.scan(jd)
      
      expect(result[:blocking]).to include(
        hash_including(message: /unpaid/i)
      )
    end
    
    it 'flags vague compensation' do
      jd = 'Competitive salary'
      result = scanner.scan(jd)
      
      expect(result[:info]).to include(
        hash_including(message: /compensation not specified/i)
      )
    end
  end
  
  describe 'skill detection' do
    it 'detects compound skills correctly' do
      jd = 'Need Ruby on Rails experience'
      result = scanner.scan(jd)
      
      # Should detect "Ruby on Rails", not just "Ruby"
      unverified = result[:unverified_skills].map { |s| s[:skill] }
      expect(unverified).to include('Ruby on Rails')
    end
    
    it 'handles case-insensitive matching' do
      jd = 'POSTGRESQL and postgresql'
      # Should dedupe
    end
  end
end
```

**Effort**: S (2-3 hours)  
**Risk**: MEDIUM - Rules not enforced correctly

---

## Test Infrastructure Gaps

### Missing Test Helpers
```ruby
# spec/support/pdf_helper.rb (MISSING)
module PdfHelper
  def extract_text_from_pdf(pdf_string)
    PDF::Inspector::Text.analyze(pdf_string).strings.join(' ')
  end
  
  def pdf_includes_skill?(pdf_string, skill)
    extract_text_from_pdf(pdf_string).include?(skill)
  end
end

# spec/support/factory_bot.rb (MISSING)
FactoryBot.define do
  factory :application do
    company { 'Test Company' }
    role { 'Software Engineer' }
    job_description { 'Rails developer needed' }
    status { :draft }
  end
  
  factory :job_posting do
    company { 'Instacart' }
    title { 'Backend Engineer' }
    description { 'Ruby on Rails experience required' }
    url { "https://example.com/jobs/#{SecureRandom.uuid}" }
    remote { true }
  end
end

# spec/support/vcr.rb (MISSING - for HTTP mocking)
VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.filter_sensitive_data('<GREENHOUSE_API>') { ENV['GREENHOUSE_API_KEY'] }
end
```

### Missing Test Data
```yaml
# spec/fixtures/config/experience.yml (MISSING)
skills:
  - name: Ruby on Rails
    level: expert
  - name: React
    level: intermediate

# spec/fixtures/config/profile.yml (MISSING)
name: Test User
email: test@example.com
phone: '555-1234'
summary: Test summary
```

---

## Integration Test Scenarios (P3)

### End-to-End Flows (MISSING)
```ruby
# spec/system/generate_resume_spec.rb (MISSING)
RSpec.describe 'Generate Resume Flow', type: :system do
  it 'completes full prepare → finalize flow' do
    visit new_application_path
    
    # Step 1: Input
    fill_in 'Job Description', with: 'Rails developer at Instacart'
    click_button 'Review Skills & Generate'
    
    # Step 2: Review skills
    expect(page).to have_content('Verified Skills')
    check 'Rails'
    uncheck 'Blockchain'  # Not in experience.yml
    click_button 'Generate Documents'
    
    # Step 3: Download
    expect(page).to have_content('Application documents generated')
    expect(page).to have_link('Download Resume')
    
    # Verify PDF contents
    click_link 'Download Resume'
    # Parse PDF, verify skills
  end
  
  it 'shows error for invalid input' do
    visit new_application_path
    click_button 'Review Skills & Generate'
    
    expect(page).to have_content('Please provide a job description')
  end
end
```

**Effort**: L (12-16 hours)  
**Risk**: MEDIUM - Regressions in user flow

---

## Flaky Test Risks

### Identified Risks
1. **Time-dependent tests**: `PdfOutputManager` uses `Time.current` for timestamps
   - **Fix**: Use `travel_to` or freeze time in tests
   
2. **Filesystem tests**: Tests create real directories
   - **Fix**: Use `tmp/test` directory, clean up in `after` block
   
3. **HTTP tests**: Fetchers make real API calls in tests
   - **Fix**: Use VCR or WebMock stubs
   
4. **Random ordering**: No seed control
   - **Fix**: Add `config.order = :random` with seed output

### Recommended RSpec Config
```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  # Random order with seed
  config.order = :random
  Kernel.srand config.seed
  
  # Clean up test files
  config.after(:each) do
    FileUtils.rm_rf(Rails.root.join('tmp/test'))
  end
  
  # Freeze time for consistency
  config.include ActiveSupport::Testing::TimeHelpers
  
  # Database cleaner
  config.use_transactional_fixtures = true
end
```

---

## Coverage Targets

| Category | Current | Target | Priority |
|----------|---------|--------|----------|
| Models | 60% | 90% | P3 |
| Services | 30% | 85% | P2 |
| Controllers | 0% | 75% | P1 |
| Integration | 0% | 60% | P2 |
| **OVERALL** | **25%** | **80%** | — |

---

## Test Automation

### Missing CI Setup
```yaml
# .github/workflows/test.yml (MISSING)
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3.4
          bundler-cache: true
      - name: Run RuboCop
        run: bundle exec rubocop
      - name: Run RSpec
        run: bundle exec rspec
      - name: Check Coverage
        run: bundle exec rspec --format RspecJunitFormatter --out test-results.xml
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
```

### Pre-commit Hooks (MISSING)
```bash
# .git/hooks/pre-commit (or use Overcommit gem)
#!/bin/bash
bundle exec rubocop --parallel
bundle exec rspec spec/models spec/services
```

---

## Next Steps

1. **Immediate** (today):
   - Add ResumeBuilder truth-safety test
   - Add PdfOutputManager path traversal test
   - Set up SimpleCov for coverage tracking

2. **This Week**:
   - Add ApplicationsController request specs
   - Add Fetcher error handling tests
   - Set up CI with GitHub Actions

3. **This Month**:
   - Reach 60%+ overall coverage
   - Add integration tests for main flows
   - Set up continuous coverage monitoring

---

**Test Priority**: Focus on P1/P2 tests first - they cover security and core functionality.

**Recommended Tools**:
- `simplecov` - Coverage reporting
- `factory_bot` - Test data
- `vcr` / `webmock` - HTTP mocking
- `pdf-inspector` - PDF content assertions
- `capybara` - System tests



