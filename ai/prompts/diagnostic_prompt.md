# 🧠 AI Diagnostic Recovery Prompt (for Cursor or Claude)

Use this anytime the AI repeats fixes or gets stuck in a bug loop.

---

## ⛔️ Diagnostic Mode — Stop and Think

**Stop editing code.**

We have a recurring bug or incomplete fix.
Before attempting another patch, switch to **diagnostic-only mode**.

Perform the following steps:

### 1. Trace the data flow
Identify where the problematic value or behavior enters the codebase.  
Show the full call path: `source → model → controller → view → output`.

**Example:**
```
API Response (Greenhouse/Lever)
  ↓
Fetcher (normalize_jobs → extract_description)
  ↓
Database (job_postings.description column)
  ↓
Model (JobPosting)
  ↓
Controller (JobsController#show)
  ↓
View (jobs/show.html.erb)
  ↓
Browser Output
```

### 2. Prove contamination point
Show 1–2 lines of code or console output proving *where* the bad value appears.

**Example:**
```ruby
# In rails console:
job = JobPosting.find(1526)
job.description[0..100]
# => "&lt;div class=&quot;content-intro&quot;&gt;&lt;p&gt;..."
# ❌ HTML entities are already in the database
```

### 3. Classify the failure
Choose one:
- **Logic bug** (bad branch or nil)
- **Data contamination** (HTML, encoding, etc.)
- **Lifecycle error** (wrong callback order)
- **Config/environment mismatch**
- **Test vs production inconsistency**

### 4. Propose exactly ONE fix location
Choose the single best place to fix it (e.g., Fetcher, Model callback, View helper).  
Explain *why* this is the correct layer for the fix.

**Example:**
```
Fix location: app/services/job_wizard/fetchers/greenhouse.rb (line 45-49)
Method: extract_description

Why:
1. Clean data at ingestion (single source of truth)
2. Database stores clean data (easier to debug/query)
3. Fix once during fetch (rare), not every render (frequent)
4. All downstream consumers get clean data automatically
5. Resume/cover letter builders benefit without separate fixes
```

### 5. Do not apply changes yet
Wait for human confirmation before showing diffs.

---

## ✅ Once Approved

After approval, apply the fix *only* in the file and method identified above.  
Show diffs and add a minimal test proving the bug no longer occurs.

**Post-fix verification:**
1. Re-fetch a job posting from the external API
2. Verify the database contains clean text (no HTML entities)
3. Verify the view renders clean text
4. Optionally: Add a spec testing the cleaning logic

---

## 🧪 Example Use

> "Stop editing. We're seeing job descriptions render with HTML tags.  
> Diagnose which layer introduces the HTML. Trace from Fetchers to View.  
> Then propose one permanent fix location, no edits yet."

---

## 💬 Quick Use Command

You can quickly trigger this prompt inside Cursor by typing:

```
/diagnose [brief description of the bug]
```

Or simply paste this into your Cursor chat:

```
Stop editing code. Switch to diagnostic mode.
Trace the data flow for [ISSUE], prove where the bad data appears,
classify the bug type, and propose ONE fix location.
Do not apply changes yet.
```

---

## 🧰 Recommended Shell Alias

If you maintain a shell function or Justfile for AI actions, add this alias:

```bash
# ~/.zshrc or ~/.bashrc
ai_diagnose() {
  cat ai/prompts/diagnostic_prompt.md
}
```

Then run:
```bash
$ ai_diagnose
```

---

## 📚 When to Use This

Use diagnostic mode when you notice:
- ✅ The same fix is attempted 3+ times
- ✅ Multiple layers are being modified without clear improvement
- ✅ The AI says "now it should work" but the bug persists
- ✅ You're unsure which layer is causing the issue
- ✅ Previous attempts modified the wrong part of the codebase

**Don't use for:**
- ❌ Simple syntax errors (just fix them)
- ❌ Clear, well-understood bugs with obvious fixes
- ❌ New features (use regular prompts)

---

## 🎯 Success Criteria

A good diagnostic response includes:
1. ✅ Complete data flow diagram
2. ✅ Console/log output proving contamination point
3. ✅ Bug classification
4. ✅ Single fix location with justification
5. ✅ No code changes (yet)

If the AI starts showing diffs immediately, remind it:
> "Stop. Diagnostic mode means no code changes. Just analyze and propose."

---

## 📝 Template for AI Response

```
## Diagnostic Analysis

### Data Flow
[Show path from source to output]

### Contamination Point
[Show proof with code/console output]

### Bug Classification
[Pick one: Logic / Data / Lifecycle / Config / Test inconsistency]

### Recommended Fix Location
File: [exact file path]
Method: [exact method name]
Line: [line number range]

Justification:
1. [Reason 1]
2. [Reason 2]
3. [Reason 3]

### Waiting for approval before applying changes.
```

---

## 🔄 After Fix is Applied

Create a smoke test to prevent regression:

```bash
# Example smoke test
rails runner "
  job = JobPosting.last
  if job.description.include?('&lt;') || job.description.include?('&gt;')
    puts '❌ HTML entities still present'
    exit 1
  else
    puts '✅ Clean text confirmed'
  end
"
```

---

## 📖 Related Documentation

- [AI Workflow Guide](../workflow.md)
- [Testing Strategy](../../spec/README.md)
- [Data Flow Architecture](../architecture/data_flow.md)

---

**Last Updated:** 2025-10-21  
**Maintainer:** Development Team





