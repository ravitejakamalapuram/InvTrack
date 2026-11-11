Two switches in a new "Privacy" section of Settings, under Security: "Share usage data" and "Send crash reports". They reuse `SettingsToggleTile` and `SettingsSection`; no new widget.

## Rules

- Both default to on (today's behaviour). Turning one off takes effect at once and is remembered across restarts and honoured at app start.
- "Share usage data" also covers performance monitoring.
- Copy states plainly that no amounts or names are sent (money rule 7).
- No analytics event is sent about these switches themselves.
