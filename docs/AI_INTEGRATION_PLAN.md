# AI Integration Plan: Document Parsing with Google Gemini

> **Version 1.0** — December 2024

---

## 1. Overview

This document outlines the plan to integrate AI-powered document parsing into InvTrack, enabling users to upload Excel, CSV, or investment documents and have the AI automatically extract and infer investment cash flow data.

### Goals
- Allow users to upload documents (CSV, Excel, PDF, images)
- AI extracts and infers investment data (dates, amounts, types)
- User reviews and confirms extracted data before saving
- Maintain simplicity while ensuring accuracy

---

## 2. Recommended Approach: Firebase AI Logic

### Why Firebase AI Logic?

| Factor | Firebase AI Logic | Direct Gemini API |
|--------|-------------------|-------------------|
| **Security** | API key stays on server, App Check protection | API key in app (risky) |
| **Flutter Support** | Official `firebase_ai` package | Legacy `google_generative_ai` (deprecated) |
| **Integration** | Works with existing Firebase setup | Separate setup required |
| **Maintenance** | Actively maintained by Google | Not actively maintained for Flutter |
| **Cost** | Free tier available via Gemini Developer API | Same |

**Recommendation**: Use **Firebase AI Logic** with the `firebase_ai` package.

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER FLOW                                │
├─────────────────────────────────────────────────────────────────┤
│  1. User taps "Import Document"                                  │
│  2. User selects file (CSV, Excel, PDF, or image)               │
│  3. App uploads file to Firebase Storage (temporary)            │
│  4. App sends file reference + prompt to Gemini via Firebase AI │
│  5. Gemini extracts structured data (JSON)                      │
│  6. App displays extracted cash flows for user review           │
│  7. User confirms/edits each entry                              │
│  8. Confirmed entries saved to Firestore                        │
│  9. Temporary file deleted from Storage                         │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow Diagram

```
┌──────────┐    ┌─────────────┐    ┌──────────────────┐
│  User    │───▶│  Flutter    │───▶│ Firebase Storage │
│  Device  │    │    App      │    │   (temp files)   │
└──────────┘    └──────┬──────┘    └────────┬─────────┘
                       │                     │
                       ▼                     ▼
               ┌───────────────┐    ┌───────────────────┐
               │ Firebase AI   │───▶│  Gemini Model     │
               │ Logic (Proxy) │    │  (multimodal)     │
               └───────┬───────┘    └───────────────────┘
                       │
                       ▼
               ┌───────────────┐
               │  Firestore    │
               │  (save data)  │
               └───────────────┘
```

---

## 4. Implementation Phases

### Phase 1: Setup ✅ COMPLETED
- [x] Enable Firebase AI Logic in Firebase Console
- [x] Add `firebase_ai` package to pubspec.yaml
- [x] Configure Gemini API provider (Developer API for free tier)
- [ ] Set up Firebase App Check for security (optional enhancement)

### Phase 2: File Upload ✅ COMPLETED
- [x] Create document picker UI (file_picker package)
- [x] Support file types: CSV, XLSX, PDF, JPG/PNG
- [x] Upload files to Firebase Storage (temporary bucket)
- [x] Implement file size limits (max 10MB)

### Phase 3: AI Extraction ✅ COMPLETED
- [x] Create Gemini prompt for investment data extraction
- [x] Implement structured output (JSON schema)
- [x] Handle multimodal input (text for CSV, vision for PDF/images)
- [x] Parse Gemini response into CashFlow entities

### Phase 4: User Verification ✅ COMPLETED
- [x] Create review UI showing extracted cash flows
- [x] Allow user to edit/correct each entry (toggle selection)
- [x] Implement confidence indicators
- [x] Add "Accept All" and "Accept Selected" actions

### Phase 5: Save & Cleanup ✅ COMPLETED
- [x] Save confirmed cash flows to Firestore
- [x] Delete temporary files from Storage
- [x] Add success/error feedback
- [ ] Implement retry logic for failures (optional enhancement)

---

## 5. Gemini Prompt Strategy

### Structured Output Schema

```json
{
  "type": "object",
  "properties": {
    "investment_name": { "type": "string" },
    "cash_flows": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "date": { "type": "string", "format": "date" },
          "amount": { "type": "number" },
          "type": { "type": "string", "enum": ["INVEST", "RETURN", "INCOME", "FEE"] },
          "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
          "notes": { "type": "string" }
        },
        "required": ["date", "amount", "type", "confidence"]
      }
    }
  }
}
```

### Sample Prompt Template

```
You are an investment data extraction assistant. Analyze the provided document 
and extract all investment-related cash flows.

For each transaction, determine:
1. DATE: The transaction date (format: YYYY-MM-DD)
2. AMOUNT: The monetary value (positive number)
3. TYPE: One of:
   - INVEST: Money invested (purchases, deposits, SIPs)
   - RETURN: Money returned (sales, redemptions, withdrawals)
   - INCOME: Dividends, interest, or other income
   - FEE: Fees, charges, or expenses
4. CONFIDENCE: Your confidence in this extraction (0.0 to 1.0)
5. NOTES: Any relevant notes about the transaction

Return the data as JSON matching the provided schema.
If you cannot determine a field with confidence, set confidence to 0.5 or lower.
```

---

## 6. Security Considerations

| Concern | Mitigation |
|---------|------------|
| API Key Exposure | Firebase AI Logic keeps keys server-side |
| Unauthorized Access | Firebase App Check validates requests |
| Data Privacy | Files deleted after processing |
| Rate Limiting | Firebase AI Logic has built-in per-user limits |
| Cost Control | Use Gemini Flash (cheaper) for extraction |

---

## 7. Cost Estimation

### Gemini API Pricing (as of Dec 2024)

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| Gemini 1.5 Flash | $0.075 | $0.30 |
| Gemini 1.5 Pro | $1.25 | $5.00 |

**Recommendation**: Use **Gemini 1.5 Flash** for document extraction (cost-effective).

### Estimated Usage
- Average document: ~5,000 tokens input, ~500 tokens output
- Cost per document: ~$0.0004 (Flash)
- Free tier: 15 RPM, 1M tokens/day

---

## 8. Dependencies

```yaml
dependencies:
  firebase_ai: ^3.6.1          # Firebase AI Logic SDK (Gemini 2.0)
  file_picker: ^10.3.7         # Document selection
  firebase_storage: ^13.0.5    # Temporary file storage
```

**Note**: Excel and CSV parsing packages are not needed as Gemini handles document parsing directly.

---

## 9. Success Metrics

| Metric | Target |
|--------|--------|
| Extraction Accuracy | >90% for structured documents |
| User Confirmation Rate | >80% accept without edits |
| Processing Time | <10 seconds per document |
| Error Rate | <5% of uploads |

---

## 10. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Poor extraction quality | Fallback to manual entry, improve prompts |
| Large file handling | Chunk processing, file size limits |
| API rate limits | Queue requests, show progress |
| Unsupported formats | Clear error messages, format guidance |

---

## 11. Future Enhancements

- **Batch Import**: Process multiple documents at once
- **Template Learning**: Remember user's document formats
- **Auto-categorization**: Suggest investment types based on patterns
- **Receipt Scanning**: Camera capture for physical documents

---

*End of Document*

