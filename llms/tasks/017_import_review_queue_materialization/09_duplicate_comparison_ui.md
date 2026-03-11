# Task 09: Duplicate Visibility UI

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off

## Objective
Repurpose the old duplicate-override task into a simpler duplicate-inspection task for CSV v1.

## V1 Goal
Help the user understand why a row was marked `duplicate`, without providing any override control.

## In Scope
- show duplicate rows distinctly in the details page
- optionally show the matched fingerprint or referenced evidence row
- optionally show whether the matched prior row was already materialized

## Out of Scope
- force-approve UI
- duplicate override workflow
- side-by-side approval wizard

## Recommended UX
- inline expandable detail or lightweight drawer
- enough context to explain the duplicate classification
- clear copy that duplicates are not materialized in v1

## Remaining Open Question
1. Is simple inline duplicate context enough for v1, or do we still want a dedicated comparison drawer for readability?
