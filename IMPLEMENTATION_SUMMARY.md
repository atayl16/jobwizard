# JobWizard Implementation Summary

## Features Added/Modified

### 1. Status Management ✅
- Added `rejected` status to JobPosting enum
- Added fields: `rejected_at`, `rejected_reason`, `notes`, `snooze_until`
- Added methods: `mark_rejected!`, `snooze_until!`, `snoozed?`
- Added scopes: `snoozed`, `unsnoozed`

### 2. Controller Actions ✅
- Added `rejected`, `snooze`, `update_notes` actions to JobsController
- Updated routes to support new actions

### 3. Status Filter Tabs ✅
- Added Active, Applied, Rejected, Ignored, Exported, All tabs
- Added status counts with badges
- Active tab highlighting
- Preserves status during search/filter

### 4. Rake Tasks ✅
- `rake jobs:prune_ignored` - removes ignored jobs older than N days (default 30)
- `rake jobs:prune_outputs` - keeps last N output folders (default 50)
- Configurable via ENV vars

### 5. Auto-Mark Applied ✅
- Auto-marks job as applied after successful PDF generation
- Controlled by `ENV['JOB_WIZARD_AUTO_MARK_APPLIED']`
- Only applies to jobs in 'suggested' status

### 6. Keyboard Shortcuts ✅
- `j`/`k`: navigate jobs
- `/`: focus search
- `a`: apply
- `i`: ignore
- `r`: reject

### 7. Blocklist Management ✅
- Added `SafeRulesWriter` service for safe YAML updates
- Existing UI in `/settings/filters`
- Supports adding/removing exclude keywords

### 8. Optional Dev Scheduler ✅
- Uses rufus-scheduler for dev-only background jobs
- Controlled by `ENV['JOB_WIZARD_SCHEDULE_FETCH']`
- Only runs in development environment

### 9. Role Analyzer ✅
- Added `JobRoleAnalyzer` service
- Extracts role summary bullets
- Calculates alignment score (0-100)
- Categorizes skills into Verified/Unverified/Not applicable

### 10. Optional Sidekiq Support ✅
- Added queue adapter configuration
- Defaults to :async for local-only development
- Can be switched to Sidekiq with `ENV['JOB_WIZARD_QUEUE_ADAPTER']`
- Mounts Sidekiq web UI in development at `/sidekiq`

### 11. Location Filtering ✅
- Enhanced filtering to reject country-specific jobs (except US)
- Rejects jobs with locations like "Germany", "Pakistan", "Philippines", etc.
- Allows "USA", "Remote", "Anywhere" without country restrictions

## New ENV Variables

- `JOB_WIZARD_AUTO_MARK_APPLIED` - Auto-mark applied after PDF generation (default: false)
- `JOB_WIZARD_PRUNE_DAYS` - Days before pruning ignored jobs (default: 30)
- `JOB_WIZARD_KEEP_OUTPUTS` - Number of output folders to keep (default: 50)
- `JOB_WIZARD_SCHEDULE_FETCH` - Schedule interval for dev scheduler (e.g., "10m")
- `JOB_WIZARD_QUEUE_ADAPTER` - Queue adapter: "async" or "sidekiq" (default: "async")

## Quick Start Commands

```bash
# Install dependencies
bundle install

# Run migrations
rails db:migrate

# Fetch jobs
rake jobs:fetch_all

# Start server
rails s

# Optional: Enable auto-mark applied
export JOB_WIZARD_AUTO_MARK_APPLIED=true

# Optional: Enable dev scheduler (every 10 minutes)
export JOB_WIZARD_SCHEDULE_FETCH=10m

# Optional: Prune old ignored jobs
rake jobs:prune_ignored

# Optional: Prune old outputs
rake jobs:prune_outputs

# Optional: Use Sidekiq (requires Redis + Sidekiq gem)
export JOB_WIZARD_QUEUE_ADAPTER=sidekiq
```

## Files Created/Modified

### Created:
- `db/migrate/20251023205851_add_missing_fields_to_job_postings.rb`
- `app/services/job_wizard/safe_rules_writer.rb`
- `app/services/job_wizard/job_role_analyzer.rb`
- `config/initializers/scheduler.rb`
- `app/javascript/keyboard_shortcuts.js`

### Modified:
- `app/models/job_posting.rb` - Added rejected status, fields, methods
- `app/controllers/jobs_controller.rb` - Added actions, status filtering
- `app/views/jobs/index.html.erb` - Added status tabs
- `lib/tasks/jobs.rake` - Added prune tasks
- `app/services/job_wizard/application_pdf_generator.rb` - Added auto-mark applied
- `app/services/job_wizard/job_filter.rb` - Enhanced location filtering
- `config/application.rb` - Added queue adapter configuration
- `config/routes.rb` - Added new actions, Sidekiq mount
- `Gemfile` - Added rufus-scheduler, commented Sidekiq

## Notes

- All changes maintain local-only defaults (SQLite, ActiveJob :async)
- Truth-only rule enforced throughout (no skill fabrication)
- No hard dependencies on external services
- Sidekiq support is optional and requires Redis
- Dev scheduler only runs in development environment

