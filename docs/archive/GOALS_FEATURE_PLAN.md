# Goals Feature - Complete Implementation Plan

> **Version**: 1.0 | **Created**: 2025-12-26
> **Vision**: "The GPS for Your Financial Journey"

---

## Executive Summary

Goals feature enables users to set financial targets and track progress using their real investment data. Unlike generic goal trackers, InvTracker goals are **linked to actual investments** with automatic progress calculation from cash flows.

---

## 1. Feature Scope

### 1.1 Goal Types

| Type | Description | Progress Calculation |
|------|-------------|---------------------|
| **Target Amount** | Accumulate a specific amount | Sum of net inflows in linked investments |
| **Target Date + Amount** | Reach amount by deadline | Same + timeline projection |
| **Income Target** | Monthly passive income goal | Average monthly income from linked investments |

### 1.2 Tracking Modes

| Mode | Description |
|------|-------------|
| `all` | Track all user's investments |
| `byType` | Track all investments of specific types (e.g., all P2P) |
| `selected` | Track only manually selected investments |

---

## 2. Data Model

### 2.1 Goal Entity

```dart
class GoalEntity {
  String id;
  String name;
  GoalType type;           // targetAmount, targetDate, incomeTarget
  double targetAmount;      // Target corpus (for amount goals)
  double? targetMonthlyIncome; // For income goals
  DateTime? targetDate;     // Optional deadline
  GoalTrackingMode trackingMode; // all, byType, selected
  List<String> linkedInvestmentIds; // For 'selected' mode
  List<InvestmentType> linkedTypes; // For 'byType' mode
  String icon;              // Emoji icon
  int colorValue;           // Color as int
  bool isArchived;
  DateTime createdAt;
  DateTime updatedAt;
}
```

### 2.2 Goal Progress (Calculated)

```dart
class GoalProgress {
  double currentAmount;     // Current value toward goal
  double targetAmount;      // Target value
  double progressPercent;   // 0-100
  double monthlyVelocity;   // Average monthly contribution
  DateTime? projectedDate;  // Estimated completion
  int daysRemaining;        // If target date set
  GoalStatus status;        // onTrack, ahead, behind, achieved
  List<GoalMilestone> milestones; // 25%, 50%, 75%, 90%, 100%
}
```

---

## 3. Architecture

### 3.1 Folder Structure

```
lib/features/goals/
├── data/
│   ├── models/
│   │   └── goal_model.dart
│   └── repositories/
│       └── goal_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── goal_entity.dart
│   │   └── goal_progress.dart
│   └── repositories/
│       └── goal_repository.dart
└── presentation/
    ├── providers/
    │   ├── goals_provider.dart
    │   └── goal_progress_provider.dart
    ├── screens/
    │   ├── goals_screen.dart
    │   ├── goal_detail_screen.dart
    │   └── create_goal_screen.dart
    └── widgets/
        ├── goal_card.dart
        ├── goal_progress_ring.dart
        ├── goal_milestone_indicator.dart
        └── investment_selector.dart
```

### 3.2 Firestore Structure

```
users/{userId}/goals/{goalId}
  - name: string
  - type: string (targetAmount|targetDate|incomeTarget)
  - targetAmount: number
  - targetMonthlyIncome: number?
  - targetDate: timestamp?
  - trackingMode: string (all|byType|selected)
  - linkedInvestmentIds: string[]
  - linkedTypes: string[]
  - icon: string
  - colorValue: number
  - isArchived: boolean
  - createdAt: timestamp
  - updatedAt: timestamp
```

---

## 4. Implementation Phases

### Phase 1: Core Infrastructure (Day 1-2) ✅ COMPLETE
- [x] Goal entity & enums
- [x] Goal model (Firestore serialization)
- [x] Goal repository interface
- [x] Goal repository implementation
- [x] Basic Riverpod providers

### Phase 2: Progress Calculation (Day 2-3) ✅ COMPLETE
- [x] GoalProgress entity
- [x] Progress calculation service
- [x] Milestone detection
- [x] Projection engine
- [x] Goal progress provider

### Phase 3: UI - List & Cards (Day 3-4) ✅ COMPLETE
- [x] Goals screen (list view)
- [x] Goal card widget
- [x] Progress ring widget
- [x] Empty state
- [x] Add to navigation

### Phase 4: UI - Create/Edit (Day 4-5) ✅ COMPLETE
- [x] Create goal screen
- [x] Investment selector widget
- [x] Type selector
- [x] Edit goal screen
- [x] Delete confirmation

### Phase 5: UI - Detail Screen (Day 5-6) ✅ COMPLETE
- [x] Goal detail screen
- [x] Linked investments list
- [x] Progress timeline
- [x] Milestone indicators
- [x] Actions (edit, archive, delete)

### Phase 6: Integration & Polish (Day 6-7) ✅ COMPLETE
- [x] Dashboard goal summary card
- [x] Goal notifications hooks
- [x] Analytics events
- [x] Error handling
- [x] Loading states

---

## 5. UI Specifications

See wireframes in next section of this document.

---

## 6. Notification Hooks ✅ IMPLEMENTED

| Event | Trigger | Status |
|-------|---------|--------|
| `goal_milestone_reached` | Progress crosses 25/50/75/90/100% | ✅ Implemented |
| `goal_at_risk` | Goal status is "behind" (>30 days behind projection) | ✅ Implemented (rate-limited: 1/week) |
| `goal_stale` | No linked activity for 60 days | ✅ Implemented (rate-limited: 1/month) |
| `goal_achieved` | 100% reached | ✅ Implemented (via milestone) |

---

## 7. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Goals per user | 2+ | Average goals created |
| Linking rate | 80% | % goals with linked investments |
| Weekly engagement | 40% | Users viewing goals weekly |
| Completion rate | 30% | Goals reaching 100% |

---

## 8. Premium Gating

> **Note**: As of v1.0, all goal features are FREE with no premium gating.

| Feature | Status |
|---------|--------|
| Number of goals | ✅ Unlimited |
| Projections | ✅ Free |
| Milestone notifications | ✅ Free |
| Income goals | ✅ Free |
| At-risk alerts | ✅ Free |
| Stale reminders | ✅ Free |

---

## 9. Implementation Status

**Feature Status: ✅ COMPLETE**

All phases have been implemented:
- Core infrastructure with Firestore persistence
- Progress calculation with projections
- Full UI (list, create, edit, detail screens)
- Dashboard integration
- All notification types (milestones, at-risk, stale)
- Analytics events
