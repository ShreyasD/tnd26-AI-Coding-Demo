# UC2: Employee Property Showing Scheduling Agent — Planning Transcript

> **Mode:** Ask Mode (planning only — no edits)
> **Date:** 2026-04-06
> **Use Case:** Single-topic Employee Agent to schedule Event records for property showings
> **Agent Type:** Deterministic Agentforce Employee Agent (Agent Script DSL)

---

## Table of Contents

1. [Use Case Summary](#use-case-summary)
2. [Team Roster & Role Assignments](#team-roster--role-assignments)
3. [Data Model](#data-model)
4. [Existing Assets](#existing-assets)
5. [Implementation Plan — Role-Assigned Tasks](#implementation-plan--role-assigned-tasks)
6. [Task Dependency Graph](#task-dependency-graph)
7. [File Inventory](#file-inventory)
8. [Agent Script Specification](#agent-script-specification)
9. [Smoke Test Plan](#smoke-test-plan)
10. [Key Constraints & Gotchas](#key-constraints--gotchas)

---

## Use Case Summary

An **Employee Agent** that helps internal employees schedule property showing events. The agent:

- Has **one topic** (`schedule_showing`) with **one action** (`create_showing`)
- Collects property ID and desired date/time from the employee via conversation
- Creates an `Event` record linked to the `Property__c` (WhatId) and the broker's `Contact` (WhoId)
- The running employee is automatically the Event owner (Employee Agent runs as the logged-in user)

**Conversation flow:**
```
Employee: "Schedule a showing for 321 Oak Street tomorrow at 2pm"
Agent: [extracts property + datetime] → calls Apex action → "Done! Event 00U... created."
```

---

## Team Roster & Role Assignments

| Agent Role | Agent Name | Responsibilities in This Use Case |
|---|---|---|
| **Strategist** | `fde-strategist` | Architecture planning, task decomposition, team coordination. Owns this plan document. Does NOT edit files. |
| **FDE Engineer** | `fde-engineer` | Authors the `.agent` file (Agent Script DSL). Reviews/adjusts the existing Apex `@InvocableMethod` if needed. Owns agent configuration and metadata authoring. |
| **PS Technical Architect** | `ps-technical-architect` | Owns the Apex `@InvocableMethod` action (`PropertyShowingSchedulerAction.cls`). Reviews for bulkification, governor limits, and error handling. Enhances test class coverage. |
| **FDE Experience Specialist** | `fde-experience-specialist` | Designs conversation flow: system instructions, welcome message, error message, topic instructions, and the natural language prompts that guide the employee. Defines persona voice/tone. |
| **FDE QA Engineer** | `fde-qa-engineer` | Runs Apex tests (`PropertyShowingSchedulerActionTest`), validates agent script with `sf agent validate`, executes preview smoke tests, and analyzes coverage gaps. |
| **FDE Release Engineer** | `fde-release-engineer` | Deploys Apex to target org, publishes the agent bundle via `sf agent publish`, activates the agent, updates `sfdx-project.json` API version to 66.0. |
| **PS Solution Architect** | `ps-solution-architect` | Validates data model (Property__c, Broker__c, Contact relationships). Creates architecture diagrams (ERD, sequence). Reviews permission set requirements if needed. |

---

## Data Model

```
Property__c
├── Name (Text) — Property name
├── Broker__c (Lookup → Broker__c) — SetNull on delete
├── Address__c, City__c, State__c, Zip__c, Price__c, ...
│
Broker__c
├── Name (Text) — Broker name
├── Contact__c (Lookup → Contact) — SetNull on delete
├── Email__c, Phone__c, Mobile_Phone__c, ...
│
Event (Standard Object)
├── WhatId → Property__c (the property being shown)
├── WhoId → Contact (the broker's contact record)
├── OwnerId → Running User (the employee — auto-set for Employee Agent)
├── Subject, Description, StartDateTime, EndDateTime
```

**Resolution chain:** `Property__c.Broker__c` → `Broker__c.Contact__c` → `Contact.Id` → `Event.WhoId`

---

## Existing Assets

| Asset | Path | Status |
|---|---|---|
| Apex Action | `force-app/main/default/classes/PropertyShowingSchedulerAction.cls` | **Exists** — `@InvocableMethod` with Request/Response wrappers |
| Apex Action Meta | `force-app/main/default/classes/PropertyShowingSchedulerAction.cls-meta.xml` | **Exists** |
| Apex Test | `force-app/main/default/classes/PropertyShowingSchedulerActionTest.cls` | **Exists** — 3 test methods, needs enhancement |
| Property__c Object | `force-app/main/default/objects/Property__c/` | **Exists** — 27 fields including Broker__c lookup |
| Broker__c Object | `force-app/main/default/objects/Broker__c/` | **Exists** — 10 fields including Contact__c lookup |
| Agent Script | `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/` | **Does not exist** — to be created |
| GenAi Metadata | `force-app/main/default/genAiFunctions/`, `genAiPlugins/` | Empty folders — **not needed** for Agent Script path |
| sfdx-project.json | `sfdx-project.json` | **Exists** — API v65.0, needs bump to v66.0 |

---

## Implementation Plan — Role-Assigned Tasks

### Phase 1: Foundation & Design (Parallel)

#### Task 1.1 — Validate Data Model & Create Architecture Diagram
**Assigned to: `ps-solution-architect`**
- Verify `Property__c.Broker__c` and `Broker__c.Contact__c` lookups are correctly configured
- Confirm `Property__c` has `enableActivities: true` (required for Event.WhatId)
- Create an ERD (Mermaid) showing Property → Broker → Contact → Event relationships
- Create a sequence diagram showing the agent conversation flow
- Document any permission set requirements (Object CRUD + FLS for Property__c, Broker__c, Event)

#### Task 1.2 — Design Conversation Experience
**Assigned to: `fde-experience-specialist`**
- Write the agent persona: professional, concise, scheduling-assistant tone
- Author the `system.messages.welcome` greeting
- Author the `system.messages.error` fallback
- Author `system.instructions` (global agent personality)
- Author `topic.schedule_showing` reasoning instructions (how to collect info, respond to success/failure)
- Define sample utterances for the schedule_showing topic (minimum 10)

#### Task 1.3 — Review & Enhance Apex Action
**Assigned to: `ps-technical-architect`**
- Review `PropertyShowingSchedulerAction.cls` for:
  - Bulkification correctness (already bulk-safe — confirm)
  - Error handling coverage (null checks, invalid IDs, past dates — confirm)
  - Governor limit safety (2 SOQL queries, 1 DML — confirm within limits)
- Verify `@InvocableVariable` field names match what Agent Script will reference
- **Action required:** Confirm I/O field name mapping:
  - Inputs: `propertyId`, `startDateTime`, `durationMinutes`, `subject`, `eventDescription`
  - Outputs: `eventId`, `confirmationMessage`, `errorMessage`

#### Task 1.4 — Enhance Apex Test Coverage
**Assigned to: `ps-technical-architect`**
- Add test methods for uncovered scenarios:
  - `startDateTime` in the past → error
  - Blank/null `propertyId` → error
  - Null request list → empty response
  - Default duration (null `durationMinutes`) → 30-minute event
  - Default subject (blank `subject`) → "Property Showing"
  - Broker exists but `Contact__c` is null → error
- Target: 90%+ coverage on `PropertyShowingSchedulerAction.cls`

---

### Phase 2: Agent Script Authoring (Sequential — depends on Phase 1)

#### Task 2.1 — Author the Agent Script `.agent` File
**Assigned to: `fde-engineer`**

**Depends on:** Task 1.2 (conversation content), Task 1.3 (confirmed I/O names)

Create `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent` with:

- `config:` block — Employee Agent, developer_name matches folder
- `system:` block — messages and instructions from Experience Specialist (Task 1.2)
- `variables:` block — mutable state for event_id, confirmation, error, completion flag
- `start_agent:` block — entry point routing to schedule_showing topic
- `topic schedule_showing:` block — single topic with single `apex://PropertyShowingSchedulerAction` action
- Complete `inputs:` / `outputs:` matching exact `@InvocableVariable` field names
- Post-action conditional instructions for success/error feedback
- `is_user_input: True` on `propertyId` and `startDateTime`

**Activation Checklist (must verify before commit):**
- [ ] Exactly one `start_agent` block
- [ ] No mixed tabs/spaces
- [ ] Booleans are `True` / `False`
- [ ] No `else if` or nested `if`
- [ ] No top-level `actions:` block
- [ ] `agent_type: "AgentforceEmployeeAgent"` — explicit
- [ ] No `default_agent_user` (forbidden for Employee Agent)
- [ ] `developer_name` matches bundle folder name
- [ ] I/O names match `@InvocableVariable` field names exactly
- [ ] `datetime` and `integer` used only in action I/O, not as variable types

#### Task 2.2 — Update sfdx-project.json API Version
**Assigned to: `fde-engineer`**

- Bump `sourceApiVersion` from `"65.0"` to `"66.0"` (required for Agent Script)

---

### Phase 3: Validation & Testing (Parallel — depends on Phase 2)

#### Task 3.1 — Run Apex Tests
**Assigned to: `fde-qa-engineer`**
- Execute: `sf apex run test --class-names PropertyShowingSchedulerActionTest --target-org <ORG> --result-format human --code-coverage`
- Validate all tests pass
- Confirm coverage ≥ 85% on `PropertyShowingSchedulerAction.cls`
- Report any failures back to `ps-technical-architect`

#### Task 3.2 — Validate Agent Script
**Assigned to: `fde-qa-engineer`**
- Execute: `sf agent validate authoring-bundle --api-name Property_Showing_Scheduler --target-org <ORG> --json`
- Fix or report any validation errors
- Confirm clean validation before publish

#### Task 3.3 — Preview Smoke Tests
**Assigned to: `fde-qa-engineer`**

**Depends on:** Task 4.1 (agent must be published first)

Run interactive preview with test utterances (see Smoke Test Plan below)

---

### Phase 4: Deployment & Activation (Sequential — depends on Phase 3)

#### Task 4.1 — Deploy All Metadata & Publish Agent
**Assigned to: `fde-release-engineer`**

**Depends on:** Tasks 3.1, 3.2 passing

1. Deploy Apex classes to target org:
   ```bash
   sf project deploy start --source-dir force-app/main/default/classes --target-org <ORG>
   ```
2. Publish the agent bundle:
   ```bash
   sf agent publish authoring-bundle --api-name Property_Showing_Scheduler --target-org <ORG> --json
   ```
3. Activate the agent:
   ```bash
   sf agent activate --api-name Property_Showing_Scheduler --target-org <ORG>
   ```

#### Task 4.2 — Post-Deployment Verification
**Assigned to: `fde-qa-engineer`**
- Run preview smoke tests (Task 3.3)
- Verify Event records are created correctly in the org
- Confirm Event.OwnerId = running employee user
- Confirm Event.WhatId = Property__c record
- Confirm Event.WhoId = Broker's Contact record

---

## Task Dependency Graph

```
Phase 1 (Parallel):
  Task 1.1 [ps-solution-architect]  ──┐
  Task 1.2 [fde-experience-specialist]─┤
  Task 1.3 [ps-technical-architect] ──┤
  Task 1.4 [ps-technical-architect] ──┘ (can run parallel with 1.3)
                                       │
Phase 2 (Sequential):                 ▼
  Task 2.1 [fde-engineer] ← depends on 1.2 + 1.3
  Task 2.2 [fde-engineer] ← can run parallel with 2.1
                                       │
Phase 3 (Parallel):                   ▼
  Task 3.1 [fde-qa-engineer] ← depends on 1.4 + 4.1(deploy)
  Task 3.2 [fde-qa-engineer] ← depends on 2.1
                                       │
Phase 4 (Sequential):                 ▼
  Task 4.1 [fde-release-engineer] ← depends on 3.1 + 3.2
  Task 4.2 [fde-qa-engineer]     ← depends on 4.1
```

---

## File Inventory

### Files to Create

| File | Owner | Description |
|---|---|---|
| `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent` | `fde-engineer` | Agent Script definition |

### Files to Modify

| File | Owner | Change |
|---|---|---|
| `force-app/main/default/classes/PropertyShowingSchedulerActionTest.cls` | `ps-technical-architect` | Add 5-6 new test methods for edge cases |
| `sfdx-project.json` | `fde-engineer` | Bump `sourceApiVersion` from `65.0` to `66.0` |

### Files to Review Only (No Changes)

| File | Reviewer | Purpose |
|---|---|---|
| `force-app/main/default/classes/PropertyShowingSchedulerAction.cls` | `ps-technical-architect` | Confirm I/O names, bulkification, error handling |
| `force-app/main/default/objects/Property__c/fields/Broker__c.field-meta.xml` | `ps-solution-architect` | Confirm lookup relationship |
| `force-app/main/default/objects/Broker__c/fields/Contact__c.field-meta.xml` | `ps-solution-architect` | Confirm lookup relationship |
| `force-app/main/default/objects/Property__c/Property__c.object-meta.xml` | `ps-solution-architect` | Confirm `enableActivities: true` |

---

## Agent Script Specification

### Config

```yaml
config:
  developer_name: "Property_Showing_Scheduler"
  agent_description: "Schedules property showing events for employees by creating calendar events linked to properties and their broker contacts"
  agent_type: "AgentforceEmployeeAgent"
```

### System

```yaml
system:
  messages:
    welcome: "Hello! I can help you schedule a property showing. Which property would you like to schedule a showing for?"
    error: "Sorry, something went wrong while scheduling your showing. Please try again."
  instructions: "You are a property showing scheduling assistant. You help employees schedule showing events for properties. When scheduling, you need the property name or ID and the desired date and time. Be concise and professional."
```

### Variables

```yaml
variables:
  event_id: mutable string = ""
  confirmation_msg: mutable string = ""
  error_msg: mutable string = ""
  schedule_complete: mutable boolean = False
```

### Start Agent

```yaml
start_agent entry:
  description: "Entry point — greet and route to the scheduling topic"
  reasoning:
    instructions: |
      Greet the employee and ask which property they want to schedule a showing for.
      Route to the schedule_showing topic.
    actions:
      go_schedule: @utils.transition to @topic.schedule_showing
        description: "Navigate to showing scheduler"
```

### Topic: schedule_showing

```yaml
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
      if @variables.schedule_complete == True:
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

## Smoke Test Plan

| # | Test Utterance | Expected Behavior | Validates |
|---|---|---|---|
| 1 | "Schedule a showing for property a0xxx... tomorrow at 2pm" | Collects inputs, creates Event, returns confirmation with Event ID | Happy path |
| 2 | "Schedule a showing" | Agent asks for property and date/time | Slot filling |
| 3 | "I want to see 123 Main St next Monday at 10am for an hour" | Creates 60-min event | Custom duration extraction |
| 4 | "Schedule a showing for an invalid property ID" | Returns "Property not found" error | Error handling |
| 5 | "Schedule for yesterday at noon" | Returns "startDateTime must be in the future" error | Date validation |

---

## Key Constraints & Gotchas

| # | Constraint | Impact | Mitigation |
|---|---|---|---|
| 1 | **API Version 66.0 required** | Agent Script won't work on v65.0 | Task 2.2: bump `sfdx-project.json` |
| 2 | **Employee Agent has no `default_agent_user`** | Omit the field entirely; including it will cause publish error | Activation checklist item |
| 3 | **I/O names must exactly match `@InvocableVariable` fields** | Mismatch → "invalid input/output" at publish | Task 1.3: explicit confirmation of field names |
| 4 | **`datetime`/`integer` are action-I/O-only types** | Cannot use as `mutable`/`linked` variable types | Variables use `string`/`boolean` instead |
| 5 | **`developer_name` must match bundle folder** | Mismatch → validation failure | Both set to `Property_Showing_Scheduler` |
| 6 | **Publish does NOT activate** | Agent is inert after publish | Task 4.1: explicit `sf agent activate` step |
| 7 | **Apex must be deployed before agent publish** | `apex://PropertyShowingSchedulerAction` must exist in org | Task 4.1: deploy Apex first, then publish agent |
| 8 | **`Property__c.enableActivities` must be `true`** | Required for `Event.WhatId` to accept Property records | Confirmed in existing metadata |
