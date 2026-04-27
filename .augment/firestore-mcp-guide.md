# Firestore Access via Firebase MCP Tools

**Reference**: https://firebase.google.com/docs/crashlytics/ai-assistance-mcp

## Overview
Firebase MCP (Model Context Protocol) provides tools to interact with Firestore databases directly from your development environment. This is useful for querying data, debugging, and analyzing user data like cashflows analytics.

---

## 1. Setup & Environment

### Get Firebase Environment Info
```tool
firebase_get_environment_firebase
```

Returns:
- Current authenticated user
- Active project
- Project directory
- Available Firebase apps

---

## 2. Querying Firestore Data

### Basic Collection Query
Use `firestore_query_collection` to search for documents in a collection:

```tool
firestore_query_collection
{
  "collection_path": "users/{userId}/cashFlows",
  "filters": [
    {
      "field": "date",
      "op": "GREATER_THAN_OR_EQUAL",
      "compare_value": {
        "string_value": "2026-01-01"
      }
    },
    {
      "field": "type",
      "op": "EQUAL",
      "compare_value": {
        "string_value": "INVEST"
      }
    }
  ],
  "order": {
    "orderBy": "date",
    "orderByDirection": "DESCENDING"
  },
  "limit": 100,
  "use_emulator": false
}
```

### Available Filter Operators
- `EQUAL`, `NOT_EQUAL`
- `LESS_THAN`, `LESS_THAN_OR_EQUAL`
- `GREATER_THAN`, `GREATER_THAN_OR_EQUAL`
- `ARRAY_CONTAINS`, `ARRAY_CONTAINS_ANY`
- `IN`, `NOT_IN`

### Compare Value Types
```json
{
  "string_value": "text",
  "integer_value": 123,
  "double_value": 123.45,
  "boolean_value": true,
  "string_array_value": ["value1", "value2"]
}
```

---

## 3. CashFlows Analytics Examples

### Get All CashFlows for a User
```tool
firestore_query_collection
{
  "collection_path": "users/{userId}/cashFlows",
  "filters": [],
  "order": {"orderBy": "date", "orderByDirection": "DESCENDING"},
  "limit": 1000
}
```

### Get Investment CashFlows Only
```tool
firestore_query_collection
{
  "collection_path": "users/{userId}/cashFlows",
  "filters": [
    {
      "field": "type",
      "op": "EQUAL",
      "compare_value": {"string_value": "INVEST"}
    }
  ],
  "limit": 500
}
```

### Get CashFlows by Date Range
```tool
firestore_query_collection
{
  "collection_path": "users/{userId}/cashFlows",
  "filters": [
    {
      "field": "date",
      "op": "GREATER_THAN_OR_EQUAL",
      "compare_value": {"string_value": "2026-01-01"}
    },
    {
      "field": "date",
      "op": "LESS_THAN",
      "compare_value": {"string_value": "2026-12-31"}
    }
  ],
  "order": {"orderBy": "date", "orderByDirection": "ASCENDING"}
}
```

---

## 4. Other Useful Firestore Collections

### Portfolio Health Snapshots

```text
users/{userId}/healthScores
```

### Investments

```text
users/{userId}/investments
```

### Goals

```text
users/{userId}/goals
```

### User Settings

```text
users/{userId}/settings
```

---

## 5. Important Notes

1. **Always use user-scoped paths**: `users/{userId}/collection`
2. **Respect privacy**: Don't log sensitive financial data
3. **Use emulator for testing**: Set `use_emulator: true` for local testing
4. **Pagination**: Use `limit` and `cursor` for large datasets
5. **Index requirements**: Complex queries may need Firestore indexes

---

## 6. Common Use Cases

### Analyze Investment Patterns
Query cashflows to understand:
- Total invested per month
- Investment frequency
- Most active investment categories
- Average investment amounts

### Debug User Issues
- Check if data exists in Firestore
- Verify data format/structure
- Identify missing fields
- Validate timestamps

### Performance Analysis
- Query health score snapshots over time
- Analyze portfolio growth trends
- Track goal progress

---

## References
- [Firebase MCP Documentation](https://firebase.google.com/docs/crashlytics/ai-assistance-mcp)
- [Firestore Query Syntax](https://firebase.google.com/docs/firestore/query-data/queries)
