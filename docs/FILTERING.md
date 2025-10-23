# JobWizard Filtering Documentation

## Overview

JobWizard includes a comprehensive filtering system that automatically rejects unwanted job postings at ingestion time and provides defense-in-depth filtering at display time.

## Filter Types

### 1. Company Blocking

**YAML Configuration** (`config/job_wizard/rules.yml`):
```yaml
filters:
  company_blocklist:
    - "SpamRecruiter"           # Exact match
    - "/^CyberCoders$/i"        # Regex pattern
```

**Database Overrides**:
- Add companies via Settings page (`/settings/filters`)
- Block companies directly from job board (click "Block" button)
- Supports both exact matching and regex patterns

### 2. Content Blocking

Automatically rejects jobs containing:
- NSFW content
- Adult entertainment
- Gambling/casino content
- Crypto casino content

### 3. Security Clearance Filtering

**Rejects jobs requiring:**
- Active security clearance
- Secret clearance
- TS/SCI clearance
- DoD clearance

**Allows jobs mentioning:**
- Background checks
- Background screening

### 4. Technology Focus

**Required Keywords** (at least one must be present):
- "ruby"
- "rails"

**Excluded Keywords** (any presence causes rejection):
- "php"
- "dotnet"
- ".net"
- "golang"
- "cobol"

**Exception**: Manually added jobs bypass keyword requirements.

## Implementation Details

### Rules Engine

The `JobWizard::RulesEngine` service applies all filtering rules:

```ruby
engine = JobWizard::RulesEngine.new
rejected, reasons = engine.should_reject?(job_posting)
```

### Defense in Depth

1. **Ingestion Filtering**: Jobs are filtered when fetched from APIs
2. **Display Filtering**: Jobs are filtered again when displayed (using `board_visible` scope)

### Regex Patterns

Company blocklist supports regex patterns:
- Format: `/pattern/flags`
- Example: `/^CyberCoders$/i` (case-insensitive exact match)
- Invalid regex patterns fall back to case-insensitive string matching

### Logging

Rejected jobs are logged with reasons:
```ruby
engine.recent_rejections(10) # Returns last 10 rejections with reasons
```

## Configuration Examples

### Block Spam Recruiters
```yaml
filters:
  company_blocklist:
    - "CyberCoders"
    - "Robert Half"
    - "/.*recruiter.*/i"
```

### Stricter Technology Requirements
```yaml
filters:
  required_keywords:
    - "ruby"
    - "rails"
    - "postgresql"
  excluded_keywords:
    - "php"
    - "dotnet"
    - "java"
    - "python"
```

### Allow Background Checks
```yaml
filters:
  require_no_security_clearance: true
  allow_background_checks: true
  allowed_phrases:
    - "background check"
    - "background screening"
  excluded_phrases:
    - "active security clearance"
    - "secret clearance"
```

## Troubleshooting

### Jobs Not Appearing

1. Check if company is blocked: `BlockedCompany.matches_company?("CompanyName")`
2. Check recent rejections: `JobWizard::RulesEngine.new.recent_rejections`
3. Verify keyword requirements are met
4. Check for excluded keywords

### Debug Mode

Add `?debug_filters=1` to job board URL to see filtering information (if implemented).

### Manual Override

Jobs can be manually added with `source: 'manual'` to bypass keyword requirements.


