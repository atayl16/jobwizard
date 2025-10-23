# JobWizard - Local-Only Configuration Guide

**Last Updated**: 2025-10-21  
**Target Environment**: macOS development (single user, no deployment)

---

## Overview

JobWizard is designed as a **local-only** Rails app that runs on your Mac to generate truth-only resume and cover letter PDFs. It's optimized for personal use with minimal setup complexity.

**Key Principles**:
- 🏠 Single-user, no authentication needed
- 📁 PDFs saved directly to your Mac filesystem
- 🗄️ SQLite database (no PostgreSQL required)
- ⚡ ActiveJob with `:async` adapter (no Redis/Sidekiq needed)
- 🔍 Finder integration for macOS workflow
- 🎯 Truth-only: Never fabricates skills or experience

---

## Environment Variables

### Core Configuration

#### `JOB_WIZARD_OUTPUT_ROOT`
**Purpose**: Where PDFs and application folders are created on your Mac

**Default**: `~/Documents/JobWizard`

**Examples**:
```bash
# Default (recommended)
# PDFs go to: ~/Documents/JobWizard/Applications/...

# Custom location (Dropbox)
export JOB_WIZARD_OUTPUT_ROOT="/Users/yourname/Dropbox/JobApplications"

# Custom location (Desktop for quick access)
export JOB_WIZARD_OUTPUT_ROOT="/Users/yourname/Desktop/JobWizard"
```

**How it works**:
- Directory created automatically if it doesn't exist
- Must be writable by your user account
- Subdirectories created per company/role/date
- Symlink `Latest/` always points to most recent application

**Verify it's working**:
```bash
# Check current setting
rails runner "puts JobWizard::OUTPUT_ROOT"

# List generated applications
ls -la ~/Documents/JobWizard/Applications/
```

---

#### `JOB_WIZARD_PATH_STYLE`
**Purpose**: Choose between flat and nested folder structures

**Default**: `simple` (flat structure)

**Options**:

**Option 1: `simple` (Recommended)**
```bash
export JOB_WIZARD_PATH_STYLE=simple

# Creates:
~/Documents/JobWizard/
  ├─ Instacart - Backend Engineer - 2025-10-21/
  │   ├─ resume.pdf
  │   └─ cover_letter.pdf
  ├─ Netflix - Senior Developer - 2025-10-22/
  │   ├─ resume.pdf
  │   └─ cover_letter.pdf
  └─ Latest/  (symlink → most recent)
```

**Pros**:
- ✅ Easy to browse in Finder
- ✅ All applications at same level
- ✅ Quick search with Spotlight
- ✅ Alphabetical sorting by company

**Option 2: `nested` (Deep hierarchy)**
```bash
export JOB_WIZARD_PATH_STYLE=nested

# Creates:
~/Documents/JobWizard/
  └─ Applications/
      ├─ Instacart/
      │   └─ BackendEngineer/
      │       └─ 2025-10-21/
      │           ├─ resume.pdf
      │           └─ cover_letter.pdf
      ├─ Netflix/
      │   └─ SeniorDeveloper/
      │       └─ 2025-10-22/
      │           ├─ resume.pdf
      │           └─ cover_letter.pdf
      └─ Latest/  (symlink)
```

**Pros**:
- ✅ Organized by company, then role
- ✅ Multiple roles per company grouped
- ✅ Versions per role over time

**Recommendation**: Use `simple` for most cases - easier to navigate in Finder.

---

### Optional: AI Cover Letters

#### `AI_WRITER`
**Purpose**: Enable AI-generated cover letters (instead of templates)

**Default**: (empty - uses template-based generation)

**Options**: `anthropic`, `openai`

**Example**:
```bash
# Use Claude (Anthropic)
export AI_WRITER=anthropic
export ANTHROPIC_API_KEY=sk-ant-your-key-here

# Use ChatGPT (OpenAI)
export AI_WRITER=openai
export OPENAI_API_KEY=sk-your-key-here
```

**Fallback Behavior**:
- If `AI_WRITER` set but API key missing → Falls back to TemplatesWriter with warning
- If `AI_WRITER` not set → Uses TemplatesWriter (no API calls)

**Cost Considerations** (if using AI):
- Anthropic Claude: ~$0.01-0.03 per cover letter
- OpenAI GPT-4: ~$0.02-0.05 per cover letter
- Template writer: $0.00 (always free)

---

## File Output Workflow

### Where PDFs Are Saved

**Primary Location** (for Finder access):
```
~/Documents/JobWizard/
  ├─ [Company] - [Role] - [YYYY-MM-DD]/
  │   ├─ resume.pdf
  │   └─ cover_letter.pdf
  └─ Latest/  (symlink → most recent)
```

**Secondary Location** (for Rails downloads):
```
[Rails.root]/tmp/outputs/
  └─ [Same structure as above]
```

**Why Two Locations?**
- Primary: For opening in Finder, organizing in your file system
- Secondary: For `send_file` downloads via browser (Rails can't serve from `~`)

**Pro Tip**: Use the "Open in Finder" button (dev mode only) to jump directly to the PDF folder!

---

### Finder Integration

#### "Open in Finder" Buttons

**Where they appear** (in development mode):
1. **Header toolbar**: Opens root output folder
2. **Application show page**: Opens specific application folder
3. **Recent applications list**: Quick-open each folder

**How it works**:
```ruby
# app/controllers/files/reveal_controller.rb
def create
  path = params[:path]
  system("open", "-R", path)  # macOS: Opens Finder and selects file
end
```

**Keyboard shortcut** (future enhancement):
- Press `⌘ + F` to open current application in Finder

---

### Latest Symlink

**Purpose**: Always points to your most recently generated application

**Usage**:
```bash
# Quick access to latest PDFs
open ~/Documents/JobWizard/Latest/resume.pdf

# Copy latest resume to Desktop
cp ~/Documents/JobWizard/Latest/resume.pdf ~/Desktop/

# Add to your shell aliases
alias latest-resume="open ~/Documents/JobWizard/Latest/resume.pdf"
alias latest-cover="open ~/Documents/JobWizard/Latest/cover_letter.pdf"
```

**How it works**:
```ruby
# app/services/job_wizard/pdf_output_manager.rb
def update_latest_symlink!
  latest_path = JobWizard::OUTPUT_ROOT.join('Latest')
  File.delete(latest_path) if File.symlink?(latest_path)
  File.symlink(output_path, latest_path)
end
```

---

## Background Jobs (Local Mode)

### ActiveJob Configuration

**Current Setup**: `:async` adapter (in-memory queue)

```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :async
```

**What this means**:
- Jobs run in background threads (not separate process)
- No Redis, Sidekiq, or external queue needed
- Perfect for local development
- Restarts when Rails server restarts

**When jobs run**:
- PDF generation: Synchronous (immediate, blocks request)
- Job fetching: Background (via `GeneratePdfsJob` if triggered from dashboard)

**Monitoring jobs**:
```bash
# Rails console
rails c
> Que.jobs  # (if using Que adapter)
> ActiveJob::Base.queue_adapter  # => :async
```

**Switching to Solid Queue** (future enhancement):
```bash
# For persistent background jobs that survive restarts
# Gemfile: gem 'solid_queue'
# config/environments/development.rb:
config.active_job.queue_adapter = :solid_queue
```

---

## Database: SQLite vs PostgreSQL

### Current Setup: SQLite3

**Why SQLite for local-only?**
- ✅ Zero configuration - works out of the box
- ✅ Single file database (`db/development.sqlite3`)
- ✅ No server process to manage
- ✅ Perfect for < 10,000 records
- ✅ Easy backups (just copy file)

**When to switch to PostgreSQL**:
- ❌ You hit 10,000+ job postings or applications
- ❌ You need concurrent writes (unlikely for single user)
- ❌ You want to use JSONB features heavily

**Sticking with SQLite** (recommended):
```ruby
# database.yml already configured
development:
  <<: *default
  database: storage/development.sqlite3

# Backup your database
cp storage/development.sqlite3 storage/development.sqlite3.backup
```

**Switching to PostgreSQL** (if needed):
```bash
# Install PostgreSQL
brew install postgresql@16
brew services start postgresql@16

# Update Gemfile
gem 'pg', '~> 1.1'

# Update database.yml
development:
  adapter: postgresql
  database: jobwizard_development

# Recreate database
rails db:drop db:create db:migrate db:seed
```

---

## Quick Start (New Machine Setup)

### 1. Clone and Install
```bash
git clone https://github.com/yourname/JobWizard.git
cd JobWizard
bundle install
```

### 2. Configure Your Resume Data
```bash
# Copy examples (if needed)
cp config/job_wizard/profile.yml.example config/job_wizard/profile.yml
cp config/job_wizard/experience.yml.example config/job_wizard/experience.yml

# Edit with your information
code config/job_wizard/profile.yml
code config/job_wizard/experience.yml
```

### 3. Set Up Database
```bash
rails db:prepare
```

### 4. (Optional) Configure ENV Vars
```bash
# Create .env file
touch .env

# Add custom settings (optional)
echo 'JOB_WIZARD_OUTPUT_ROOT=/Users/yourname/Dropbox/JobWizard' >> .env
echo 'JOB_WIZARD_PATH_STYLE=simple' >> .env
```

### 5. Start the Server
```bash
bin/dev
```

### 6. Generate Your First Resume
1. Visit http://localhost:3000
2. Paste a job description
3. Click "Review Skills & Generate"
4. Download your PDFs!

**Total time**: 10-15 minutes

---

## Common Local-Only Workflows

### Workflow 1: Quick Apply
```
1. Copy job description from LinkedIn/email
2. Visit http://localhost:3000
3. Paste JD in textarea
4. Click "Review Skills & Generate"
5. Select which skills to highlight
6. Click "Generate Documents"
7. Click "Open in Finder"
8. Attach resume.pdf and cover_letter.pdf to application
```

**Time**: ~2 minutes per application

---

### Workflow 2: Batch Job Fetch
```
1. Add job sources to db/seeds.rb:
   JobSource.create!(name: 'Airbnb', provider: 'greenhouse', slug: 'airbnb')

2. Fetch all jobs:
   rake jobs:board

3. Browse jobs at http://localhost:3000/jobs

4. Click "Tailor & Export" for interesting roles

5. PDFs auto-generated in background
```

**Time**: ~5 minutes for 100+ jobs

---

### Workflow 3: Finder-First
```
1. Generate PDFs via web UI

2. Press ⌘+F or click "Open in Finder"

3. Drag resume.pdf directly to email or LinkedIn

4. Copy cover_letter.pdf contents for inline paste

5. Latest/ symlink always has newest docs
```

**Time**: ~30 seconds per application (after initial generation)

---

## Troubleshooting (Local-Only)

### "Permission denied" writing PDFs
```bash
# Check permissions
ls -la ~/Documents/JobWizard

# Fix permissions
chmod 755 ~/Documents/JobWizard
```

### "Rails server won't start"
```bash
# Check if server already running
ps aux | grep puma

# Kill old server
kill -9 [PID]

# Or use rake task
rake restart

# Or delete PID file
rm tmp/pids/server.pid
```

### "Job descriptions show HTML tags"
```bash
# Re-fetch jobs to clean HTML entities
rake 'jobs:fetch[greenhouse,instacart]'

# Verify cleaning works
rails runner "puts JobPosting.last.description[0..200]"
# Should show clean text, no &lt; or &gt;
```

### "YAML syntax error"
```bash
# Validate YAML syntax
ruby -ryaml -e "YAML.load_file('config/job_wizard/profile.yml')"

# Common issues:
# - Mixing tabs and spaces (use 2 spaces)
# - Unescaped quotes (use 'single quotes' or "double quotes")
# - Missing colons after keys
```

### "Skills not appearing in PDF"
```bash
# Check if skill is in experience.yml
grep -i "docker" config/job_wizard/experience.yml

# Verify skill normalization
rails runner "puts JobWizard::ExperienceLoader.new.all_skill_names.to_a"

# Test skill detection
rails runner "
  jd = 'Need Docker experience'
  detector = JobWizard::SkillDetector.new(jd)
  puts detector.analyze.inspect
"
```

---

## Performance Tuning (Local)

### Speed Up PDF Generation

**Current**: ~800ms per PDF  
**Target**: <300ms per PDF

**Optimization 1: Cache YAML configs**
```bash
# Enable caching in development
rails dev:cache

# Verify caching
rails runner "
  2.times do
    start = Time.now
    JobWizard::ExperienceLoader.new
    puts Time.now - start
  end
"
# First: ~50ms, Second: ~0.5ms (cached)
```

**Optimization 2: Preload configs on boot**
```ruby
# config/initializers/job_wizard.rb (add this)
Rails.application.config.after_initialize do
  # Preload configs into memory on Rails boot
  JobWizard::EXPERIENCE_CACHE = JobWizard::ExperienceLoader.new
  JobWizard::PROFILE_CACHE = YAML.load_file(JobWizard::CONFIG_PATH.join('profile.yml'))
end
```

---

### Speed Up Job Fetching

**Current**: ~5s for 150 jobs  
**Target**: <2s for 150 jobs

**Optimization: Parallel fetching**
```ruby
# lib/tasks/jobs.rake (future enhancement)
task board: :environment do
  sources = JobSource.active
  
  # Fetch in parallel threads
  threads = sources.map do |source|
    Thread.new { fetch_source(source) }
  end
  
  threads.each(&:join)
end
```

---

## Backup & Sync (Local)

### Backup Your Data

**What to backup**:
1. Database: `storage/development.sqlite3`
2. Config files: `config/job_wizard/*.yml`
3. Generated PDFs: `~/Documents/JobWizard/` (optional)

**Backup script**:
```bash
#!/bin/bash
# bin/backup

BACKUP_DIR="$HOME/Backups/JobWizard/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

# Backup database
cp storage/development.sqlite3 "$BACKUP_DIR/"

# Backup configs
cp config/job_wizard/*.yml "$BACKUP_DIR/"

echo "✓ Backup saved to: $BACKUP_DIR"
```

**Restore from backup**:
```bash
# Restore database
cp ~/Backups/JobWizard/2025-10-21/development.sqlite3 storage/

# Restore configs
cp ~/Backups/JobWizard/2025-10-21/*.yml config/job_wizard/
```

---

### Sync Across Macs (Optional)

**Option 1: Dropbox**
```bash
# Set output to Dropbox
export JOB_WIZARD_OUTPUT_ROOT="$HOME/Dropbox/JobWizard"

# Symlink database to Dropbox (for sync)
mv storage/development.sqlite3 ~/Dropbox/JobWizard/database.sqlite3
ln -s ~/Dropbox/JobWizard/database.sqlite3 storage/development.sqlite3
```

**Option 2: iCloud Drive**
```bash
export JOB_WIZARD_OUTPUT_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/JobWizard"
```

**Option 3: Git (configs only)**
```bash
# DON'T commit:
# - Database (storage/*.sqlite3)
# - Generated PDFs (tmp/outputs/)
# - API keys (.env)

# DO commit:
# - Config YAMLs (config/job_wizard/*.yml)
# - Code changes
```

---

## Development Tips

### Auto-Open PDFs After Generation

Add to `~/.zshrc`:
```bash
# Auto-open latest resume in Preview
alias show-latest="open ~/Documents/JobWizard/Latest/resume.pdf"

# Auto-open latest in Finder
alias finder-latest="open ~/Documents/JobWizard/Latest/"
```

---

### Quick Job Description Capture

**macOS Service** (Automator):
1. Open Automator
2. New → Quick Action
3. Add "Run Shell Script":
   ```bash
   pbpaste > /tmp/jd_capture.txt
   open "http://localhost:3000/applications/new"
   ```
4. Save as "Send to JobWizard"
5. Assign keyboard shortcut: ⌘⌥J

**Usage**: Highlight JD text anywhere → Press ⌘⌥J → Opens JobWizard with JD ready to paste

---

### Spotlight Search for PDFs

**Make PDFs searchable**:
```bash
# Add metadata to PDFs (future enhancement)
mdls ~/Documents/JobWizard/Latest/resume.pdf

# Search from Spotlight
# Type: "Instacart resume" → Finds PDF instantly
```

---

## Local-Only Security Notes

Even though this is local-only, some security still matters:

### ✅ Keep Secured (P1)
- **Path traversal**: Fix `slugify` to prevent writing to `/etc` or system dirs
- **File uploads**: Limit size to prevent disk space exhaustion
- **API keys**: Don't commit to git (use .env, add to .gitignore)

### ⚠️ Optional (P2)
- **YAML validation**: Prevent accidental code injection from malformed configs
- **Session validation**: Re-check skills in finalize step

### ❌ NOT Needed (Deprioritized)
- Multi-user authentication
- HTTPS/SSL certificates
- Rate limiting
- CORS headers
- Production secret management
- Database encryption at rest

---

## Maintenance

### Weekly Tasks
```bash
# Clean old job postings (keeps last 30 days)
rake jobs:clean

# Backup database
./bin/backup

# Update gems
bundle update
```

### Monthly Tasks
```bash
# Check for security updates
bundle audit

# Run full test suite
bundle exec rspec

# Review and archive old applications
# Move old PDFs to "Archive" folder
```

---

## Upgrading Rails / Ruby

### Before Upgrading
```bash
# Backup everything
./bin/backup

# Run tests
bundle exec rspec

# Note current versions
ruby -v  # 3.3.4
rails -v  # 8.0.3
```

### After Upgrading
```bash
# Update gems
bundle update rails

# Run migrations
rails db:migrate

# Run tests
bundle exec rspec

# Verify app works
bin/dev
# Visit http://localhost:3000 and generate test PDF
```

---

## FAQ

**Q: Can I run this on Linux or Windows?**  
A: Mostly yes, but Finder integration won't work. Replace `open` with `xdg-open` (Linux) or `start` (Windows).

**Q: Do I need Redis for background jobs?**  
A: No! ActiveJob `:async` adapter uses in-memory queues - perfect for local use.

**Q: Can I use this offline?**  
A: Yes for manual JD entry. Job fetching requires internet to reach Greenhouse/Lever APIs.

**Q: How much disk space will this use?**  
A: ~5MB per application (2 PDFs). 100 applications = ~500MB. Database ~10-50MB for 1000 jobs.

**Q: Can I delete old applications?**  
A: Yes! Just delete the folder: `rm -rf ~/Documents/JobWizard/[Company] - [Role] - [Date]`  
   Or clean from Rails console: `Application.where("created_at < ?", 30.days.ago).destroy_all`

**Q: What if I want to share with a colleague?**  
A: Export your config YAMLs, they clone the repo and use their own resume data.

---

## Next Steps

1. **Verify your setup**:
   ```bash
   rails runner "puts JobWizard::OUTPUT_ROOT"
   rails runner "puts ENV['JOB_WIZARD_PATH_STYLE'] || 'simple'"
   ```

2. **Generate a test PDF**:
   - Visit http://localhost:3000
   - Paste any job description
   - Verify PDFs land in expected location

3. **Customize ENV vars** (if needed):
   - Add `.env` file with your preferences
   - Restart Rails server

4. **Set up Finder integration**:
   - Test "Open in Finder" buttons
   - Create shell aliases for quick access

---

**Last Updated**: 2025-10-21  
**Maintained by**: You! (This is your personal app)  
**Support**: See TROUBLESHOOTING.md or check audit docs



