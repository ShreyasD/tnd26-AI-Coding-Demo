# Bug Fix: `schedule_complete` Variable Never Set to True

> **Mode:** Agent Mode
> **Date:** 2026-04-06
> **Target Org:** `tnd26-demo-org` (`sdhond@tnd26demo.com`)
> **File Fixed:** `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent`

---

## Summary

The `schedule_complete` boolean variable was declared and used as the success-branch guard in the agent's reasoning logic, but it was **never set to `True`** after a successful action execution. This caused the confirmation message to never be shown to the user after a property showing was successfully scheduled.

---

## Issue Details

### Symptom

After the `create_showing` action executed successfully and created an Event record, the agent would never display the success confirmation message ("The showing has been scheduled successfully..."). Instead, it would fall through to the default instructions, re-prompting the employee for property and date/time information as if nothing had happened.

### Root Cause

The `schedule_complete` variable was:

1. **Declared** on line 16 as `mutable boolean = False`
2. **Checked** on line 60 as `if @variables.schedule_complete == True`
3. **Never updated** — none of the `set` directives in the action output mapping (lines 77-79) wrote to `schedule_complete`

The action's `set` block only captured three output variables:

```
set @variables.event_id = @outputs.eventId
set @variables.confirmation_msg = @outputs.confirmationMessage
set @variables.error_msg = @outputs.errorMessage
```

No `set @variables.schedule_complete = True` existed anywhere in the file.

### Impact

- **Severity:** High — the primary user-facing success flow was broken
- **Affected behavior:** Successful scheduling operations produced no confirmation to the user
- **Error path:** Unaffected (the error branch checked `@variables.error_msg != ""` which was correctly populated)

---

## Actions Performed

### Step 1: Verify the Issue

**Action:** Read the full `.agent` file to confirm the reported bug.

**Reasoning:** Before making any changes, verify the issue exists exactly as described. Need to see the complete variable lifecycle — declaration, reads, and writes.

**Result:** Confirmed. The file contained:
- Line 16: `schedule_complete: mutable boolean = False` (declaration)
- Line 60: `if @variables.schedule_complete == True:` (read/guard)
- Lines 77-79: Three `set` directives, none touching `schedule_complete` (missing write)

The variable was write-orphaned — declared and read, but never written to after initialization.

### Step 2: Determine the Fix Strategy

**Action:** Analyzed two possible approaches.

**Reasoning:** There were two valid ways to fix this:

| Approach | Description | Trade-off |
|----------|-------------|-----------|
| A) Add a `set` | Add `set @variables.schedule_complete = True` after line 79 | Keeps the boolean variable but Agent Script `set` in action blocks is unconditional — it would always set to `True` even on failure |
| B) Remove variable, branch on `event_id` | Delete `schedule_complete`, change guard to `if @variables.event_id != ""` | Cleaner; `event_id` is already populated by the action and is empty string on failure, non-empty on success |

**Decision:** Approach B — remove the redundant boolean and use `event_id` as the success signal. This is more robust because:
- `event_id` is already being set from `@outputs.eventId` (line 77)
- The Apex action returns an empty string for `eventId` on failure and a real Salesforce ID on success
- Eliminates a variable that served no purpose beyond what `event_id` already provides
- Avoids the unconditional-set problem with approach A

### Step 3: Remove the `schedule_complete` Variable Declaration

**Action:** Edited the `variables:` block to remove the `schedule_complete` line.

**Before:**
```
variables:
  event_id: mutable string = ""
  confirmation_msg: mutable string = ""
  error_msg: mutable string = ""
  schedule_complete: mutable boolean = False
```

**After:**
```
variables:
  event_id: mutable string = ""
  confirmation_msg: mutable string = ""
  error_msg: mutable string = ""
```

### Step 4: Update the Reasoning Guard Condition

**Action:** Changed the success-branch condition from checking the removed boolean to checking `event_id`.

**Before:**
```
instructions: ->
  if @variables.schedule_complete == True:
    | The showing has been scheduled successfully.
    | Confirmation: {!@variables.confirmation_msg}
    | Ask if they would like to schedule another showing.
```

**After:**
```
instructions: ->
  if @variables.event_id != "":
    | The showing has been scheduled successfully.
    | Confirmation: {!@variables.confirmation_msg}
    | Ask if they would like to schedule another showing.
```

### Step 5: Validate the Agent Script

**Action:** Ran `sf agent validate authoring-bundle --api-name Property_Showing_Scheduler --target-org tnd26-demo-org`

**Reasoning:** Agent Script validation checks syntax, variable references, action target resolution, and structural correctness. Must pass before publishing.

**Result:** Validation succeeded:
```json
{
  "status": 0,
  "result": {
    "success": true
  }
}
```

### Step 6: Publish the Updated Agent

**Action:** Ran `sf agent publish authoring-bundle --api-name Property_Showing_Scheduler --target-org tnd26-demo-org`

**Reasoning:** Publishing pushes the corrected agent definition to the org, creating a new BotVersion. This makes the fix live.

**Result:** Publish succeeded in ~42 seconds:
```json
{
  "status": 0,
  "result": {
    "success": true,
    "botDeveloperName": "Property_Showing_Scheduler"
  }
}
```

### Step 7: Verify Final State

**Action:** Read the final `.agent` file to confirm all changes were applied correctly.

**Result:** Verified:
- `schedule_complete` variable is fully removed (not in `variables:` block)
- Success guard on line 59 now reads `if @variables.event_id != ""`
- All other logic (error branch, default instructions, action mappings) unchanged
- File is 79 lines (down from 80 — one variable declaration line removed)

---

## Files Changed

| File | Change |
|------|--------|
| `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent` | Removed `schedule_complete` variable; changed success guard to check `event_id != ""` |

---

## Final Agent File State

```
config:
  developer_name: "Property_Showing_Scheduler"
  agent_description: "Schedules property showing events for employees by creating calendar events linked to properties and their broker contacts"
  agent_type: "AgentforceEmployeeAgent"

system:
  messages:
    welcome: "Hello! I can help you schedule a property showing. Which property would you like to schedule a showing for?"
    error: "Sorry, something went wrong while scheduling your showing. Please try again."
  instructions: "You are a property showing scheduling assistant. You help employees schedule showing events for properties. When scheduling, you need the property name or ID and the desired date and time. Be concise and professional."

variables:
  event_id: mutable string = ""
  confirmation_msg: mutable string = ""
  error_msg: mutable string = ""

start_agent entry:
  description: "Entry point for property showing scheduling conversations"
  reasoning:
    instructions: |
      Greet the employee and ask which property they want to schedule a showing for.
      Route to the schedule_showing topic.
    actions:
      go_schedule: @utils.transition to @topic.schedule_showing
        description: "Navigate to showing scheduler"

topic schedule_showing:
  description: "Schedules a property showing event by collecting property and datetime information, then creating a calendar event linked to the property and its broker contact"

  actions:
    create_showing:
      description: "Creates a property showing event. Requires the property ID and a future start date/time. Optionally accepts duration in minutes, a custom subject, and event description."
      inputs:
        propertyId: string
          description: "The Salesforce record ID of the Property__c record to schedule the showing for"
          is_required: True
          is_user_input: True
        startDateTime: datetime
          description: "The date and time when the property showing should begin. Must be in the future."
          is_required: True
          is_user_input: True
        durationMinutes: integer
          description: "Duration of the showing in minutes. Defaults to 30 if not provided."
        subject: string
          description: "Custom subject line for the event. Defaults to Property Showing if not provided."
        eventDescription: string
          description: "Optional description or notes for the showing event"
      outputs:
        eventId: string
          description: "The ID of the created Event record"
        confirmationMessage: string
          description: "A confirmation message with the event details"
        errorMessage: string
          description: "Error message if the event could not be created"
      target: "apex://PropertyShowingSchedulerAction"

  reasoning:
    instructions: ->
      if @variables.event_id != "":
        | The showing has been scheduled successfully.
        | Confirmation: {!@variables.confirmation_msg}
        | Ask if they would like to schedule another showing.

      if @variables.error_msg != "":
        | The last scheduling attempt failed: {!@variables.error_msg}
        | Ask the employee to correct the information and try again.

      | Help the employee schedule a property showing.
      | Ask for the property they want to show and the desired date and time.
      | The duration defaults to 30 minutes if not specified.
    actions:
      schedule: @actions.create_showing
        description: "Schedule the property showing"
        with propertyId = ...
        with startDateTime = ...
        set @variables.event_id = @outputs.eventId
        set @variables.confirmation_msg = @outputs.confirmationMessage
        set @variables.error_msg = @outputs.errorMessage
```

---

## Verification Checklist

- [x] Issue confirmed: `schedule_complete` never written to after init
- [x] Redundant variable removed from `variables:` block
- [x] Success guard updated to `@variables.event_id != ""`
- [x] Agent script validated successfully
- [x] Agent published to target org successfully
- [x] No other references to `schedule_complete` remain in the file
