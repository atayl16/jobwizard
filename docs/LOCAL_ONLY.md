# Local-Only Development Guide

**JobWizard runs entirely locally** - no external services required for development.

## What "Local-Only" Means

### Database: SQLite
- **Development:** `storage/development.sqlite3`
- **Test:** `storage/test.sqlite3`
- **Production:** Can be swapped to PostgreSQL when deploying

**No PostgreSQL installation needed** for local development.

### Background Jobs: ActiveJob :async
- **Default:** `config.active_job.queue_adapter = :async`
- **No Redis/Sidekiq:** Jobs run in-memory threads
- **Perfect for:** PDF generation, email sending, API calls

**No Redis installation needed** for local development.

### No External Services Required
- ✅ Database: SQLite (built-in)
- ✅ Background jobs: :async adapter (built-in)
- ✅ Email: Send emails to console (development)
- ✅ File storage: Local filesystem

---

## Environment Variables

### Customize Output Paths

```bash
# Override default output directory
export JOB_WIZARD_OUTPUT_ROOT=~/Desktop/Applications

# Change path style
export JOB_WIZARD_PATH_STYLE=simple   # ~/Documents/JobWizard/Applications/Company-Role/
export JOB_WIZARD_PATH_STYLE=nested   # ~/Documents/JobWizard/Applications/Company/Role/YYYY-MM-DD/

# Default: JOB_WIZARD_OUTPUT_ROOT=~/Documents/JobWizard
```

### Optional: OpenAI Integration

```bash
# Add to .env file (optional)
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o-mini
```

**Without OpenAI:** Uses template-based generation (works fine!)

---

## Quick Commands

```bash
# Start server
bin/dev

# Run tests
bundle exec rspec

# Auto-fix linter issues
bundle exec rubocop -A

# Security scans
bundle exec bundler-audit check
bundle exec brakeman -q

# Reset database
rails db:reset

# Generate PDFs
# Via web UI: /applications/new
```

---

## Why Local-Only?

### Benefits
- ✅ **Zero setup** - No PostgreSQL, Redis, or external services
- ✅ **Fast** - No network latency
- ✅ **Safe** - No risk of breaking production
- ✅ **Portable** - Works on any machine with Ruby

### When You Might Need PostgreSQL
- Deploying to Heroku/Render (production)
- Testing PostgreSQL-specific features
- Team requires production parity

**To add PostgreSQL:**
```bash
# Add to Gemfile
gem "pg", "~> 1.1"

# Update config/database.yml
# production:
#   adapter: postgresql

# Run migrations
rails db:migrate
```

---

## Deployment Considerations

### Keep Local-Only for Development
- SQLite works perfectly for local dev
- Fast iteration, no setup hassles

### Switch to PostgreSQL for Production
- Heroku/Render require PostgreSQL
- Better for concurrent users
- Production data durability

**Migration is simple:** Just change `config/database.yml` in production.

---

## Troubleshooting

### "Can't connect to database"
```bash
rails db:migrate
rails db:setup
```

### "No such file or directory"
```bash
# Create output directory
mkdir -p ~/Documents/JobWizard
```

### "Background jobs not running"
- Check `config/application.rb` has `queue_adapter = :async`
- Restart Rails server

---

*AUTOPILOT Mode: Local-first development*


