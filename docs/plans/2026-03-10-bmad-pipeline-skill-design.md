# BMAD Pipeline Automation Skill — Design Document

**Date**: 2026-03-10
**Status**: Approved

## Overview

A Claude Code skill (`/bmad-pipeline`) that automates the BMAD Phase 4 implementation loop by orchestrating three agents (SM, PM, Dev) with gated handoffs between phases.

## Requirements

- **Pipeline**: SM (draft story) → PM (validate) → Dev (implement) → PM (review) → Dev (fix if needed) → loop to next story
- **Starting point**: Story 1.3, all Phase 2-3 planning artifacts exist
- **Autonomy**: SM and Dev run YOLO (autonomous subagents), PM runs interactively in main context
- **Gates**: Approve / Retry / Edit between each phase, max 3 retries per gate
- **Scope**: Continuous loop across stories until no backlog stories remain
- **PM validation**: Structured checklist-based review (adapted from validate-PRD workflow)

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Orchestrator Skill (/bmad-pipeline)    │
│                                                  │
│  1. Read sprint-status.yaml → find next story    │
│  2. Loop:                                        │
│     ┌──────────────┐                             │
│     │ SM Subagent   │ YOLO - drafts story file   │
│     └──────┬───────┘                             │
│            ▼                                     │
│     ══ GATE 1 ══  (approve / retry / edit)       │
│            ▼                                     │
│     ┌──────────────┐                             │
│     │ PM Validation │ Interactive in main context │
│     └──────┬───────┘                             │
│            ▼                                     │
│     ══ GATE 2 ══  (approve / retry / edit)       │
│            ▼                                     │
│     ┌──────────────┐                             │
│     │ Dev Subagent  │ YOLO - implements story     │
│     └──────┬───────┘                             │
│            ▼                                     │
│     ══ GATE 3 ══  (approve / retry / edit)       │
│            ▼                                     │
│     ┌──────────────┐                             │
│     │ PM Review     │ Interactive in main context │
│     └──────┬───────┘                             │
│            ▼                                     │
│     ══ GATE 4 ══  (approve / retry / edit)       │
│            ▼                                     │
│     If issues → Dev Fix Subagent (YOLO)          │
│            ▼                                     │
│     Update sprint-status.yaml → next story       │
│     ══ GATE 5 ══  (continue next story / stop)   │
│  3. Repeat                                       │
└─────────────────────────────────────────────────┘
```

## Subagent Design

### SM Subagent (Story Drafting)
- **Input**: Path to sprint-status.yaml, path to epics.md, story key to draft
- **Instructions**: Load SM agent persona + create-story/workflow.yaml + workflow.xml engine. Execute in YOLO mode. Save story file to implementation-artifacts/
- **Output**: Path to created story file + summary

### Dev Subagent (Implementation)
- **Input**: Path to approved story file
- **Instructions**: Load Dev agent persona + dev-story/workflow.yaml + workflow.xml engine. Execute all tasks/subtasks in order with TDD. Update story file with Dev Agent Record.
- **Output**: Summary of implementation, tests, files changed

### Dev Fix Subagent (Post-review fixes)
- **Input**: Path to story file + PM's review feedback (specific issues)
- **Instructions**: Same as Dev subagent but scoped to PM's flagged issues. Run tests after fixes.
- **Output**: Summary of fixes applied

### PM Phases (Main Context)
- **PM Validation**: Load story file content, run structured validation checklist (adapted from validate-PRD). Interactive — user discusses issues with PM. Output: approved / list of patches.
- **PM Review**: Load updated story file (with Dev Agent Record) + git diff. Review implementation against ACs. Interactive. Output: approved / list of issues.

## Gate Mechanics

Each gate displays:
1. Summary of what the agent just did
2. Path to the output artifact
3. Preview of key content (~50 lines)
4. Options: [A] Approve, [R] Retry (with optional feedback), [E] Edit (pause for manual edits)

**Retry behavior:**
- Gates 1, 3: Re-runs subagent with feedback appended to prompt
- Gates 2, 4: Continues PM conversation to address concerns
- Gate 5: Continue to next story / stop

**Max retries**: 3 per gate. After 3, pipeline halts.

**Edit behavior**: Orchestrator pauses, user edits artifact, types "done" to resume.

## Sprint Status & Story Loop

### Story Discovery
1. Read sprint-status.yaml
2. Find first story with status `backlog`
3. If no backlog stories in current epic, check next epic
4. If all done, pipeline completes with summary

### Status Transitions
```
backlog → (SM drafts) → ready-for-dev
ready-for-dev → (Dev starts) → in-progress
in-progress → (Dev completes) → review
review → (PM approves) → done
```

### Edge Cases
- Status `ready-for-dev`: Skip SM, go to PM validation
- Status `in-progress`: Skip SM + PM validation, resume Dev
- Status `review`: Skip to PM review
- Pipeline resumes from current sprint-status.yaml state

## File Structure

Single skill file: `~/.claude/skills/bmad-pipeline.md`

No new files in the BMAD project — skill reads/writes to existing `_bmad-output/` structure.

**Invocation:**
- `/bmad-pipeline` — auto-discovers next backlog story
- `/bmad-pipeline 1.3` — targets specific story

## Key File Paths

- Config: `{project-root}/_bmad/bmm/config.yaml`
- Sprint status: `{project-root}/_bmad-output/implementation-artifacts/sprint-status.yaml`
- Epics: `{project-root}/_bmad-output/planning-artifacts/epics.md`
- Story output: `{project-root}/_bmad-output/implementation-artifacts/{story_key}.md`
- SM agent: `{project-root}/_bmad/bmm/agents/sm.md`
- Dev agent: `{project-root}/_bmad/bmm/agents/dev.md`
- PM agent: `{project-root}/_bmad/bmm/agents/pm.md`
- Workflow engine: `{project-root}/_bmad/core/tasks/workflow.xml`
- Create-story workflow: `{project-root}/_bmad/bmm/workflows/4-implementation/create-story/workflow.yaml`
- Dev-story workflow: `{project-root}/_bmad/bmm/workflows/4-implementation/dev-story/workflow.yaml`
- Validate-PRD workflow: `{project-root}/_bmad/bmm/workflows/2-plan-workflows/create-prd/workflow-validate-prd.md`
