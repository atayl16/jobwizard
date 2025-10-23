# Security Audit - JobWizard

**Date**: 2025-10-21  
**Focus**: Secrets, file operations, input validation, PDF generation, API keys

---

## Critical Vulnerabilities (P1)

| Area | Issue | Why It Matters | Fix Summary | Effort | Risk |
|------|-------|----------------|-------------|--------|------|
| **Authentication** | No user authentication | Anyone can access app, generate PDFs with your personal resume data | Add Devise/Rails Auth with user isolation | M | 🔴 CRITICAL |
| **File Upload** | No validation on uploaded JD files (`applications_controller.rb:216-231`) | DoS via large files, malicious content execution | Add size limit (5MB), type check (.txt/.pdf), virus scan | S | 🔴 HIGH |
| **Path Traversal** | User-controlled company/role in filesystem paths (`pdf_output_manager.rb:79-91`) | `../../../etc/passwd` in company name can write anywhere | Strict regex `[a-zA-Z0-9\s-]`, reject path chars | S | 🔴 HIGH |
| **Session Tampering** | Untrusted data in session (`applications_controller.rb:73-89`) | Attacker can inject skills/JD via session manipulation | Sign session data, add CSRF tokens, validate structure | S | 🟡 MEDIUM |
| **YAML Injection** | No validation on config YAML load (`experience_loader.rb:61-63`) | If config files are user-editable, code injection possible | Use `YAML.safe_load`, validate schema on boot | S | 🟡 MEDIUM |

---

## High-Priority Issues (P2)

| Area | Issue | Why It Matters | Fix Summary | Effort | Risk |
|------|-------|----------------|-------------|--------|------|
| **API Keys** | No secret scanning in git history | If `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` leaked, unauthorized usage | Add `.gitignore` check, run `git-secrets` scan | S | 🟡 MEDIUM |
| **send_file** | No authorization check (`applications_controller.rb:207-230`) | Anyone with ID can download any user's PDFs | Add current_user ownership check | S | 🟡 MEDIUM |

---

## Medium-Priority Issues (P3)

| Area | Issue | Why It Matters | Fix Summary | Effort | Risk |
|------|-------|----------------|-------------|--------|------|
| **HTTP Headers** | Missing security headers (CSP, X-Frame-Options) | XSS, clickjacking risks | Add `secure_headers` gem, configure CSP | S | 🟢 LOW |
| **Symlink Security** | No validation of symlink targets (`pdf_output_manager.rb:113-120`) | Symlink pointing outside allowed directory | Validate target is within OUTPUT_ROOT | S | 🟢 LOW |
| **Regex DoS** | Complex regex in skill extraction (`rules_scanner.rb:74-100`) | Malicious JD can cause ReDoS | Audit regex, add timeout, use simpler patterns | M | 🟢 LOW |

---

## Detailed Findings

### 1. No Authentication (CRITICAL)

**File**: Entire application  
**Line**: N/A (missing `ApplicationController` authentication)

**Problem**:
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # No before_action :authenticate_user!
  # No current_user method
end
```

**Impact**:
- Anyone who knows the URL can access the app
- Personal resume data (name, email, work history) exposed
- No user isolation - all PDFs visible to everyone

**Recommendation**:
```ruby
# Add to Gemfile
gem 'devise'

# Add to ApplicationController
before_action :authenticate_user!

# Scope queries
@applications = current_user.applications.order(created_at: :desc)
```

**Alternatives**: Rails 8 built-in auth, Clearance, custom session-based auth

---

### 2. File Upload Validation (HIGH)

**File**: `app/controllers/applications_controller.rb`  
**Lines**: 216-231 (`extract_job_description`)

**Problem**:
```ruby
def extract_job_description
  if params[:application][:job_description_file].present?
    file = params[:application][:job_description_file]
    file.read  # ❌ No size check, type check, or virus scan
  end
end
```

**Attack Vector**:
- Upload 1GB file → DoS via memory exhaustion
- Upload malicious executable → stored on server
- Upload with embedded scripts → XSS if rendered

**Recommendation**:
```ruby
MAX_FILE_SIZE = 5.megabytes
ALLOWED_TYPES = %w[text/plain application/pdf]

def extract_job_description
  if params[:application][:job_description_file].present?
    file = params[:application][:job_description_file]
    
    # Size check
    return render json: { error: "File too large" }, status: :unprocessable_entity if file.size > MAX_FILE_SIZE
    
    # Type check
    unless ALLOWED_TYPES.include?(file.content_type)
      return render json: { error: "Invalid file type" }, status: :unprocessable_entity
    end
    
    # Read with limit
    file.read(MAX_FILE_SIZE)
  end
end
```

**Additional**: Consider ClamAV integration for virus scanning

---

### 3. Path Traversal (HIGH)

**File**: `app/services/job_wizard/pdf_output_manager.rb`  
**Lines**: 79-91 (`slugify`, `build_output_path`)

**Problem**:
```ruby
def slugify(text)
  text.gsub(/[^a-zA-Z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .strip
      .downcase
  # ❌ Allows ../../../ if user sets company to "../../etc/passwd"
end
```

**Attack Vector**:
```ruby
# Malicious input
company = "../../../../../../tmp/evil"
role = "../../../../../../../etc/cron.d/backdoor"

# Results in path like:
# ~/Documents/JobWizard/Applications/../../tmp/evil/.../etc/cron.d/backdoor/
```

**Recommendation**:
```ruby
def slugify(text)
  # Reject path traversal characters FIRST
  raise ArgumentError, "Invalid characters" if text =~ /\.\.|\/|\\/
  
  # Then slugify
  text.gsub(/[^a-zA-Z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .strip
      .downcase[0..100] # Also add length limit
end

# Add validation in build_output_path
def build_output_path
  path = case @path_style
  when 'simple'
    JobWizard::OUTPUT_ROOT.join(folder_name)
  else
    JobWizard::OUTPUT_ROOT.join('Applications', @company_slug, @role_slug, @date_slug)
  end
  
  # CRITICAL: Validate result is within OUTPUT_ROOT
  unless path.to_s.start_with?(JobWizard::OUTPUT_ROOT.to_s)
    raise SecurityError, "Path traversal detected"
  end
  
  path
end
```

---

### 4. Session Data Tampering (MEDIUM)

**File**: `app/controllers/applications_controller.rb`  
**Lines**: 64-89 (`prepare`), 92-138 (`finalize`)

**Problem**:
```ruby
# prepare action stores untrusted data
session[:application_prepare] = {
  company: company,  # ❌ User-controlled
  role: role,        # ❌ User-controlled
  job_description: job_description,  # ❌ User-controlled
  verified_skills: skill_analysis[:verified],  # ❌ Can be manipulated
  unverified_skills: skill_analysis[:unverified]
}

# finalize action trusts this data
prepare_data = session[:application_prepare]
# Uses prepare_data without re-validation
```

**Attack Vector**:
- Attacker modifies session cookie
- Injects fabricated skills into `verified_skills`
- PDF generated with false claims

**Recommendation**:
```ruby
# Option 1: Re-run skill detection in finalize
def finalize
  prepare_data = session[:application_prepare]
  
  # Re-detect skills (don't trust session)
  detector = JobWizard::SkillDetector.new(prepare_data[:job_description])
  fresh_analysis = detector.analyze
  
  # Validate user selections match fresh analysis
  unless (selected_verified - fresh_analysis[:verified]).empty?
    return redirect_to new_application_path, alert: "Invalid skill selection"
  end
end

# Option 2: Sign session data
config.action_dispatch.cookies_serializer = :json
config.action_dispatch.signed_cookie_salt = ENV['SECRET_KEY_BASE']
```

---

### 5. YAML Injection (MEDIUM)

**File**: `app/services/job_wizard/experience_loader.rb`  
**Lines**: 61-63 (`load_yaml`)

**Problem**:
```ruby
def load_yaml
  return {} unless File.exist?(@experience_path)
  YAML.load_file(@experience_path) || {}  # ❌ Unsafe YAML load
end
```

**Attack Vector (if config files are user-editable)**:
```yaml
# Malicious experience.yml
skills: !ruby/object:Gem::Installer
  i: x
```

**Recommendation**:
```ruby
def load_yaml
  return {} unless File.exist?(@experience_path)
  
  # Use safe_load with permitted classes
  YAML.safe_load(
    File.read(@experience_path),
    permitted_classes: [Symbol, Date, Time],
    permitted_symbols: [],
    aliases: false
  ) || {}
rescue Psych::DisallowedClass => e
  Rails.logger.error "YAML security violation: #{e.message}"
  {}
end

# Add validation on boot
Rails.application.config.after_initialize do
  validator = JobWizard::ConfigValidator.new
  validator.validate_experience_yml!
  validator.validate_profile_yml!
end
```

---

## Security Checklist

- [ ] Add authentication (Devise/Rails Auth)
- [ ] Validate file uploads (size, type, virus scan)
- [ ] Sanitize filesystem paths (reject `..`, `/`, `\`)
- [ ] Sign session data or re-validate in finalize
- [ ] Use `YAML.safe_load` with schema validation
- [ ] Add `secure_headers` gem for HTTP security
- [ ] Run `git-secrets` scan for leaked API keys
- [ ] Add authorization checks to `send_file`
- [ ] Validate symlink targets within OUTPUT_ROOT
- [ ] Audit regex patterns for ReDoS
- [ ] Add rate limiting on file upload endpoints
- [ ] Set up CSP headers to prevent XSS

---

## Environment Variables to Secure

| Variable | Current State | Recommendation |
|----------|---------------|----------------|
| `JOB_WIZARD_OUTPUT_ROOT` | Documented | ✅ Good |
| `JOB_WIZARD_PATH_STYLE` | Documented | ✅ Good |
| `AI_WRITER` | Documented | ✅ Good |
| `ANTHROPIC_API_KEY` | No validation | ⚠️ Add `.env` to `.gitignore`, use Rails credentials |
| `OPENAI_API_KEY` | No validation | ⚠️ Add `.env` to `.gitignore`, use Rails credentials |
| `SECRET_KEY_BASE` | Rails default | ⚠️ Rotate, use 128-bit key |

**Recommendation**: Move API keys to Rails 8 encrypted credentials:
```bash
rails credentials:edit --environment production
# Add:
# anthropic_api_key: xxx
# openai_api_key: yyy
```

---

## Penetration Test Scenarios

### Scenario 1: Path Traversal
```ruby
# POST /applications/prepare
params = {
  company: "../../../../tmp",
  role: "evil",
  job_description: "Test"
}
# Expected: Rejected with "Invalid characters"
# Actual: Creates ~/Documents/JobWizard/../../../../tmp/evil/
```

### Scenario 2: File Upload DoS
```ruby
# POST /applications/create
params = {
  application: {
    job_description_file: File.open("/dev/zero", "r")  # Infinite file
  }
}
# Expected: Rejected with "File too large"
# Actual: Memory exhaustion, app crash
```

### Scenario 3: Session Tampering
```ruby
# Step 1: POST /applications/prepare (legitimate)
# Step 2: Modify session cookie to add fake skills
# Step 3: POST /applications/finalize
# Expected: Skills re-validated, fake skills rejected
# Actual: PDF generated with fabricated skills
```

---

## Next Steps

1. **Immediate** (today):
   - Add `.gitignore` entry for `.env`
   - Run `git log -p | grep -i "api_key"` to check for leaks
   - Add file size limit to uploads

2. **This Week**:
   - Implement authentication (Devise)
   - Fix path traversal in `slugify`
   - Add session validation in `finalize`

3. **This Month**:
   - Full penetration test with OWASP ZAP
   - Add security headers
   - Set up automated security scanning in CI

---

**Severity Legend**:
- 🔴 CRITICAL - Immediate data breach or RCE risk
- 🟡 MEDIUM - Significant but requires specific conditions
- 🟢 LOW - Defense-in-depth, minimal immediate risk



