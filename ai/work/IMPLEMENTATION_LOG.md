# JobWizard Implementation Log

## Completed Tasks

### A1 - Job Status Management ✅
**Files changed**: 
- `db/migrate/20251021230000_add_status_to_job_postings.rb` (new migration)
- `app/models/job_posting.rb` (added status enum, scopes, methods)
- `app/controllers/jobs_controller.rb` (added applied/exported/ignore actions)
- `config/routes.rb` (added new routes)
- `app/views/jobs/index.html.erb` (added status buttons)
- `spec/models/job_posting_spec.rb` (new tests)
- `spec/requests/jobs_spec.rb` (new tests)

**Tests added**: Model validations, controller actions, filtering behavior
**Runbook notes**: Jobs now filter to show only "suggested" status by default. After PDF generation, jobs are marked as "exported" and disappear from suggestions.

### B1 - Clickable App Title ✅
**Files changed**:
- `app/views/layouts/application.html.erb` (made title clickable, added nav links)
- `spec/system/navigation_spec.rb` (new system test)

**Tests added**: System test for title navigation
**Runbook notes**: JobWizard title now links to root path. Added Jobs, New Application, Settings nav links.

### C1 - JobSkillAssessment Model ✅
**Files changed**:
- `db/migrate/20251021231000_create_job_skill_assessments.rb` (new migration)
- `app/models/job_skill_assessment.rb` (new model)
- `app/models/job_posting.rb` (added association)
- `app/services/job_wizard/effective_skills_service.rb` (new service)
- `spec/models/job_skill_assessment_spec.rb` (new tests)
- `spec/services/job_wizard/effective_skills_service_spec.rb` (new tests)

**Tests added**: Model validations, service logic for effective skills calculation
**Runbook notes**: New model stores per-job skill assessments with Have/Don'tHave + proficiency levels.

### C2 - Skill Assessment UI ✅
**Files changed**:
- `app/controllers/job_skill_assessments_controller.rb` (new controller)
- `config/routes.rb` (added nested routes)
- `app/controllers/jobs_controller.rb` (added skill extraction logic)
- `app/views/jobs/show.html.erb` (added skill assessment table)
- `spec/requests/job_skill_assessments_spec.rb` (new tests)

**Tests added**: Controller CRUD operations
**Runbook notes**: Job show page now displays skill assessment table with Have/Don'tHave dropdowns and proficiency selectors.

### D1 - Service Integration ✅
**Files changed**:
- `app/services/job_wizard/resume_builder.rb` (integrated with EffectiveSkillsService)
- `app/controllers/jobs_controller.rb` (pass job_posting to ResumeBuilder)
- `spec/integration/skill_assessment_integration_spec.rb` (new integration test)

**Tests added**: Integration test for skill assessment + resume building
**Runbook notes**: ResumeBuilder now uses effective skills from job-specific assessments when job_posting is provided.

## NEW: Filtering & Rules System

### PATCH 1 - Rules Configuration ✅
**Files changed**:
- `config/job_wizard/rules.yml` (added filters section)
- `app/services/job_wizard/rules_loader.rb` (new service)
- `spec/services/job_wizard/rules_loader_spec.rb` (new tests)

**Tests added**: YAML loading, regex compilation, filter merging
**Runbook notes**: Extended rules.yml with non-destructive filters for company/content blocking and Ruby/Rails requirements.

### PATCH 2 - Database Overrides ✅
**Files changed**:
- `db/migrate/20251021232000_create_blocked_companies.rb` (new migration)
- `app/models/blocked_company.rb` (new model)
- `app/services/job_wizard/rules_loader.rb` (integrated DB companies)
- `spec/models/blocked_company_spec.rb` (new tests)

**Tests added**: Company matching logic, regex/exact matching, DB integration
**Runbook notes**: Added BlockedCompany model with regex support. RulesLoader now merges YAML and DB company blocklists.

### PATCH 3 - Rules Engine ✅
**Files changed**:
- `app/services/job_wizard/rules_engine.rb` (new service)
- `app/models/job_posting.rb` (added board_visible scope)
- `app/controllers/jobs_controller.rb` (updated to use board_visible)
- `app/services/job_wizard/fetchers/greenhouse.rb` (integrated rules engine)
- `spec/services/job_wizard/rules_engine_spec.rb` (new tests)

**Tests added**: Comprehensive filtering logic tests for all rule types
**Runbook notes**: Added RulesEngine with company/content/security/keyword filtering. Integrated into Greenhouse fetcher for ingestion filtering.

### PATCH 4 - UI Actions & Settings ✅
**Files changed**:
- `app/controllers/filters_controller.rb` (new controller)
- `app/controllers/settings_controller.rb` (new controller)
- `config/routes.rb` (added filter/settings routes)
- `app/views/jobs/index.html.erb` (added Block button)
- `app/views/settings/filters.html.erb` (new settings page)
- `app/views/layouts/application.html.erb` (updated Settings link)
- `spec/requests/filters_spec.rb` (new tests)

**Tests added**: Controller actions for blocking companies and settings management
**Runbook notes**: Added "Block Company" action from job rows. Created settings page for managing blocked companies and viewing YAML rules.

### PATCH 5 - HTML Sanitization ✅
**Files changed**:
- `app/services/job_wizard/html_cleaner.rb` (new service)
- `app/services/job_wizard/fetchers/greenhouse.rb` (updated to use cleaner)
- `app/services/job_wizard/fetchers/lever.rb` (updated to use cleaner)
- `spec/services/job_wizard/html_cleaner_spec.rb` (new tests)

**Tests added**: HTML cleaning edge cases, entity decoding, tag removal
**Runbook notes**: Added robust HTML sanitization service. Updated both fetchers to use cleaner for consistent text processing.

### PATCH 6 - Documentation & Polish ✅
**Files changed**:
- `README.md` (added filtering section)
- `docs/FILTERING.md` (new comprehensive documentation)
- `db/seeds.rb` (added example blocked companies)
- `ai/work/IMPLEMENTATION_LOG.md` (this file)

**Tests added**: Documentation and examples
**Runbook notes**: Added comprehensive documentation for filtering system, including configuration examples and troubleshooting guide.

## Summary
- ✅ Job status workflow (applied/exported/ignored)
- ✅ Clickable app title with navigation
- ✅ Per-job skill assessments with UI
- ✅ Truth-safe skill integration with resume building
- ✅ Comprehensive filtering system with company/content/security/keyword rules
- ✅ Database overrides for company blocking
- ✅ Settings UI for filter management
- ✅ Robust HTML sanitization
- ✅ Complete documentation and examples
- ✅ Comprehensive test coverage

## Next Steps
All approved items from the plan have been implemented. The app now has:
1. Job status management with filtering
2. Clickable navigation
3. Per-job skill assessments
4. Truth-safe resume generation using effective skills
5. Comprehensive filtering system with multiple rule types
6. Company blocking with regex support
7. Settings page for filter management
8. Robust HTML sanitization
9. Complete documentation

The implementation follows the truth-only policy: resume generation only uses verified skills from YAML + job-specific "have" skills above threshold, and excludes skills marked as "don't have". The filtering system provides defense in depth with both ingestion and display filtering.
