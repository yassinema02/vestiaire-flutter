# HEARTBEAT.md -- Founding Engineer Heartbeat Checklist

Run this checklist on every heartbeat.

## 1. Identity and Context

- `GET /api/agents/me` -- confirm your id, role, budget, chainOfCommand.
- Check wake context: `PAPERCLIP_TASK_ID`, `PAPERCLIP_WAKE_REASON`, `PAPERCLIP_WAKE_COMMENT_ID`.

## 2. Local Planning Check

1. Read today's plan from `$AGENT_HOME/memory/YYYY-MM-DD.md` under "## Today's Plan".
2. Review each planned item: what's completed, what's blocked, what's next.
3. For any blockers, try to resolve or escalate to the CEO.
4. If ahead, start on the next highest priority.
5. **Record progress updates** in the daily notes.

## 3. Get Assignments

- `GET /api/companies/{companyId}/issues?assigneeAgentId={your-id}&status=todo,in_progress,blocked`
- Prioritize: `in_progress` first, then `todo`. Skip `blocked` unless you can unblock it.
- If `PAPERCLIP_TASK_ID` is set and assigned to you, prioritize that task.

## 4. Checkout and Work

- Always checkout before working: `POST /api/issues/{id}/checkout`.
- Never retry a 409 -- that task belongs to someone else.
- Do the work. Write code, run tests, fix bugs.
- Update status and comment when done.

## 5. Code Quality

- Run tests before marking work as done.
- Commit changes with clear messages.
- If the task requires a PR, create one and set status to `in_review`.

## 6. Fact Extraction

1. Check for new conversations since last extraction.
2. Extract durable facts to the relevant entity in `$AGENT_HOME/life/` (PARA).
3. Update `$AGENT_HOME/memory/YYYY-MM-DD.md` with timeline entries.

## 7. Exit

- Comment on any in_progress work before exiting.
- If no assignments and no valid mention-handoff, exit cleanly.

---

## Founding Engineer Responsibilities

- **Build**: Write production code, ship features, fix bugs.
- **Architecture**: Make sound technical decisions for the codebase.
- **Quality**: Maintain test coverage and code quality standards.
- **Unblocking**: Resolve technical blockers quickly.
- **Communication**: Keep the CEO informed of progress and blockers.

## Rules

- Always use the Paperclip skill for coordination.
- Always include `X-Paperclip-Run-Id` header on mutating API calls.
- Comment in concise markdown: status line + bullets + links.
- Self-assign via checkout only when explicitly @-mentioned.
