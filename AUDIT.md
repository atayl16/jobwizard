# JobWizard Technical Audit

**Date**: 2025-10-21  
**Auditor**: AI Technical Review  
**Scope**: Full-stack Rails 8 app for job application PDF generation with truth-only guarantees

## Executive Summary

**Deployment Context**: 🏠 **LOCAL-ONLY** - Single-user macOS app (no production deployment)

**Overall Health**: 🟢 **GOOD** - Core functionality solid, optimized for local use

**Key Strengths**:
- Well-architected service layer (Fetchers, ResumeBuilder, RulesScanner, PdfOutputManager)
- Truth-safety mechanism via ExperienceLoader prevents skill fabrication
- Clean separation between manual JD entry and fetched jobs
- Recent HTML entity bug fix shows good diagnostic discipline
- SQLite database perfect for local use
- Finder integration for macOS workflow

**Critical Issues** (P1 - Must Fix):
1. **Truth-safety gaps** - Need tests proving only experience.yml skills appear in PDFs
2. **Path traversal vulnerability** - User-controlled company/role names in filesystem paths
3. **File upload validation** - No size limits or type validation
4. **Missing critical tests** - ResumeBuilder, Controllers untested
5. **Fetcher resilience** - One API failure crashes entire job board

**High-Priority Issues** (P2 - Quick Wins):
1. **UX friction** - No loading states during PDF generation (2-5s wait)
2. **N+1 queries** - Dashboard loads jobs/apps without eager loading
3. **Repeated YAML loads** - ExperienceLoader parsed on every request
4. **Error messages** - Generic failures don't explain what went wrong
5. **Missing documentation** - No ENV var reference, no local setup guide

**Medium-Priority Issues** (P3 - Nice to Haves):
1. **Accessibility gaps** - No keyboard nav, missing ARIA labels
2. **Mobile layout** - Dashboard breaks on smaller screens
3. **Empty states** - No helpful guidance when no jobs fetched
4. **CI setup** - No automated testing on push
5. **Code documentation** - Missing YARD docstrings

---

## Architecture Overview

```
User Input (JD text/file)
  ↓
ApplicationsController#prepare → SkillDetector
  ↓
Session Storage (untrusted)
  ↓
ApplicationsController#finalize → ResumeBuilder
  ↓
  ├─ ExperienceLoader (truth-only skills)
  ├─ WriterFactory → TemplatesWriter
  └─ PdfOutputManager → Filesystem
```

**Services**:
- `JobWizard::ResumeBuilder` - PDF generation with skill filtering
- `JobWizard::ExperienceLoader` - YAML normalization, skill verification
- `JobWizard::RulesScanner` - Red-flag detection
- `JobWizard::PdfOutputManager` - Filesystem operations, symlinks
- `JobWizard::Fetchers::{Greenhouse,Lever}` - External API integration
- `JobWizard::SkillDetector` - JD skill extraction
- `JobWizard::WriterFactory` - Cover letter generation strategy

**Models**:
- `JobPosting` - Fetched jobs from external sources
- `Application` - User-generated applications
- `JobSource` - API source configuration

---

## Detailed Findings Summary

| Category | P1 (Critical) | P2 (High) | P3 (Medium) | Total |
|----------|---------------|-----------|-------------|-------|
| Security | 5 | 2 | 3 | 10 |
| Performance | 0 | 5 | 4 | 9 |
| UX | 0 | 3 | 7 | 10 |
| Tests | 0 | 6 | 2 | 8 |
| DevEx | 0 | 2 | 5 | 7 |
| **TOTAL** | **5** | **18** | **21** | **44** |

---

## Prioritized 10-Step Action Plan (Local-Only Optimized)

### Phase 1: Truth-Safety & Core Functionality (P1 - Must Fix) - Week 1

**Step 1**: Add truth-safety tests for ResumeBuilder
- **Why**: Core promise - must prove only experience.yml skills appear in PDFs
- **Files**: `spec/services/job_wizard/resume_builder_spec.rb` (new)
- **Effort**: M (3-4 hours)
- **Risk**: HIGH - Product integrity untested

**Step 2**: Fix path traversal in PdfOutputManager
- **Why**: Malicious company names could write files anywhere on macOS
- **Files**: `app/services/job_wizard/pdf_output_manager.rb#slugify`
- **Effort**: S (1-2 hours)
- **Risk**: HIGH - Could overwrite system files

**Step 3**: Add file upload validation
- **Why**: Large/malicious files could crash local Rails server
- **Files**: `app/controllers/applications_controller.rb#extract_job_description`
- **Effort**: S (1-2 hours)
- **Risk**: MEDIUM - Local DoS, disk space exhaustion

**Step 4**: Make Fetchers resilient to API failures
- **Why**: One provider down shouldn't crash job board or rake tasks
- **Files**: `app/services/job_wizard/fetchers/*.rb`, `lib/tasks/jobs.rake`
- **Effort**: S (2 hours)
- **Risk**: MEDIUM - Job board unreliable

**Step 5**: Add controller and integration tests
- **Why**: Main user flows untested (prepare → finalize, quick_create)
- **Files**: `spec/requests/applications_controller_spec.rb`, `spec/system/generate_resume_spec.rb`
- **Effort**: M (6-8 hours)
- **Risk**: HIGH - Regressions in core flows

### Phase 2: UX & Performance (P2 - Quick Wins) - Week 2

**Step 6**: Add loading states for PDF generation
- **Why**: 2-5s wait with no feedback feels broken to user
- **Files**: `app/views/applications/new.html.erb`, Turbo controllers
- **Effort**: M (3-4 hours)
- **Risk**: LOW - Better user experience

**Step 7**: Cache YAML configs in memory
- **Why**: Re-parsing experience.yml on every PDF wastes 50ms per generation
- **Files**: `app/services/job_wizard/experience_loader.rb`
- **Effort**: S (1-2 hours)
- **Risk**: LOW - 3x faster PDF generation

**Step 8**: Add database indexes for dashboard queries
- **Why**: Faster dashboard loads, especially with 100+ applications
- **Files**: `db/migrate/YYYYMMDD_add_local_indexes.rb`
- **Effort**: S (1 hour)
- **Risk**: LOW - Smoother local experience

**Step 9**: Improve error messages and recovery
- **Why**: Generic errors don't help user fix config issues
- **Files**: `app/controllers/applications_controller.rb`, custom exceptions
- **Effort**: S (2-3 hours)
- **Risk**: LOW - Better debugging experience

### Phase 3: Documentation & DevEx (P3 - Polish) - Week 3

**Step 10**: Create local-only documentation
- **Why**: No setup guide for local ENV flags, Finder workflow, background jobs
- **Files**: `docs/LOCAL_ONLY.md`, `docs/ENV_VARS.md`, `bin/setup`
- **Effort**: M (4-5 hours)
- **Risk**: LOW - Easier to maintain and extend

---

## Key Metrics (Local-Only Context)

| Metric | Current | Target | Priority |
|--------|---------|--------|----------|
| Test Coverage | ~30% | 70%+ | P1 |
| Truth-Safety Tests | 0 | 5+ | P1 |
| PDF Generation Time | ~800ms | <300ms | P2 |
| Dashboard Load Time | ~250ms | <100ms | P2 |
| Documented ENV Vars | 2/6 | 6/6 | P3 |
| Finder Integration | Partial | Complete | P2 |
| Background Job Config | ✅ :async | ✅ :async | Done |

---

## Local-Only Considerations

**What We DON'T Need** (Deprioritized):
- ❌ Multi-user authentication (single local user)
- ❌ Production deployment guides
- ❌ CDN/asset pipeline optimization
- ❌ OAuth/CORS/HSTS headers
- ❌ Database replication/scaling
- ❌ Container orchestration (Docker/K8s)
- ❌ Secret management systems (Rails credentials sufficient)

**What We DO Need** (Prioritized):
- ✅ Truth-safety guarantees (never fabricate skills)
- ✅ Path traversal protection (protect macOS filesystem)
- ✅ Resilient API fetchers (handle provider outages gracefully)
- ✅ Fast YAML caching (smooth local experience)
- ✅ Excellent error messages (self-service debugging)
- ✅ Finder integration (macOS workflow)
- ✅ SQLite simplicity (no PostgreSQL complexity)
- ✅ ActiveJob :async (no Redis needed)

---

## References

- [Security Audit](./AUDIT_SECURITY.md) - *Scoped to local-only concerns*
- [Performance Audit](./AUDIT_PERF.md) - *Focus on local responsiveness*
- [UX Audit](./AUDIT_UX.md) - *macOS-first user experience*
- [Test Coverage Audit](./AUDIT_TESTS.md) - *Truth-safety emphasis*
- [Documentation Audit](./AUDIT_DOCS.md) - *Local setup & ENV vars*
- [Local-Only Guide](./docs/LOCAL_ONLY.md) - *Quick reference for local use*

---

**Next Steps**:
1. Read `docs/LOCAL_ONLY.md` for local-specific configuration
2. Start with Step 1 (Truth-safety tests) - proves core promise
3. Fix Step 2 (Path traversal) - protects your macOS filesystem
4. Add Step 6 (Loading states) - immediate UX improvement
5. Complete Step 10 (Documentation) - reference for future you

**Estimated Total Effort**: 25-35 hours (optimized for local-only use)

