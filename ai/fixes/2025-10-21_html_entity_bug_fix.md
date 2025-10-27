# HTML Entity Bug Fix - 2025-10-21

## Problem
Job descriptions fetched from external APIs (Greenhouse, Lever) were displaying HTML entities and tags as raw text in the UI:
- `&lt;div&gt;` instead of being stripped
- `&quot;` instead of `"`
- `&#39;` instead of `'`
- `&amp;` instead of `&`

## Root Cause Analysis

### Data Flow Trace
```
External API (Greenhouse/Lever)
  ↓ Returns HTML-encoded content
Fetcher (normalize_jobs → extract_description)
  ↓ Stored as-is (no cleaning)
Database (job_postings.description)
  ↓ Contains: "&lt;div&gt;&lt;p&gt;Text&lt;/p&gt;&lt;/div&gt;"
Model (JobPosting)
  ↓ Returns database value unchanged
Controller (JobsController#show)
  ↓ Passes to view
View (jobs/show.html.erb)
  ↓ Renders with sanitize/strip_tags
Browser
  ↓ Displays: "<div><p>Text</p></div>" as literal text
```

### Contamination Point
Database verification showed HTML entities were already present:
```ruby
job = JobPosting.find(1526)
job.description[0..100]
# => "&lt;div class=&quot;content-intro&quot;&gt;&lt;p&gt;..."
```

### Bug Classification
**Data contamination** - HTML entities were stored in the database during fetch, making all downstream rendering incorrect.

## Solution

### Fix Location
**Fetcher layer** - `app/services/job_wizard/fetchers/greenhouse.rb` and `lever.rb`

**Why this is the correct layer:**
1. ✅ Clean data at ingestion (single source of truth)
2. ✅ Database stores clean, readable text (easier to debug/query)
3. ✅ Fix once during fetch (rare), not every render (frequent)
4. ✅ All downstream consumers get clean data automatically
5. ✅ Resume/cover letter PDF builders benefit without separate fixes

### Implementation

**Greenhouse Fetcher** (`app/services/job_wizard/fetchers/greenhouse.rb`):
```ruby
def extract_description(job)
  content = job['content'] || ''
  raw_html = [content].flatten.join("\n\n").strip
  
  # Step 1: Decode HTML entities (e.g., &lt; becomes <, &quot; becomes ")
  decoded = CGI.unescapeHTML(raw_html)
  
  # Step 2: Strip all HTML tags to get clean text
  clean = ActionView::Base.full_sanitizer.sanitize(decoded)
  
  # Step 3: Decode any remaining HTML entities (e.g., &amp; becomes &)
  CGI.unescapeHTML(clean).strip
end
```

**Lever Fetcher** (`app/services/job_wizard/fetchers/lever.rb`):
```ruby
def extract_description(job)
  description = job['description'] || job['descriptionPlain'] || ''
  additional = job['additional'] || job['additionalPlain'] || ''
  raw_html = [description, additional].reject(&:blank?).join("\n\n")
  
  # Step 1: Decode HTML entities
  decoded = CGI.unescapeHTML(raw_html)
  
  # Step 2: Strip all HTML tags
  clean = ActionView::Base.full_sanitizer.sanitize(decoded)
  
  # Step 3: Decode remaining entities
  CGI.unescapeHTML(clean).strip
end
```

**View Simplification** (`app/views/jobs/show.html.erb`):
```erb
<%= simple_format(@job.description, {}, wrapper_tag: "div") %>
```

No more need for `strip_tags` or complex sanitization - the data is already clean.

## Testing

Created smoke test: `test/smoke_test_job_description_cleaning.sh`

**Test Results:**
```
✅ HTML entities decoded and tags stripped correctly
✅ Greenhouse fetcher cleans HTML correctly
✅ Lever fetcher cleans HTML correctly
⚠️  Existing jobs have HTML entities - re-fetch to clean them
```

## Migration Path

### For Existing Data
Re-fetch jobs to update database with clean descriptions:
```bash
rake 'jobs:fetch[greenhouse,instacart]'
rake 'jobs:fetch[lever,netflix]'
```

### For New Jobs
All newly fetched jobs will automatically have clean descriptions.

## Verification

1. **Run smoke test:**
   ```bash
   ./test/smoke_test_job_description_cleaning.sh
   ```

2. **Verify in browser:**
   - Visit `http://localhost:3000/jobs/[any-job-id]`
   - Job description should display clean, readable text
   - No HTML tags or entities visible

3. **Verify in database:**
   ```ruby
   job = JobPosting.last
   puts job.description[0..200]
   # Should show clean text, no &lt; or &gt;
   ```

## Prevention

### Diagnostic Prompt Created
To prevent similar bug loops in the future, created:
- `ai/prompts/diagnostic_prompt.md` - Systematic root-cause analysis guide
- Updated `ai/plan.md` with link to diagnostic tools

**When to use:**
- Same fix attempted 3+ times without success
- Multiple layers modified without clear improvement
- Unclear which layer is causing the issue

**How to use:**
1. Stop editing code
2. Trace data flow from source to output
3. Prove contamination point with console output
4. Classify bug type (logic/data/lifecycle/config)
5. Propose single fix location with justification
6. Wait for approval before applying changes

## Lessons Learned

1. **Always trace data flow first** - Don't assume the problem is where symptoms appear
2. **Fix at the source** - Clean data at ingestion, not at every render
3. **Verify with database queries** - Check what's actually stored, not just what's displayed
4. **Create smoke tests** - Prevent regression and verify fix works end-to-end
5. **Document for AI** - Create diagnostic tools to avoid repeating the same debugging process

## Files Modified

- `app/services/job_wizard/fetchers/greenhouse.rb` - Added HTML cleaning logic
- `app/services/job_wizard/fetchers/lever.rb` - Added HTML cleaning logic
- `app/views/jobs/show.html.erb` - Simplified view (removed redundant cleaning)
- `test/smoke_test_job_description_cleaning.sh` - Created verification test
- `ai/prompts/diagnostic_prompt.md` - Created diagnostic guide
- `ai/plan.md` - Added reference to diagnostic tools
- `ai/fixes/2025-10-21_html_entity_bug_fix.md` - This document

## Status
✅ **RESOLVED** - All tests passing, fix applied to fetchers, diagnostic tools created for future prevention.





