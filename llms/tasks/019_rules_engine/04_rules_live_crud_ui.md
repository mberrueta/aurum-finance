# Task 04: RulesLive CRUD UI (Condition Builder + Action Builder)

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 08, Task 11, Task 12

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Rewrite `AurumFinanceWeb.RulesLive` and `AurumFinanceWeb.RulesComponents` to use real data from the `Classification` context. Implement CRUD forms for rule groups and rules, including the unified scope selector for `global` / `entity` / `account`, the structured condition builder (create flow), the raw expression editor (edit flow), and the action builder UI.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (US-1 through US-8, UX States, Edge Cases)
- [ ] `llms/tasks/019_rules_engine/02_classification_context_crud.md` - Context API
- [ ] `llms/constitution.md` - HEEx templating rules, i18n
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance_web/live/rules_live.ex` - Current mock implementation to replace
- [ ] `lib/aurum_finance_web/components/rules_components.ex` - Current components to rewrite
- [ ] `lib/aurum_finance_web/live/accounts_live.ex` - Reference LiveView pattern (entity selection, CRUD forms)
- [ ] `lib/aurum_finance_web/components/slideover_components.ex` - Slideover/modal pattern
- [ ] `lib/aurum_finance_web/components/ui_components.ex` - Shared UI components
- [ ] `lib/aurum_finance_web/components/core_components.ex` - Core components (forms, inputs)
- [ ] `lib/aurum_finance/classification.ex` - Context API (from Task 02)

## Expected Outputs

- [ ] Rewritten: `lib/aurum_finance_web/live/rules_live.ex`
- [ ] Rewritten: `lib/aurum_finance_web/components/rules_components.ex`
- [ ] New HEEx template (if LiveView uses separate template): `lib/aurum_finance_web/live/rules_live.html.heex`
- [ ] Updated gettext strings in `priv/gettext/*/LC_MESSAGES/rules.po` (if applicable)

## Acceptance Criteria

- [ ] **Group list**: Shows rule groups visible in the current entity context: global groups, entity-scoped groups for the selected entity, and account-scoped groups whose accounts belong to the selected entity. Groups are ordered by scope precedence (`account`, `entity`, `global`), then `priority ASC`, then `name ASC`. Each group shows name, description, scope badge, scope target label, priority number, rule count, active/inactive badge
- [ ] **Group CRUD forms**: Create group via slideover/modal with fields: name (required, 2-160), `scope_type` (required, global/entity/account), scope target picker (entity picker when `entity`, account picker when `account`, none when `global`), priority (required, positive int), description (optional), target_fields (optional multi-select from category/tags/investment_type/notes), is_active (checkbox, default true)
- [ ] **Group edit/delete**: Edit group inline or via slideover; delete with confirmation
- [ ] **Rule list**: Within selected group, shows rules ordered by position ASC. Each rule row shows: position number, human-readable condition summary (from expression), human-readable action summary (from actions JSONB), is_active status, stop_processing indicator
- [ ] **Rule create (builder flow)**: Condition builder with dynamic rows of field (dropdown) / operator (dropdown, filtered by field type) / value (text input or date picker or account picker depending on field) / negate (checkbox). Builder compiles to expression on form submit. Action builder with rows of field (dropdown) / operation (dropdown, filtered by field) / value (text or account picker for category)
- [ ] **Rule edit (raw expression flow)**: Shows stored expression as raw text field with "Advanced mode" warning notice. Shows actions in same builder UI as create. Backend validates expression on save; invalid expressions show inline error.
- [ ] **Toggle active**: Toggle is_active for groups and rules without full form
- [ ] **Scoped visibility**: Current entity drives the page context; switching entity reloads visible global/entity/account groups for that entity
- [ ] **Empty states**: "No rule groups yet" with CTA; "No rules in this group" with CTA; per spec UX States section
- [ ] **Inactive styling**: Inactive groups/rules shown with muted/dimmed styling and "Inactive" badge
- [ ] **Category action value**: When action field is "category", value input is an account picker showing only `management_group: :category` accounts for current entity
- [ ] All text uses `dgettext("rules", "...")` for i18n
- [ ] HEEx uses `{}` interpolation and `:if`/`:for` attributes (no `<% %>` blocks)
- [ ] No `<%= %>` blocks -- use `{}` interpolation exclusively

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance_web/live/accounts_live.ex        # Reference LiveView (entity scope, CRUD)
lib/aurum_finance_web/live/reconciliation_live.ex   # Reference LiveView (selected item detail)
lib/aurum_finance_web/components/                   # Component patterns
lib/aurum_finance_web/router.ex                     # Route (already exists)
```

### Patterns to Follow
- Entity selection from `Entities.list_entities()`, current entity in assigns
- Scope selection in the group form must drive conditional entity/account pickers
- Slideover/modal for create/edit forms using existing slideover component
- `phx-change` / `phx-submit` form events
- `change_*` functions for form changeset handling
- Flash messages on success/error
- `push_patch` for URL state management

### Constraints
- Do NOT implement preview UI (that is Task 08)
- Do NOT implement bulk apply UI (that is Task 11)
- The condition builder is for CREATE only; EDIT uses raw expression text
- v1 does NOT reconstruct builder state from expression (one-directional compilation)
- The test runner section from the current mock should be removed (preview replaces it in Task 08)
- Account-scoped group creation/edit must not store redundant `entity_id`

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Study existing LiveView patterns (AccountsLive, ReconciliationLive) for entity selection and CRUD patterns
3. Remove all mock data from RulesLive
4. Implement group list + detail pane layout
5. Implement group CRUD with slideover forms and explicit scope selection
6. Implement rule list within selected group
7. Implement rule create with condition builder + action builder
8. Implement rule edit with raw expression editor + action builder
9. Implement toggle active for groups and rules
10. Handle all empty states per spec
11. Verify all HEEx follows constitution rules (no `<% %>` blocks)
12. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review UI against spec acceptance criteria and UX States
2. Test group CRUD manually in browser
3. Test rule create (builder) and edit (raw expression) flows
4. Verify empty states render correctly
5. Verify i18n usage throughout
6. If approved: mark `[x]` on "Approved" and update execution_plan.md status

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [To be filled]

### Outputs Created
- [To be filled]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

### Blockers Encountered
- [To be filled]

### Questions for Human
1. [To be filled]

### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
