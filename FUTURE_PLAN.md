# Future Plan

This document tracks planned improvements and features for the InvTrack app.

## P1 - Important

### Integration Tests for Critical User Flows
Add integration tests covering:
- User sign-in/sign-out flow
- Creating an investment with initial cash flow
- Adding/editing/deleting cash flows
- Bulk import from CSV
- Investment merge functionality

### Architecture Documentation
Create ARCHITECTURE.md documenting:
- Feature-based folder structure
- Data flow patterns (Riverpod providers)
- Repository pattern implementation
- Error handling strategy

## P2 - Nice to Have

### Localization Infrastructure
- Add `flutter_localizations` dependency
- Create ARB files for strings
- Extract all hardcoded strings to localization
- Support for multiple languages

### Analytics/Event Tracking Layer
- Create analytics abstraction layer
- Track key user events (investment created, cash flow added, etc.)
- Integrate with Firebase Analytics or similar

### Firebase Performance Monitoring
- Add Firebase Performance SDK
- Track screen load times
- Monitor network request performance
- Custom traces for critical operations

### Structured Logging
- Replace `debugPrint` with proper logging framework
- Add log levels (debug, info, warning, error)
- Configure different outputs for debug/release
- Consider integration with crash reporting

---
*Last updated: 2025-12-23*

