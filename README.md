# JobWizard 🧙‍♂️

A Rails 8 application that generates human-sounding, truth-only résumé and cover letter PDFs tailored to any job description.

## Features

✨ **Manual Application Generator**
- Paste any job description
- Generates tailored resume.pdf and cover_letter.pdf
- **Optional AI-powered generation** (OpenAI GPT-4o-mini) or template-based
- Only uses verified information from your profile
- Flags unverified skills and job requirements

📋 **Automated Job Board**
- Fetches jobs from Greenhouse and Lever APIs
- Pre-scans for red flags and requirements
- One-click "Tailor & Export" PDF generation
- Background job processing
- **Search & filters**: Search by company/title/keywords, filter by date and score
- **Smart status tracking**: Jobs stay ignored/applied after refetch
- **Deduplication**: Prevents duplicate jobs from multiple fetches
- **"Check for New Jobs" button**: Manual fetch trigger with background processing

🗂️ **Smart File Organization**
- Saves to: `~/Documents/JobWizard/Applications/<Company>/<Role>/<YYYY-MM-DD>/`
- Maintains "Latest" symlink to most recent application
- Download PDFs directly from web interface
- Customizable via `JOB_WIZARD_OUTPUT_ROOT` env var

🛡️ **Truth-Only Generation**
- All content sourced from `config/job_wizard/*.yml` files
- Never fabricates skills or experience
- Flags skills not in your verified experience
- Red-flag scanner warns about problematic requirements

🚫 **Smart Filtering**
- Automatically blocks NSFW, gambling, and adult content
- Filters out security clearance requirements
- Maintains Ruby/Rails focus with keyword requirements
- Company blocklist with regex support
- Manual "Block Company" action from job board

💰 **AI Cost Tracking** (Optional)
- Tracks OpenAI API usage and costs (gpt-4o-mini: ~$0.002 per application)
- Month-to-date dashboard display
- Detailed usage ledger at `/ai/usages`
- Historical cost tracking persists even if API key removed

## Quick Start

### 1. Install Dependencies
```bash
bundle install
```

### 2. Setup Database
```bash
bin/rails db:create db:migrate
```

### 3. Configure Your Profile

Edit these files with your real information:

**`config/job_wizard/profile.yml`**
```yaml
name: "Your Name"
email: "you@example.com"
phone: "+1-555-0100"
location: "Houston, TX (Remote)"
linkedin: "linkedin.com/in/yourprofile"
github: "github.com/yourusername"

summary: |
  Your professional summary here...

core_skills:
  - Ruby on Rails
  - PostgreSQL
  - JavaScript
  # ... your actual skills
```

**`config/job_wizard/experience.yml`**
```yaml
positions:
  - company: "Current Company"
    title: "Senior Software Engineer"
    dates: "2020 - Present"
    achievements:
      - "Built feature X that improved Y by Z%"
      # ... your real achievements
    skills:
      - Ruby on Rails
      - PostgreSQL
      # ... technologies you actually used
```

**`config/job_wizard/rules.yml`** (already configured with sensible defaults)

### 4. (Optional) Enable AI Generation

JobWizard can use OpenAI to generate more natural, tailored content. **This is completely optional** - the app works great with template-based generation.

```bash
# Get your API key from https://platform.openai.com/api-keys
export OPENAI_API_KEY=sk-your-key-here

# Test it
rake ai:cover_letter["Acme Corp","Senior Rails Engineer"]
```

Cost: ~$0.001 per application with gpt-4o-mini (one-tenth of a cent).

See **[docs/AI_WRITER_SETUP.md](docs/AI_WRITER_SETUP.md)** for full configuration options and troubleshooting.

**Without an API key**: The app automatically uses high-quality template-based generation instead.

### 5. Start the Server
```bash
bin/dev
```

Visit http://localhost:3000

## Skill Levels & Context

JobWizard now supports nuanced skill levels with optional context for more honest and tailored resumes!

### The New Format

In `config/job_wizard/experience.yml`, use the new `skills` array:

```yaml
skills:
  - name: "Ruby on Rails"
    level: "expert"           # expert, intermediate, or basic
    context: "Primary framework for 5+ years"
  - name: "Docker"
    level: "intermediate"
    context: "Local development and container debugging"
  - name: "Kubernetes"
    level: "basic"
    context: "Monitored pod health in production clusters"
```

### Skill Levels

- **expert** (proficient/advanced) → "Deep experience with…"
- **intermediate** (working_knowledge) → "Working proficiency with…"
- **basic** (familiar/beginner) → "Familiar with…"

### PDF Generation

The resume builder automatically:
1. **Highlights expert skills first** with contexts in parentheses
2. **Groups intermediate skills** under "Working proficiency:"
3. **Lists basic skills** under "Also familiar with:"
4. **Excludes unclaimed skills** - any JD skill not in your experience.yml

### Backward Compatibility

Old formats still work! The system automatically normalizes:

**Old Flat Array:**
```yaml
verified_skills:
  - Ruby on Rails
  - PostgreSQL
  - Docker
# All skills default to intermediate level
```

**Old Tiered Format:**
```yaml
skills:
  proficient:           # → expert
    - Ruby on Rails
  working_knowledge:    # → intermediate
    - Docker
  familiar:             # → basic
    - Terraform
```

### Not Claimed Skills

When you paste a job description, any skills mentioned that aren't in your `experience.yml` will:
- Be marked as "Not Claimed" in the UI
- **NOT appear in your generated PDFs** (truth-only!)
- Show up in a purple box on the application page so you can decide to add them later

Example: If a JD mentions "Elasticsearch" but you don't have it in your YAML, it won't be fabricated in your resume.

## Dashboard

JobWizard features a unified dashboard at `/` with three main sections:

### 🚀 Quick Apply

Paste any job description and JobWizard will:
- **Auto-extract** company name and role (editable before submitting)
- Generate tailored resume + cover letter PDFs instantly
- Save files to `~/Documents/JobWizard/Applications/<Company>/<Role>/<Date>/`
- Show download links immediately

The parsing is lightweight and heuristic-based—if it misses the company or role, just type them in!

### 💼 Suggested Jobs

View job postings fetched from Greenhouse/Lever APIs. Each job has a **Generate PDFs** button that:
- Creates an application record
- Generates tailored documents
- Updates the recent applications list live (via Turbo)

Run `rake jobs:fetch[greenhouse,company-slug]` to populate this section.

### 📋 Recent Applications

See your last 10 generated applications with:
- **Download links** for resume and cover letter
- **Status badges** (✓ Ready, ⋯ Draft, ✗ Error)
- **Disk path reveal** (dev-only) - click to see the exact Finder path

### 📁 Output Path Banner

Always visible at the top, showing where your PDFs are saved. In development mode, there's an **Open Folder** button that opens the root output directory in Finder.

## Usage

### Dashboard (Quick Apply)

1. Visit the homepage (`http://localhost:3000`)
2. Paste a job description in the **Quick Apply** textarea
3. Watch as company and role auto-fill (edit if needed)
4. Click **Generate PDFs**
5. Download links appear immediately in the **Recent Applications** section

PDFs are automatically saved to `~/Documents/JobWizard/Applications/<Company>/<Role>/<YYYY-MM-DD>/`

### Traditional Application Form

Visit `/applications/new` for the classic form with more detailed flags and analysis.

### Automated Job Board

### Configuring Job Sources

Edit `config/job_wizard/sources.yml` to add companies you want to track:

```yaml
sources:
  - provider: greenhouse
    slug: instacart
    name: Instacart
    active: true

  - provider: lever
    slug: figma
    name: Figma
    active: true
```

**Finding Company Slugs:**
- **Greenhouse**: Visit careers page, look for `boards.greenhouse.io/<SLUG>` (examples: `gitlab`, `shopify`, `stripe`)
- **Lever**: Visit careers page, look for `jobs.lever.co/<SLUG>` (examples: `canva`, `notion`, `figma`)
- **SmartRecruiters**: Check careers page source for `smartrecruiters.com`
- **Personio**: Look for `<SLUG>.jobs.personio.de` (common in Europe)

### Fetching Jobs

**Fetch from all active sources in sources.yml:**
```bash
rake jobs:fetch_all
```

**Or click "Check for New Jobs" button in the UI** (runs in background)

**View the job board:**
Visit http://localhost:3000/jobs

Click any job → "Tailor & Export" to generate PDFs

### Filter Management

**Block companies from job board:**
Click "Block" on any job row to immediately hide all jobs from that company.

**Manage filters:**
Visit `/settings/filters` to:
- Add/remove blocked companies (exact match or regex)
- View current filtering rules
- See YAML-defined blocklists

### Rake Tasks

```bash
# Fetch from specific provider
rake jobs:fetch[provider,slug]

# Fetch from all active sources
rake jobs:board

# Fetch and auto-generate PDFs
rake jobs:board[true]

# Clean old postings (90+ days)
rake jobs:clean
```

## Architecture

### Core Services

**`JobWizard::PdfOutputManager`**
- Manages filesystem structure
- Creates predictable paths with safe slugs
- Maintains "Latest" symlink
- Writes to both output and tmp locations

**`JobWizard::RulesScanner`**
- Scans job descriptions against rules.yml
- Categorizes flags: warnings, blocking, info
- Detects unverified skills
- Configurable patterns

**`JobWizard::ResumeBuilder`**
- Generates PDFs using Prawn
- Professional, ATS-friendly formatting
- Only uses verified YAML data
- Tailors emphasis based on JD

**`JobWizard::Fetchers::{Greenhouse,Lever}`**
- HTTParty-based API clients
- Normalize job data to common format
- Graceful error handling

### Models

- **JobPosting** - Fetched jobs from external APIs
- **JobSource** - Tracks active fetching sources
- **Application** - Generated application with status tracking

### Background Jobs

- **GeneratePdfsJob** - Async PDF generation with retry logic

## Project Structure

```
app/
├── controllers/       # ApplicationsController, JobsController
├── jobs/             # GeneratePdfsJob
├── models/           # JobPosting, JobSource, Application
├── services/         # Core PDF generation logic
│   └── job_wizard/
│       ├── pdf_output_manager.rb
│       ├── rules_scanner.rb
│       ├── resume_builder.rb
│       └── fetchers/
│           ├── greenhouse.rb
│           └── lever.rb
└── views/            # Tailwind-styled templates

config/
├── job_wizard/       # Your profile, experience, and rules
│   ├── profile.yml
│   ├── experience.yml
│   └── rules.yml
└── initializers/
    └── job_wizard.rb # Configuration constants

lib/tasks/
└── jobs.rake         # Rake tasks for job fetching

test/
├── smoke_test_pdf_output_manager.rb
├── smoke_test_rules_scanner.rb
└── smoke_test_resume_builder.rb
```

## Testing

### Smoke Tests (No Database Required)
```bash
ruby test/smoke_test_pdf_output_manager.rb
ruby test/smoke_test_rules_scanner.rb
ruby test/smoke_test_resume_builder.rb
```

All smoke tests passing ✅

### Code Quality
```bash
bundle exec rubocop -A app/ lib/tasks/
```

## Configuration

### Environment Variables

**`JOB_WIZARD_OUTPUT_ROOT`** (optional)
- Default: `~/Documents/JobWizard`
- Override to change PDF output location
- Example: `JOB_WIZARD_OUTPUT_ROOT=/custom/path`

### YAML Files

Update these files with your real information:

1. **`config/job_wizard/profile.yml`** - Personal info, skills, education
2. **`config/job_wizard/experience.yml`** - Work history, projects, verified skills
3. **`config/job_wizard/rules.yml`** - Flag patterns (pre-configured with sensible defaults)

## Tech Stack

- **Rails 8.0** - Modern Rails with Solid Queue, Solid Cache, Solid Cable
- **Tailwind CSS** - Utility-first styling
- **Prawn** - PDF generation
- **HTTParty** - API client
- **PostgreSQL** - Database
- **Stimulus** - JavaScript framework

## Development

### Prerequisites

- Ruby 3.3.4+
- PostgreSQL
- Node.js (for Tailwind)

### Setup

```bash
git clone <repo>
cd JobWizard
bundle install
bin/rails db:create db:migrate
bin/dev
```

### Adding New Job Sources

```bash
# Add to database
rake jobs:fetch[greenhouse,company-slug]
rake jobs:fetch[lever,company-slug]

# Source will be saved as active
# Future `rake jobs:board` calls will fetch from this source
```

## Deployment

Ready for deployment with:
- Kamal (Docker-based deployment)
- Solid Queue (background jobs)
- Solid Cache (caching)
- Solid Cable (WebSockets)

## Contributing

This is a personal project, but feel free to fork and adapt!

## License

Private - Not for distribution

## Acknowledgments

Built with ❤️ using Rails 8, Prawn, and Tailwind CSS
