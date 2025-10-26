# Documentation Audit - JobWizard

**Date**: 2025-10-21  
**Focus**: Environment variables, setup process, deployment guide, developer onboarding

---

## Critical Gaps (P2)

| Area | Missing Documentation | Why It Matters | Fix Summary | Effort |
|------|----------------------|----------------|-------------|--------|
| **ENV Variables** | No complete ENV reference | Developers don't know what to configure | Create `docs/ENV_VARS.md` | S |
| **Setup Process** | No `bin/setup` or equivalent | New devs spend hours figuring out setup | Create `bin/setup` script | M |
| **Deployment** | No deployment guide | Can't deploy to production safely | Create `docs/DEPLOYMENT.md` | M |
| **API Keys** | No instructions for AI writers | Users don't know how to enable AI features | Document in `README.md` | S |
| **Configuration** | YAML file structure undocumented | Users don't know how to format `experience.yml` | Inline comments insufficient | M |

---

## Detailed Findings

### 1. Environment Variables (HIGH)

**Current State**: Scattered in code, no central reference

**Missing Documentation**:
```markdown
# docs/ENV_VARS.md (MISSING)

# Environment Variables - JobWizard

## Required Variables

None! App works out-of-the-box with defaults.

## Optional Variables

### File Output Configuration

#### JOB_WIZARD_OUTPUT_ROOT
- **Description**: Root directory where PDFs and application folders are created
- **Default**: `~/Documents/JobWizard`
- **Example**: `JOB_WIZARD_OUTPUT_ROOT=/Users/yourname/Dropbox/JobApplications`
- **Used in**: `config/initializers/job_wizard.rb:7-9`
- **Notes**: 
  - Directory will be created if it doesn't exist
  - Must be writable by Rails process
  - Use absolute paths to avoid confusion

#### JOB_WIZARD_PATH_STYLE
- **Description**: Folder structure style for generated PDFs
- **Options**: 
  - `simple` → `Company - Role - YYYY-MM-DD/`
  - `nested` → `Applications/Company/Role/YYYY-MM-DD/` (default)
- **Default**: `nested`
- **Example**: `JOB_WIZARD_PATH_STYLE=simple`
- **Used in**: `app/services/job_wizard/pdf_output_manager.rb:19-20`

### AI Cover Letter Configuration

#### AI_WRITER
- **Description**: Which AI service to use for cover letter generation
- **Options**: `anthropic`, `openai`, (empty = templates)
- **Default**: (empty - uses TemplatesWriter)
- **Example**: `AI_WRITER=anthropic`
- **Used in**: `app/services/job_wizard/writer_factory.rb:11-24`
- **Notes**: Requires corresponding API key

#### ANTHROPIC_API_KEY
- **Description**: API key for Claude (Anthropic)
- **Required**: Only if `AI_WRITER=anthropic`
- **Example**: `ANTHROPIC_API_KEY=sk-ant-...`
- **Get Key**: https://console.anthropic.com/
- **Used in**: `app/services/job_wizard/writers/anthropic_writer.rb` (when implemented)
- **Security**: ⚠️ NEVER commit this to git

#### OPENAI_API_KEY
- **Description**: API key for GPT (OpenAI)
- **Required**: Only if `AI_WRITER=openai`
- **Example**: `OPENAI_API_KEY=sk-...`
- **Get Key**: https://platform.openai.com/api-keys
- **Used in**: `app/services/job_wizard/writers/openai_writer.rb` (when implemented)
- **Security**: ⚠️ NEVER commit this to git

### Database Configuration

#### DATABASE_URL
- **Description**: PostgreSQL connection string (production)
- **Example**: `DATABASE_URL=postgres://user:pass@localhost/jobwizard_production`
- **Default**: SQLite3 in development
- **Notes**: Not needed in development

### Secret Management

#### SECRET_KEY_BASE
- **Description**: Rails session encryption key
- **Required**: YES (in production)
- **Generate**: `rails secret`
- **Example**: `SECRET_KEY_BASE=abc123...`
- **Security**: ⚠️ Rotate regularly, use Rails credentials in production

## Development .env Template

```bash
# Copy this to .env (ignored by git)

# Optional: Change output directory
# JOB_WIZARD_OUTPUT_ROOT=/Users/yourname/Documents/JobWizard

# Optional: Use simple path structure
# JOB_WIZARD_PATH_STYLE=simple

# Optional: Enable AI cover letters
# AI_WRITER=anthropic
# ANTHROPIC_API_KEY=sk-ant-your-key-here
```

## Production Checklist

- [ ] Set `SECRET_KEY_BASE` (use Rails credentials)
- [ ] Set `DATABASE_URL` (if using PostgreSQL)
- [ ] Set `JOB_WIZARD_OUTPUT_ROOT` to writable directory
- [ ] Configure `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` (if using AI)
- [ ] Verify `Rails.env.production?` works correctly
- [ ] Test file permissions on output directory

## Troubleshooting

### "Permission denied" when generating PDFs
- **Cause**: Rails process can't write to `JOB_WIZARD_OUTPUT_ROOT`
- **Fix**: `chmod 755 ~/Documents/JobWizard` or change output root

### "API key missing" warning
- **Cause**: `AI_WRITER=anthropic` but no `ANTHROPIC_API_KEY`
- **Fix**: Set API key or remove `AI_WRITER` to use templates

### "Session expired" on finalize step
- **Cause**: `SECRET_KEY_BASE` changed or session timeout
- **Fix**: Keep `SECRET_KEY_BASE` consistent, increase session timeout
```

**Effort**: S (2-3 hours)  
**Impact**: HIGH - Reduces setup confusion

---

### 2. Developer Setup (HIGH)

**Current State**: Manual setup required

**Missing `bin/setup`**:
```bash
#!/usr/bin/env bash
# bin/setup (MISSING)
set -e

echo "== Installing dependencies =="
bundle install

echo "== Preparing database =="
bin/rails db:prepare

echo "== Creating output directory =="
mkdir -p ~/Documents/JobWizard/{Applications,Latest}

echo "== Checking configuration files =="
if [ ! -f config/job_wizard/profile.yml ]; then
  echo "⚠️  config/job_wizard/profile.yml not found"
  echo "   Copy config/job_wizard/profile.yml.example and fill in your details"
  cp config/job_wizard/profile.yml.example config/job_wizard/profile.yml
fi

if [ ! -f config/job_wizard/experience.yml ]; then
  echo "⚠️  config/job_wizard/experience.yml not found"
  echo "   Copy config/job_wizard/experience.yml.example and fill in your work history"
  cp config/job_wizard/experience.yml.example config/job_wizard/experience.yml
fi

echo "== Running tests to verify setup =="
bundle exec rspec spec/models spec/services || echo "⚠️  Some tests failed - check configuration"

echo ""
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
```

**Add to README**:
```markdown
## Quick Start

### First-Time Setup (5 minutes)

```bash
# Clone the repo
git clone https://github.com/yourname/JobWizard.git
cd JobWizard

# Run automated setup
./bin/setup

# Configure your resume data
# Edit these files with your information:
config/job_wizard/profile.yml     # Name, contact, summary
config/job_wizard/experience.yml  # Work history, skills

# Start the server
bin/dev
```

Visit http://localhost:3000 and generate your first resume!
```

**Effort**: M (4 hours)  
**Impact**: HIGH - 90% faster onboarding

---

### 3. Deployment Guide (HIGH)

**Current State**: No deployment docs

**Missing Documentation**:
```markdown
# docs/DEPLOYMENT.md (MISSING)

# Deployment Guide - JobWizard

## Prerequisites

- Ruby 3.3.4+
- Rails 8.0+
- PostgreSQL 14+ (or SQLite3 for simple deployments)
- Writable filesystem for PDF output

## Option 1: Deploy to Heroku (Recommended for MVP)

### 1. Install Heroku CLI
```bash
brew install heroku/brew/heroku
```

### 2. Create Heroku App
```bash
heroku create your-app-name
heroku addons:create heroku-postgresql:mini
```

### 3. Configure Environment
```bash
# Set output directory (Heroku ephemeral filesystem)
heroku config:set JOB_WIZARD_OUTPUT_ROOT=/app/tmp/job_wizard_output

# Set path style
heroku config:set JOB_WIZARD_PATH_STYLE=simple

# Optional: AI writer
heroku config:set AI_WRITER=anthropic
heroku config:set ANTHROPIC_API_KEY=sk-ant-...
```

### 4. Deploy
```bash
git push heroku main
heroku run rails db:migrate
heroku open
```

### 5. Limitations on Heroku
⚠️ **Important**: Heroku uses ephemeral filesystem
- PDFs will be deleted on dyno restart (24h)
- Solution: Add AWS S3 for persistent storage
- See "S3 Integration" section below

## Option 2: Deploy to Fly.io (Better for file persistence)

### 1. Install Fly CLI
```bash
curl -L https://fly.io/install.sh | sh
```

### 2. Launch App
```bash
fly launch
# Select region, configure database
```

### 3. Add Persistent Volume
```bash
fly volumes create job_wizard_data --size 10 --region ord
```

### 4. Configure fly.toml
```toml
[mounts]
  source = "job_wizard_data"
  destination = "/data"

[env]
  JOB_WIZARD_OUTPUT_ROOT = "/data/job_wizard"
  JOB_WIZARD_PATH_STYLE = "simple"
```

### 5. Deploy
```bash
fly deploy
```

## Option 3: VPS (DigitalOcean, Linode, etc.)

### 1. Provision Server
- Ubuntu 22.04 LTS
- 2GB RAM minimum
- 20GB SSD

### 2. Install Dependencies
```bash
# Ruby via rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/main/bin/rbenv-installer | bash
rbenv install 3.3.4

# PostgreSQL
sudo apt install postgresql postgresql-contrib

# Nginx
sudo apt install nginx
```

### 3. Configure App
```bash
# Clone repo
git clone https://github.com/yourname/JobWizard.git /var/www/jobwizard
cd /var/www/jobwizard

# Install gems
bundle install --deployment --without development test

# Set up environment
cp .env.production.example .env.production
# Edit .env.production with your values

# Set up database
RAILS_ENV=production rails db:create db:migrate

# Precompile assets
RAILS_ENV=production rails assets:precompile

# Create output directory
mkdir -p /var/www/jobwizard/storage/applications
chmod 755 /var/www/jobwizard/storage
```

### 4. Configure Systemd Service
```ini
# /etc/systemd/system/jobwizard.service
[Unit]
Description=JobWizard Rails App
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/jobwizard
Environment=RAILS_ENV=production
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

### 5. Configure Nginx
```nginx
# /etc/nginx/sites-available/jobwizard
upstream jobwizard {
  server unix:///var/www/jobwizard/tmp/sockets/puma.sock;
}

server {
  listen 80;
  server_name yourdomain.com;
  root /var/www/jobwizard/public;

  location / {
    proxy_pass http://jobwizard;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  location ~ ^/(assets|packs)/ {
    gzip_static on;
    expires 1y;
    add_header Cache-Control public;
  }
}
```

## S3 Integration for Persistent PDFs

### 1. Add Gems
```ruby
# Gemfile
gem 'aws-sdk-s3'
gem 'active_storage_validations'
```

### 2. Configure Active Storage
```yaml
# config/storage.yml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: us-east-1
  bucket: your-bucket-name
```

### 3. Modify PdfOutputManager
```ruby
# Option: Upload to S3 after generating locally
def write_resume(pdf_content)
  local_path = output_path.join('resume.pdf')
  File.write(local_path, pdf_content)
  
  # Upload to S3 if configured
  if ENV['AWS_S3_BUCKET']
    s3 = Aws::S3::Resource.new
    obj = s3.bucket(ENV['AWS_S3_BUCKET']).object(s3_key('resume.pdf'))
    obj.upload_file(local_path)
  end
end
```

## Post-Deployment Checklist

- [ ] Database migrations ran successfully
- [ ] Output directory exists and is writable
- [ ] Config YAML files present and valid
- [ ] SECRET_KEY_BASE set
- [ ] SSL/TLS configured (use Certbot for Let's Encrypt)
- [ ] Firewall configured (ufw allow 80,443)
- [ ] Monitoring set up (Sentry, Skylight)
- [ ] Backups configured (database + PDFs)
- [ ] Health check endpoint working (`/up`)

## Monitoring

### Health Check
```bash
curl https://yourdomain.com/up
# Should return 200 OK
```

### Logs
```bash
# Heroku
heroku logs --tail

# Fly.io
fly logs

# VPS
tail -f /var/www/jobwizard/log/production.log
```

## Troubleshooting

### "Can't write to output directory"
```bash
# Check permissions
ls -la /var/www/jobwizard/storage

# Fix permissions
chown -R deploy:deploy /var/www/jobwizard/storage
chmod 755 /var/www/jobwizard/storage
```

### "Database connection failed"
```bash
# Check DATABASE_URL
echo $DATABASE_URL

# Test connection
rails db:migrate:status
```

### "PDFs not generating"
```bash
# Check logs for errors
grep "PdfOutputManager" log/production.log

# Verify Prawn gem installed
bundle list | grep prawn
```

## Scaling Considerations

### When to Scale
- > 100 concurrent users
- > 1000 PDFs generated per day
- Response times > 2 seconds

### Scaling Strategy
1. **Horizontal**: Add more Heroku dynos / Fly.io instances
2. **Background Jobs**: Move PDF generation to Sidekiq
3. **CDN**: Serve static assets from CloudFront
4. **Database**: Upgrade to larger PostgreSQL instance
5. **Caching**: Add Redis for YAML caching
```

**Effort**: M (6-8 hours)  
**Impact**: HIGH - Enables production deployment

---

### 4. Configuration YAML Documentation (MEDIUM)

**Current State**: Inline comments in `experience.yml`

**Missing**:
```markdown
# docs/CONFIGURATION.md (MISSING)

# Configuration Guide - JobWizard

## Overview

JobWizard uses YAML files to store your resume data. These files are the **single source of truth** - the app will NEVER fabricate information not present in these files.

## File Locations

- `config/job_wizard/profile.yml` - Personal info, summary, education
- `config/job_wizard/experience.yml` - Work history, skills with levels
- `config/job_wizard/rules.yml` - Red flags to detect in job descriptions

## profile.yml Structure

```yaml
name: "Your Full Name"
email: "your.email@example.com"
phone: "+1 (555) 123-4567"
location: "City, State"
linkedin: "https://linkedin.com/in/yourname"
github: "https://github.com/yourname"
website: "https://yourwebsite.com"  # Optional

summary: |
  A concise 2-3 sentence professional summary highlighting:
  - Your core expertise
  - Years of experience
  - What you're looking for
  
  Keep it warm and professional, not a bullet list.

achievements:
  - "Led team of 5 engineers to deliver $2M revenue feature"
  - "Reduced page load time by 60% through optimization"
  - "Mentored 10+ junior developers, 3 promoted to senior roles"

education:
  - degree: "Bachelor of Science in Computer Science"
    institution: "University Name"
    year: "2015"
    honors: "Magna Cum Laude"  # Optional
```

### Tips for profile.yml
- Keep summary under 500 characters
- Use specific numbers in achievements ("60%" not "significantly")
- List only significant honors/awards in education

## experience.yml Structure

### New Format (Recommended)

```yaml
skills:
  # Expert level: 2+ years daily use, can architect/teach
  - name: "Ruby on Rails"
    level: "expert"
    context: "Primary framework for 5+ years, built 10+ production apps"
  
  - name: "PostgreSQL"
    level: "expert"
    context: "Designed schemas for 1M+ user applications"
  
  # Intermediate level: 6mo-2yr, can solve problems independently
  - name: "React"
    level: "intermediate"
    context: "Built 5+ SPAs, comfortable with hooks and state management"
  
  - name: "Docker"
    level: "intermediate"
    context: "Use for local development and debugging containers"
  
  # Basic level: < 6mo or light exposure
  - name: "Kubernetes"
    level: "basic"
    context: "Monitored deployments, basic kubectl commands"
  
  - name: "Terraform"
    level: "basic"
    context: "Modified existing configs, deployed staging environments"

positions:
  - company: "Company Name"
    title: "Senior Software Engineer"
    dates: "Jan 2020 - Present"
    description: "Team name or one-line summary"
    achievements:
      - "Specific accomplishment with measurable result"
      - "Another achievement (use action verbs: Led, Built, Reduced)"
      - "3-5 bullets per position recommended"
    
  - company: "Previous Company"
    title: "Software Engineer"
    dates: "Jun 2017 - Dec 2019"
    description: "What the team/product did"
    achievements:
      - "Achievement 1"
      - "Achievement 2"
```

### Skill Levels Explained

| Level | Meaning | Resume Phrase | Example Context |
|-------|---------|---------------|-----------------|
| **expert** | 2+ years, can mentor | "Deep experience with X" | "Rails framework expert, built 10+ apps" |
| **intermediate** | 6mo-2yr, productive | "Working proficiency with X" | "React for SPAs, comfortable with hooks" |
| **basic** | < 6mo, learning | "Familiar with X" | "Kubernetes monitoring, basic kubectl" |

### Truth-Safety Guarantee

⚠️ **Important**: JobWizard will ONLY use skills listed in this file.

**Example**:
- Job requires: "Blockchain experience"
- Your experience.yml: No "Blockchain" listed
- **Result**: "Blockchain" will NOT appear in your resume or cover letter

This ensures you never make false claims.

### Backward Compatibility

#### Old Flat Format (Still Supported)
```yaml
verified_skills:
  - Ruby on Rails
  - PostgreSQL
  - React

# All skills default to "intermediate" level
```

#### Old Tiered Format (Still Supported)
```yaml
skills:
  proficient:        # Mapped to "expert"
    - Ruby on Rails
  working_knowledge: # Mapped to "intermediate"
    - Docker
  familiar:          # Mapped to "basic"
    - Kubernetes
```

## rules.yml Structure

```yaml
blocking:
  - pattern: '\bunpaid\b'
    message: "Unpaid position"
    severity: "error"

warnings:
  - pattern: '\bUS\s+(citizens?|only)\b'
    message: "US citizenship required"
    note: "You're a US citizen but digital nomad - may have location restrictions"
    severity: "warning"

info:
  - pattern: '\bcompetitive\s+salary\b'
    message: "Compensation not specified"
    severity: "info"
```

### Severity Levels
- `error` - Red flag, blocks PDF generation
- `warning` - Yellow flag, shown in UI but allows generation
- `info` - Blue flag, informational only

## Validation

### Test Your Configuration

```bash
# Validate YAML syntax
ruby -ryaml -e "YAML.load_file('config/job_wizard/profile.yml')"

# Run smoke tests
./test/smoke_test_resume_builder.rb
```

### Common Errors

**Error**: "Psych::SyntaxError"
- **Cause**: Invalid YAML (usually indentation)
- **Fix**: Use 2 spaces for indentation, check quotes

**Error**: "Skills not appearing in PDF"
- **Cause**: Skill name doesn't match JD exactly
- **Fix**: Use exact capitalization ("Ruby on Rails" not "rails")

**Error**: "PDF generation failed"
- **Cause**: Missing required fields in profile.yml
- **Fix**: Ensure name, email, summary are present
```

**Effort**: M (4-6 hours)  
**Impact**: MEDIUM - Reduces config errors

---

## Documentation Checklist

### Existing Documentation
- [x] README.md (basic)
- [x] AI diagnostic prompt (ai/prompts/diagnostic_prompt.md)
- [x] Implementation plan (ai/plan.md)
- [x] HTML entity bug fix doc (ai/fixes/2025-10-21_html_entity_bug_fix.md)

### Missing Documentation (Priority Order)

**P1 - Critical** (Ship blockers):
- [ ] ENV_VARS.md - Complete environment variable reference
- [ ] bin/setup - Automated developer setup script
- [ ] DEPLOYMENT.md - Production deployment guide

**P2 - High** (Reduces friction):
- [ ] CONFIGURATION.md - YAML file structure guide
- [ ] CONTRIBUTING.md - How to contribute, code style
- [ ] TROUBLESHOOTING.md - Common errors and solutions
- [ ] API.md - Internal API documentation for services

**P3 - Nice to Have** (Polish):
- [ ] ARCHITECTURE.md - System design diagrams
- [ ] CHANGELOG.md - Version history
- [ ] SECURITY.md - Security policy, vulnerability reporting
- [ ] CODE_OF_CONDUCT.md - Community guidelines

---

## Inline Documentation Gaps

### Missing Docstrings
```ruby
# Current: No documentation
class ResumeBuilder
  def initialize(job_description:, allowed_skills: nil)
    # ...
  end
end

# Better: Add YARD documentation
class ResumeBuilder
  # Builds truth-only resume and cover letter PDFs from job description.
  #
  # @param job_description [String] The full job description text
  # @param allowed_skills [Array<String>, nil] Whitelist of skills to include (nil = all verified skills)
  #
  # @example Generate resume for specific skills only
  #   builder = ResumeBuilder.new(
  #     job_description: "Rails and React developer needed",
  #     allowed_skills: ['Rails']  # Exclude React
  #   )
  #   pdf = builder.build_resume
  #
  # @see ExperienceLoader For skill verification logic
  # @see PdfOutputManager For file output handling
  def initialize(job_description:, allowed_skills: nil)
    # ...
  end
end
```

**Files Needing Docstrings**:
- `app/services/job_wizard/resume_builder.rb`
- `app/services/job_wizard/rules_scanner.rb`
- `app/services/job_wizard/experience_loader.rb`
- `app/services/job_wizard/pdf_output_manager.rb`
- All Fetchers
- All Writers

**Effort**: M (6-8 hours)

---

## README Improvements

### Current State
- Basic installation instructions
- No architecture overview
- No screenshots
- No feature list

### Recommended Additions
```markdown
# Add to README.md

## Features

- ✅ **Truth-Only PDFs**: Never fabricates skills or experience
- ✅ **Skill Level Awareness**: Expert/Intermediate/Basic phrasing
- ✅ **Multi-Source Job Board**: Fetch from Greenhouse, Lever
- ✅ **Red Flag Scanner**: Warns about unpaid, vague comp, US-only roles
- ✅ **Skill Review Flow**: Approve skills before PDF generation
- ✅ **AI Cover Letters**: Optional Anthropic/OpenAI integration
- ✅ **Finder Integration**: Open PDFs directly in macOS Finder

## How It Works

```
Your YAML Config → Job Description → Skill Detection → Review → PDFs
     (truth)          (input)        (matching)       (approve)  (output)
```

1. **Configure once**: Fill in `profile.yml` and `experience.yml` with your real resume data
2. **Paste JD**: Enter any job description (or fetch from Greenhouse/Lever)
3. **Review skills**: Approve which skills to highlight for this role
4. **Generate**: Get tailored `resume.pdf` and `cover_letter.pdf` instantly
5. **Apply**: PDFs saved to `~/Documents/JobWizard/Company - Role - Date/`

## Screenshots

[Add screenshots of:]
- Dashboard with Quick Apply
- Skill review page
- Generated PDF examples
- Job board listing

## Architecture

### Services
- `ResumeBuilder` - PDF generation with skill filtering
- `ExperienceLoader` - YAML parsing and skill normalization
- `RulesScanner` - Red flag detection
- `PdfOutputManager` - Filesystem operations
- `Fetchers::*` - External API integration (Greenhouse, Lever)
- `WriterFactory` - Cover letter generation (Templates/AI)

### Truth-Safety Mechanism
```ruby
# Only skills in experience.yml appear in PDFs
jd = "Need Blockchain experience"
builder = ResumeBuilder.new(job_description: jd)

# If "Blockchain" not in experience.yml:
builder.claimed_skills    # => []
builder.not_claimed_skills # => ["Blockchain"]

# PDF will NOT mention Blockchain
```

## FAQ

**Q: Will this fabricate skills I don't have?**  
A: No. The app ONLY uses skills from your `experience.yml` file.

**Q: How do I add new skills?**  
A: Edit `config/job_wizard/experience.yml`, add to `skills` array.

**Q: Can I use AI for cover letters?**  
A: Yes. Set `AI_WRITER=anthropic` and `ANTHROPIC_API_KEY=...`

**Q: Where are PDFs saved?**  
A: Default: `~/Documents/JobWizard/Applications/Company/Role/YYYY-MM-DD/`  
   Configure: `JOB_WIZARD_OUTPUT_ROOT=/custom/path`

**Q: Is this production-ready?**  
A: For personal use: Yes. For multi-user: Add authentication first (see AUDIT_SECURITY.md).
```

**Effort**: M (3-4 hours)

---

## Next Steps

1. **Immediate** (today):
   - Create `docs/ENV_VARS.md`
   - Add API key instructions to README
   - Document YAML validation errors

2. **This Week**:
   - Create `bin/setup` script
   - Write `docs/DEPLOYMENT.md`
   - Add YARD docstrings to services

3. **This Month**:
   - Record demo video
   - Add architecture diagram
   - Write comprehensive TROUBLESHOOTING.md

---

**Documentation Priority**: Focus on P1 (Critical) docs first - they unblock deployment and onboarding.

**Recommended Tools**:
- YARD for API documentation
- Mermaid for architecture diagrams
- Screen Studio for demo videos
- DocToc for auto-generating table of contents




