# Task 03: Entities CRUD LiveView

## Status
- **Status**: ⏳ PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 05

## Assigned Agent
`dev-frontend-ui-engineer` - Implements LiveView UI, navigation, and interaction flows.

## Agent Invocation
Use `llms/agents/dev_frontend_ui_engineer.md` (`name: dev-frontend-ui-engineer`) to implement the Entities LiveView CRUD flow aligned to the domain model.

## Objective
Deliver list/new/edit/archive UI for entities within authenticated app shell, using canonical fields and archive semantics.

## Inputs Required
- [ ] `llms/tasks/010_entity_model/plan.md`
- [ ] `llms/tasks/010_entity_model/01_domain_data_model_foundation.md`
- [ ] `lib/aurum_finance_web/router.ex`
- [ ] `lib/aurum_finance_web/components/layouts.ex`
- [ ] Existing LiveViews in `lib/aurum_finance_web/live/`
- [ ] `llms/project_context.md`

## Expected Outputs
- [ ] `EntitiesLive` module(s) for list/new/edit/archive
- [ ] Route registration and app navigation entry
- [ ] List behavior: active entities by default + explicit toggle/control to include archived entities
- [ ] Forms using `to_form/2`, `<.form for={@form}>`, `<.input field={@form[:...]} ...>`
- [ ] Archive action (no delete action)
- [ ] Stable DOM IDs for key elements

## Acceptance Criteria
- [ ] List/new/edit/archive flows work end-to-end against context APIs
- [ ] Default list shows active entities only
- [ ] UI provides explicit toggle/control to include archived entities
- [ ] UI shows archived-state semantics clearly
- [ ] No hard-delete affordance in UI
- [ ] Template/style follows Phoenix 1.8 + AGENTS guidelines
- [ ] `mix compile` succeeds

## Technical Notes
### Relevant Code Locations
`lib/aurum_finance_web/router.ex`  
`lib/aurum_finance_web/components/layouts.ex`  
`lib/aurum_finance_web/live/`

### Patterns to Follow
- Start templates with `<Layouts.app flash={@flash} ...>` and pass `current_scope`.
- Use `<.icon>` component and `<.input>` from core components.
- Keep IDs predictable for LiveView tests.

### Constraints
- No inline scripts in templates.
- Do not call `<.flash_group>` outside layouts module.

## Execution Instructions
### For the Agent
1. Add route and navigation wiring.
2. Implement EntitiesLive with list/new/edit/archive behavior.
3. Keep forms and IDs test-friendly.
4. Document assumptions and blockers.

### For the Human Reviewer
1. Verify AC coverage in UI behavior.
2. Confirm no delete path exists.
3. Approve before Task 05 test authoring proceeds.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- 

### Outputs Created
- 

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
|  |  |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
|  |  |  |

### Blockers Encountered
- 

### Questions for Human
1. 

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
- [ ] ✅ APPROVED - Proceed to next task
- [ ] ❌ REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# human only
```
