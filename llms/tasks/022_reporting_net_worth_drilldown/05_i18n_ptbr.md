# Task 05: I18n - Brazilian Portuguese Translations

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 06

## Assigned Agent
`loc-i18n-ptbr-gettext-guardian` - i18n guardian for Brazilian Portuguese (pt-BR).

## Agent Invocation
Invoke the `loc-i18n-ptbr-gettext-guardian` agent with instructions to add pt-BR translations for all new drilldown i18n keys.

## Objective
Add Brazilian Portuguese translations for all new `dgettext("reports", ...)` keys introduced by the drilldown feature in Tasks 01-03.

## Inputs Required

- [ ] `llms/tasks/022_reporting_net_worth_drilldown/03_liveview_drilldown_ui.md` - List of i18n keys added
- [ ] `lib/aurum_finance_web/live/net_worth_live.ex` - Source of new dgettext calls
- [ ] `lib/aurum_finance_web/live/net_worth_live.html.heex` - Source of new dgettext calls
- [ ] Existing pt-BR Gettext PO files for the "reports" domain

## Expected Outputs

- [ ] Updated pt-BR PO file for the "reports" domain with all new drilldown keys translated
- [ ] All Gettext keys have corresponding translations

## Acceptance Criteria

- [ ] Every `dgettext("reports", ...)` key added in Tasks 01-03 has a pt-BR translation
- [ ] Translations are natural Brazilian Portuguese (not machine-translated)
- [ ] Variable interpolation placeholders match the English keys
- [ ] `mix gettext.extract --merge` runs clean

## Execution Instructions

### For the Agent
1. Read Task 03 for the list of new i18n keys
2. Scan the updated LiveView files for any additional dgettext calls
3. Run `mix gettext.extract --merge` to generate missing entries
4. Add translations to the pt-BR PO file
5. Verify with `mix compile`

### For the Human Reviewer
After agent completes:
1. Review translations for accuracy and natural language quality
2. If approved: mark `[x]` on "Approved" and update plan.md status

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
