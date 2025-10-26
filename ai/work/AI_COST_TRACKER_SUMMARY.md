# AI Cost Tracker & JD Features - Implementation Summary

## Implementation Status

### ✅ Part A: AI Cost Tracker - COMPLETE

**Database & Models:**
- ✅ Migration: `db/migrate/20251023131452_create_ai_usages.rb`
- ✅ Model: `app/models/ai_usage.rb`
- ✅ Features: Cost tracking, month-to-date stats, scopes

**Services:**
- ✅ `config/initializers/ai_costing.rb` - Pricing tables and cost estimation
- ✅ `app/services/ai_cost/recorder.rb` - Logs usage to database
- ✅ `app/services/ai_cost/stats.rb` - Month-to-date statistics

**Integration:**
- ✅ Updated `app/services/job_wizard/writers/open_ai_writer.rb` to track costs
- ✅ Updated `app/services/job_wizard/resume_builder.rb` to pass metadata

**UI:**
- ✅ Updated `app/controllers/dashboard_controller.rb` to load AI stats
- ✅ Updated `app/views/dashboard/show.html.erb` to display cost
- ✅ Created `app/controllers/ai/usages_controller.rb`
- ✅ Created `app/views/ai/usages/index.html.erb` with usage table
- ✅ Added routes to `config/routes.rb`

**Features:**
- Tracks every OpenAI API call with token counts
- Calculates cost using pricing table (gpt-4o-mini default)
- Shows month-to-date cost on dashboard
- Shows breakdown by feature (resume, cover_letter, etc.)
- `/ai/usages` shows detailed usage ledger
- Month filter available
- Historical cost tracking

### 🔄 Part B: JD Summarization - PARTIAL

**Services Created:**
- ✅ `app/services/jd/summarizer.rb` - AI and heuristic summarization
- ✅ `app/services/jd/skill_extractor.rb` - Skill extraction with profile matching

**Controllers Created:**
- ✅ `app/controllers/ai/jobs_controller.rb` - Summarize and skills endpoints
- ✅ Routes added for AI features

**Missing:**
- ❌ UI integration (not yet added to job show page)
- ❌ Safe experience writer (skipped for now)
- ❌ Skills approval workflow
- ❌ Tests

## What Works Now

### Cost Tracking
1. Set `OPENAI_API_KEY` environment variable
2. Generate a resume or cover letter
3. Visit dashboard `/` - see cost displayed
4. Visit `/ai/usages` - see detailed usage

### Pricing Configuration
Default pricing (gpt-4o-mini):
- Input: $0.15 per 1M tokens
- Cached Input: $0.075 per 1M tokens  
- Output: $0.60 per 1M tokens

Override via ENV:
```bash
export OPENAI_PRICE_INPUT_PER_M=0.15
export OPENAI_PRICE_OUTPUT_PER_M=0.60
```

### JD Summarization Services
Available but not yet wired to UI:
- `Jd::Summarizer.summarize(text:, job_posting_id:)`
- `Jd::SkillExtractor.extract(text:, job_posting_id:)`

Both fall back to heuristics if AI disabled.

## Environment Variables

```bash
# Required for AI features
OPENAI_API_KEY=sk-...

# AI Cost Tracker (optional overrides)
OPENAI_PRICE_INPUT_PER_M=0.15
OPENAI_PRICE_CACHED_INPUT_PER_M=0.075
OPENAI_PRICE_OUTPUT_PER_M=0.60

# JD Enhancement Features (coming soon)
ENABLE_AI_ENHANCERS=true
AI_SUMMARY_MODEL=gpt-4o-mini
AI_SUMMARY_TEMP=0.4
AI_SKILLS_MODEL=gpt-4o-mini
AI_SKILLS_TEMP=0.2
```

## Files Changed

### Created (10 files)
1. `db/migrate/20251023131452_create_ai_usages.rb`
2. `app/models/ai_usage.rb`
3. `config/initializers/ai_costing.rb`
4. `app/services/ai_cost/recorder.rb`
5. `app/services/ai_cost/stats.rb`
6. `app/controllers/ai/usages_controller.rb`
7. `app/views/ai/usages/index.html.erb`
8. `app/services/jd/summarizer.rb`
9. `app/services/jd/skill_extractor.rb`
10. `app/controllers/ai/jobs_controller.rb`

### Modified (6 files)
1. `app/models/job_posting.rb` - Added associations and helper methods
2. `app/views/jobs/index.html.erb` - Updated button logic
3. `app/services/job_wizard/writers/open_ai_writer.rb` - Added cost tracking
4. `app/services/job_wizard/resume_builder.rb` - Added metadata passing
5. `app/controllers/dashboard_controller.rb` - Added AI stats
6. `app/views/dashboard/show.html.erb` - Added cost display
7. `config/routes.rb` - Added AI routes

## Testing Status

- ✅ Model tests pass (8/8)
- ✅ Cost tracking working
- ✅ Dashboard integration working
- ⏳ AI writer tests need update for new signatures
- ⏳ No tests for new services yet

## Next Steps

To complete implementation:

1. **JD UI Integration** (high priority)
   - Add "Summarize JD" button to job show page
   - Add "Analyze Skills" button
   - Display results in modal or inline
   - Wire up controllers

2. **Safe Experience Writer** (low priority)
   - Implement truth-safe YAML updater
   - Add approval workflow
   - Prevent unauthorized skill additions

3. **Tests** (medium priority)
   - Add service specs for Summarizer
   - Add service specs for SkillExtractor
   - Add integration tests for cost tracking
   - Update OpenAI writer tests

4. **Documentation** (low priority)
   - Update README with new features
   - Document cost tracking
   - Document JD enhancement features

## How to Use

### Basic Cost Tracking
```bash
# Set API key
export OPENAI_API_KEY=sk-your-key-here

# Run migrations
rails db:migrate

# Start server
rails s

# Generate some content
# Visit dashboard - see cost
# Visit /ai/usages - see details
```

### Cost Per Application
Typical cost with gpt-4o-mini:
- Cover letter: ~$0.001
- Resume: ~$0.001
- Total per application: ~$0.002

### Month-to-Date Tracking
- Automatically resets first of each month
- View historical data via `/ai/usages?month=YYYY-MM`
- Costs persist even if API key removed

## Architecture Notes

### Cost Calculation
```ruby
cost_cents = (prompt_tokens / 1M * input_price) + 
             (completion_tokens / 1M * output_price) +
             (cached_tokens / 1M * cached_price)
```

### Token Tracking
- `prompt_tokens` - Input tokens
- `completion_tokens` - Output tokens
- `cached_input_tokens` - Cached input (often 0)

### Fallback Behavior
- If AI disabled: Uses heuristic summarization
- If API fails: Logs error but doesn't crash
- If usage missing: Creates record with zeros

### Truth-Only Contract
- Summarizer: Only extracts explicitly stated info
- SkillExtractor: Cross-references with experience.yml
- Never invents or infers unstated skills

