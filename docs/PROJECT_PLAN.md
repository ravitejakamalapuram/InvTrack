# InvTracker — Project Execution Plan

> **Version 1.0** | Project Manager: [PM Name]  
> **Project Start Date:** 2025-12-09 (Monday)  
> **Target MVP Launch:** 2026-02-28 (12 weeks)  
> **Target Full Launch:** 2026-05-29 (24 weeks)

---

## Executive Summary

**InvTracker** is an offline-first mobile investment tracking application targeting retail investors who need transparency into their portfolio performance with complete data ownership. The app stores data locally (SQLite) and syncs to the user's own Google Drive/Sheets—no backend server required.

### Key Value Propositions
- 🔐 **Privacy-first**: No backend, user owns all data
- 📴 **Offline-first**: Works 100% without internet
- 📊 **Powerful Analytics**: XIRR, TWRR, CAGR, MOIC, P/L
- 📱 **Cross-platform**: iOS & Android via Flutter

### Success Criteria
| Metric | Target |
|--------|--------|
| Time-to-first-entry | < 30 seconds |
| App cold start | < 2 seconds |
| Sync success rate | > 99.5% |
| Calculation accuracy | < 0.01% variance vs Excel |
| Crash-free sessions | > 99.9% |

---

## Team Structure & Resource Allocation

### Core Team (Recommended)
| Role | Count | Allocation | Responsibilities |
|------|-------|------------|------------------|
| **Product Manager** | 1 | 50% | Roadmap, priorities, stakeholder mgmt |
| **Tech Lead / Architect** | 1 | 100% | Architecture, code reviews, critical paths |
| **Flutter Developer** | 2 | 100% | UI, core features, sync engine |
| **UI/UX Designer** | 1 | 75% | Hi-fi mocks, design system, assets |
| **QA Engineer** | 1 | 75% | Test automation, regression, device testing |
| **DevOps/Release** | 0.5 | 25% | CI/CD, app store submissions |

### Extended Team (Part-time)
| Role | Involvement |
|------|-------------|
| Security Consultant | Phases 1 & 3 review |
| Legal/Compliance | Privacy policy, ToS |
| Finance Advisor | Calculation validation |

---

## Phase Breakdown

### 🔷 PHASE 1: Foundation (Weeks 1-4)
**Goal**: Core infrastructure, authentication, local database

#### Sprint 1 (Week 1-2): Project Setup & Auth
| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P1-001 | Flutter project scaffold with folder structure | Dev 1 | 2d | P0 |
| P1-002 | Package selection & dependency setup | Dev 1 | 1d | P0 |
| P1-003 | Google Cloud Console setup (OAuth credentials) | Tech Lead | 1d | P0 |
| P1-004 | Implement Google Sign-In flow | Dev 1 | 3d | P0 |
| P1-005 | Secure token storage (Keychain/Keystore) | Dev 1 | 2d | P0 |
| P1-006 | Design system setup (colors, typography, spacing) | Designer | 3d | P0 |
| P1-007 | Create Figma component library | Designer | 5d | P1 |
| P1-008 | CI/CD pipeline setup (GitHub Actions) | Tech Lead | 2d | P1 |

**Sprint 1 Deliverables:**
- [ ] Working Google Sign-In with token persistence
- [ ] Project architecture documented
- [ ] CI/CD running on every PR

#### Sprint 2 (Week 3-4): Local Database & Core Models
| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P1-009 | SQLite/Drift setup with SQLCipher encryption | Dev 2 | 3d | P0 |
| P1-010 | Database schema implementation (all tables) | Dev 2 | 2d | P0 |
| P1-011 | Database migration system | Dev 2 | 2d | P0 |
| P1-012 | CRUD operations for Investments | Dev 1 | 2d | P0 |
| P1-013 | CRUD operations for Entries | Dev 1 | 2d | P0 |
| P1-014 | Sync queue table & operations | Dev 2 | 2d | P0 |
| P1-015 | Unit tests for database layer | QA | 3d | P0 |
| P1-016 | Hi-fi mockups: Onboarding flow | Designer | 4d | P0 |

**Sprint 2 Deliverables:**
- [ ] Encrypted local database operational
- [ ] All CRUD operations tested
- [ ] Database migration system working

---

### 🔷 PHASE 2: Core Features (Weeks 5-8)
**Goal**: Entry management, basic UI, calculations engine

#### Sprint 3 (Week 5-6): Core UI & Entry Management
| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P2-001 | Implement bottom navigation shell | Dev 1 | 1d | P0 |
| P2-002 | Home Dashboard screen (skeleton) | Dev 1 | 2d | P0 |
| P2-003 | Investment List screen | Dev 2 | 2d | P0 |
| P2-004 | Add/Edit Investment form | Dev 1 | 2d | P0 |
| P2-005 | Add Entry modal (all fields) | Dev 2 | 3d | P0 |
| P2-006 | Entry validation (amount, date, type) | Dev 2 | 2d | P0 |
| P2-007 | Investment Detail screen | Dev 1 | 3d | P0 |
| P2-008 | Ledger list with swipe-to-delete | Dev 2 | 2d | P1 |
| P2-009 | Hi-fi mockups: Dashboard & Analytics | Designer | 5d | P0 |
| P2-010 | Integration tests for entry flows | QA | 3d | P0 |

**Sprint 3 Deliverables:**
- [ ] Full investment & entry CRUD via UI
- [ ] Validation working on all inputs
- [ ] All P0 screens navigable

#### Sprint 4 (Week 7-8): Calculations Engine
| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P2-011 | XIRR calculator (Newton-Raphson) | Dev 1 | 4d | P0 |
| P2-012 | XIRR unit tests (Excel validation) | QA | 2d | P0 |
| P2-013 | CAGR calculator | Dev 2 | 1d | P0 |
| P2-014 | MOIC calculator | Dev 2 | 1d | P0 |
| P2-015 | IRR calculator | Dev 1 | 2d | P0 |
| P2-016 | Profit/Loss (realized + unrealized) | Dev 2 | 2d | P0 |
| P2-017 | TWRR calculator | Dev 1 | 3d | P1 |
| P2-018 | Calculation caching & invalidation | Dev 2 | 2d | P1 |
| P2-019 | Dashboard KPI integration | Dev 1 | 2d | P0 |
| P2-020 | Unit tests for all calculators | QA | 4d | P0 |

**Sprint 4 Deliverables:**
- [ ] All 6 financial metrics calculating correctly
- [ ] 100% unit test coverage on calculations
- [ ] KPIs displaying on dashboard

---

### 🔷 PHASE 3: Sync & Charts (Weeks 9-12) — MVP
**Goal**: Google Sheets sync, charts, conflict resolution

#### Sprint 5 (Week 9-10): Google Sheets Sync Engine
| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P3-001 | Google Drive file discovery/creation | Dev 1 | 2d | P0 |
| P3-002 | Google Sheets API wrapper | Dev 1 | 2d | P0 |
| P3-003 | Sheet schema creation (headers, _meta) | Dev 2 | 1d | P0 |
| P3-004 | Sync queue processor (FIFO) | Dev 2 | 3d | P0 |
| P3-005 | Batch append rows to Sheet | Dev 1 | 2d | P0 |
| P3-006 | Pull remote changes | Dev 2 | 2d | P0 |
| P3-007 | Conflict detection (timestamp comparison) | Dev 1 | 3d | P0 |
| P3-008 | Exponential backoff retry logic | Dev 2 | 1d | P0 |
| P3-009 | Sync status indicator (UI) | Dev 1 | 1d | P0 |
| P3-010 | Integration tests for sync | QA | 4d | P0 |

**Sprint 5 Deliverables:**
- [ ] Two-way sync operational
- [ ] Conflict detection working
- [ ] Offline queue processing on reconnect

#### Sprint 6 (Week 11-12): Charts, Analytics & MVP Polish
| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P3-011 | Chart library integration (fl_chart) | Dev 1 | 2d | P0 |
| P3-012 | Portfolio value over time chart | Dev 2 | 2d | P0 |
| P3-013 | Allocation pie chart | Dev 1 | 2d | P0 |
| P3-014 | Contributions vs Returns graph | Dev 2 | 2d | P1 |
| P3-015 | Conflict resolution UI | Dev 1 | 3d | P0 |
| P3-016 | Settings screen (basic) | Dev 2 | 2d | P0 |
| P3-017 | Manual sync trigger | Dev 2 | 1d | P0 |
| P3-018 | Empty states & onboarding prompts | Designer | 2d | P0 |
| P3-019 | Performance optimization (10k entries) | Dev 1 | 3d | P0 |
| P3-020 | End-to-end testing | QA | 5d | P0 |
| P3-021 | Bug bash & fixes | All Devs | 3d | P0 |

**🎯 MVP MILESTONE (Week 12)**
- [ ] Full offline-first functionality
- [ ] Google Sign-In + Sheets sync
- [ ] All 6 financial metrics
- [ ] 3 chart types
- [ ] Conflict resolution
- [ ] < 2s app start, < 500ms chart render

---

### 🔷 PHASE 4: Security & Polish (Weeks 13-16)
**Goal**: Security hardening, biometrics, premium hooks

#### Sprint 7-8 (Week 13-16): Security & Premium Framework
| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P4-001 | Passcode lock implementation | Dev 1 | 3d | P0 |
| P4-002 | Biometric unlock (Face ID/Touch ID) | Dev 2 | 2d | P0 |
| P4-003 | Auto-lock timer | Dev 1 | 1d | P0 |
| P4-004 | Security audit & penetration testing | Security | 5d | P0 |
| P4-005 | Token security hardening | Dev 2 | 2d | P0 |
| P4-006 | Export to CSV feature | Dev 1 | 2d | P0 |
| P4-007 | Import from CSV feature | Dev 2 | 3d | P1 |
| P4-008 | Premium feature gate framework | Dev 1 | 2d | P1 |
| P4-009 | Premium UI placeholders | Dev 2 | 2d | P1 |
| P4-010 | Privacy policy & ToS screens | Dev 1 | 1d | P0 |
| P4-011 | App store assets preparation | Designer | 3d | P0 |
| P4-012 | Accessibility audit (WCAG AA) | QA | 3d | P0 |

---

### 🔷 PHASE 5: Advanced Features (Weeks 17-20)
**Goal**: Multi-currency, benchmark, notifications

| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P5-001 | Multi-currency support | Dev 1 | 4d | P1 |
| P5-002 | Currency conversion (static rates) | Dev 2 | 2d | P1 |
| P5-003 | Benchmark index comparison | Dev 1 | 3d | P1 |
| P5-004 | Push notification framework | Dev 2 | 3d | P1 |
| P5-005 | Weekly summary notifications | Dev 1 | 2d | P1 |
| P5-006 | Milestone alerts | Dev 2 | 2d | P1 |
| P5-007 | PDF report export | Dev 1 | 4d | P2 |
| P5-008 | Investment comparison table | Dev 2 | 2d | P1 |
| P5-009 | Top movers section | Dev 1 | 2d | P1 |
| P5-010 | Dark mode implementation | Dev 2 | 2d | P1 |

---

### 🔷 PHASE 6: Launch Prep (Weeks 21-24)
**Goal**: Beta testing, bug fixes, store submission

| Task ID | Task | Owner | Est. | Priority |
|---------|------|-------|------|----------|
| P6-001 | Closed beta (TestFlight/Play Console) | PM | 5d | P0 |
| P6-002 | Beta feedback collection & triage | PM | Ongoing | P0 |
| P6-003 | Critical bug fixes | Devs | Ongoing | P0 |
| P6-004 | Performance profiling & optimization | Dev 1 | 3d | P0 |
| P6-005 | Device compatibility testing | QA | 5d | P0 |
| P6-006 | App Store submission (iOS) | DevOps | 2d | P0 |
| P6-007 | Play Store submission (Android) | DevOps | 2d | P0 |
| P6-008 | App Store review response | PM | Ongoing | P0 |
| P6-009 | Launch marketing materials | Marketing | 5d | P1 |
| P6-010 | Support documentation | PM | 3d | P1 |

**🎯 FULL LAUNCH MILESTONE (Week 24)**
- [ ] iOS App Store live
- [ ] Google Play Store live
- [ ] All Phase 1-5 features complete
- [ ] < 1% crash rate
- [ ] Support channels active

---

## Risk Assessment & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Google OAuth verification delays | High | High | Start process in Week 1, limited-user testing mode |
| XIRR calculation edge cases | Medium | High | Extensive test suite, Excel validation, fallback handling |
| Sync conflicts complexity | Medium | Medium | Clear conflict UI, auto-merge for low-priority fields |
| App Store rejection | Medium | Medium | Follow guidelines strictly, pre-submission checklist |
| Google API quota limits | Low | Medium | Batching, request optimization, caching |
| Data corruption | Low | Critical | Checksums, backup before migrations, recovery flows |
| Performance with large datasets | Medium | Medium | Early benchmarking at 10k entries, lazy loading |
| Scope creep | High | Medium | Strict sprint goals, PM as gatekeeper |

---

## Technical Decisions (Pre-approved)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | Flutter 3.x | Cross-platform, single codebase |
| State Management | Riverpod or Bloc | Scalable, testable |
| Local DB | Drift + SQLCipher | Type-safe, encrypted |
| Charts | fl_chart | Flutter-native, customizable |
| HTTP Client | dio | Interceptors, retry support |
| Secure Storage | flutter_secure_storage | Platform keychain integration |
| CI/CD | GitHub Actions | Free for public repos, matrix builds |

---

## Sprint Ceremonies

| Ceremony | Frequency | Duration | Attendees |
|----------|-----------|----------|-----------|
| Sprint Planning | Bi-weekly (Monday) | 2 hours | Full team |
| Daily Standup | Daily (async or 15min) | 15 min | Dev team |
| Sprint Review | Bi-weekly (Friday) | 1 hour | Full team + stakeholders |
| Sprint Retro | Bi-weekly (Friday) | 45 min | Full team |
| Backlog Grooming | Weekly (Wednesday) | 1 hour | PM + Tech Lead |
| Design Review | Weekly | 30 min | Designer + PM + Tech Lead |

---

## Definition of Done (DoD)

### Feature Level
- [ ] Code complete and PR merged
- [ ] Unit tests written (>80% coverage for logic)
- [ ] Integration tests passing
- [ ] Code reviewed by Tech Lead
- [ ] No P0/P1 bugs
- [ ] UI matches approved mockups
- [ ] Accessibility verified
- [ ] Documentation updated
- [ ] Works offline

### Sprint Level
- [ ] All P0 tasks complete
- [ ] Demo-ready for stakeholders
- [ ] No regression in existing features
- [ ] Performance benchmarks met

### Release Level
- [ ] All acceptance criteria met
- [ ] Security audit passed
- [ ] Device compatibility verified
- [ ] App Store guidelines compliance
- [ ] Legal review complete

---

## Key Dependencies & Blockers

### External Dependencies
| Dependency | Owner | Lead Time | Required By |
|------------|-------|-----------|-------------|
| Google Cloud Console setup | PM/Tech Lead | 1 day | Week 1 |
| OAuth consent screen verification | Google | 2-4 weeks | Week 8 (MVP sync) |
| Apple Developer Account | PM | 1-2 days | Week 20 |
| Google Play Developer Account | PM | 1-2 days | Week 20 |
| Security audit vendor | PM | 1 week | Week 13 |

### Internal Dependencies
```
P1-004 (Google Sign-In) → P3-001 (Drive discovery)
P1-009 (SQLite setup) → P1-012 (Investment CRUD)
P2-011 (XIRR) → P2-019 (Dashboard KPIs)
P3-004 (Sync queue) → P3-005 (Batch append)
P4-001 (Passcode) → P4-002 (Biometrics)
```

---

## Budget Estimation (24-Week Project)

### Team Cost (Example: US Rates)
| Role | Weekly Rate | Weeks | Total |
|------|-------------|-------|-------|
| Product Manager (50%) | $2,500 | 24 | $60,000 |
| Tech Lead | $4,000 | 24 | $96,000 |
| Flutter Dev × 2 | $3,500 × 2 | 24 | $168,000 |
| UI/UX Designer (75%) | $2,625 | 24 | $63,000 |
| QA Engineer (75%) | $2,250 | 24 | $54,000 |
| DevOps (25%) | $875 | 24 | $21,000 |
| **Team Subtotal** | | | **$462,000** |

### Additional Costs
| Item | Cost |
|------|------|
| Security Consultant (2 reviews) | $5,000 |
| Legal (Privacy Policy, ToS) | $3,000 |
| Apple Developer Account | $99/year |
| Google Play Developer Account | $25 (one-time) |
| Infrastructure (CI/CD, testing devices) | $2,000 |
| Design tools (Figma) | $720 |
| **Additional Subtotal** | **$10,844** |

### **Total Estimated Budget: ~$473,000**

*Note: Costs can be reduced with offshore team, reduced scope, or longer timeline.*

---

## Communication Plan

| Channel | Purpose | Frequency |
|---------|---------|-----------|
| Slack #invtracker-dev | Dev discussions | Real-time |
| Slack #invtracker-general | Team announcements | As needed |
| GitHub Issues | Task tracking | Real-time |
| GitHub Projects | Sprint board | Updated daily |
| Weekly Status Email | Stakeholder updates | Every Friday |
| Confluence/Notion | Documentation | Updated per sprint |
| Figma | Design collaboration | Real-time |

---

## Quality Gates

### Gate 1: End of Phase 1 (Week 4)
- [ ] Auth working end-to-end
- [ ] Local DB schema finalized
- [ ] Architecture approved

### Gate 2: End of Phase 2 (Week 8)
- [ ] All calculations accurate to 0.01%
- [ ] Core UI complete
- [ ] No P0 bugs

### Gate 3: MVP (Week 12)
- [ ] Sync working reliably
- [ ] Performance targets met
- [ ] Ready for internal testing

### Gate 4: Beta (Week 20)
- [ ] Security audit passed
- [ ] External beta feedback positive
- [ ] Store submission ready

### Gate 5: Launch (Week 24)
- [ ] Store approval received
- [ ] Launch checklist complete
- [ ] Support team briefed

---

## Immediate Next Steps (Week 0)

### Pre-Sprint Activities
1. **PM**: Finalize team composition and onboarding
2. **Tech Lead**: Set up GitHub repository and project board
3. **Tech Lead**: Create architecture decision record (ADR)
4. **PM**: Set up Google Cloud Console project
5. **Designer**: Begin design system in Figma
6. **All**: Review PRD and Tech Spec thoroughly
7. **PM**: Schedule kick-off meeting with full team
8. **PM**: Set up Slack channels and Confluence space
9. **Tech Lead**: Evaluate and finalize package dependencies
10. **QA**: Define test strategy and tools

### Kick-off Meeting Agenda
1. Project overview and vision (PM) - 15 min
2. Technical architecture walkthrough (Tech Lead) - 20 min
3. Design direction preview (Designer) - 10 min
4. Sprint 1 planning - 30 min
5. Q&A and action items - 15 min

---

## Appendix: Task Priority Guide

| Priority | Definition | SLA |
|----------|------------|-----|
| **P0** | Launch blocker, must complete | No delays allowed |
| **P1** | Important feature, high value | Can slip 1 sprint max |
| **P2** | Nice-to-have, enhances UX | Can defer to post-launch |
| **P3** | Future consideration | Backlog only |

---

## Appendix: Key Stakeholder Matrix

| Stakeholder | Interest | Influence | Engagement |
|-------------|----------|-----------|------------|
| Founder/CEO | Vision, success | High | Weekly updates |
| Users (Beta) | Usability, features | Medium | Bi-weekly feedback |
| Investors | ROI, timeline | High | Monthly reports |
| Legal/Compliance | Risk mitigation | Medium | Milestone reviews |
| App Store Reviewers | Policy compliance | High | Submission time |

---

*Document created: 2025-12-03*
*Last updated: 2025-12-03*
*Next review: Sprint 1 Kick-off*

