# Bug Fix: Null vs Empty String — Success Branch Executes on Failure

**Date:** April 6, 2026
**Agent:** Property_Showing_Scheduler
**Target Org:** tnd26-demo-org
**Files Changed:** 3 (Agent Script, Apex Action, Apex Test)

---

## Issue Reported

The condition `if @variables.event_id != ""` was introduced to detect successful action execution by checking if `event_id` is not empty. However, the Apex action returns `null` for `eventId` on failure (not an empty string), causing `null != ""` to evaluate as `true` in Salesforce Agent Script. This means the success confirmation branch executes even when the action fails, displaying the success message incorrectly.

---

## Phase 1: Verification — Reading the Agent Script

**Action:** Read `Property_Showing_Scheduler.agent` to confirm the reported issue.

**Finding — Original reasoning block (lines 57–66):**

```
  reasoning:
    instructions: ->
      if @variables.event_id != "":
        | The showing has been scheduled successfully.
        | Confirmation: {!@variables.confirmation_msg}
        | Ask if they would like to schedule another showing.

      if @variables.error_msg != "":
        | The last scheduling attempt failed: {!@variables.error_msg}
        | Ask the employee to correct the information and try again.
```

**Variable assignments after action execution (lines 76–78):**

```
        set @variables.event_id = @outputs.eventId
        set @variables.confirmation_msg = @outputs.confirmationMessage
        set @variables.error_msg = @outputs.errorMessage
```

**Observation:** The variable `event_id` is initialized as `""` (line 13), but after a failed action call, `@outputs.eventId` returns `null` which gets assigned to `event_id`. In Salesforce's expression evaluation, `null != ""` evaluates to `true`, so the success branch fires on failure.

---

## Phase 2: Verification — Reading the Apex Action

**Action:** Read `PropertyShowingSchedulerAction.cls` to confirm null return behavior.

**Finding — Original Response class (lines 19–28):**

```java
global class Response {
    @InvocableVariable
    public String eventId;

    @InvocableVariable
    public String confirmationMessage;

    @InvocableVariable
    public String errorMessage;
}
```

**Analysis of Apex execution paths:**

| Path | `eventId` | `errorMessage` |
|------|-----------|----------------|
| **Success** (line 138) | Set to Event ID string | `null` (never assigned) |
| **Failure** (all error paths) | `null` (never assigned) | Set to error message string |

**Root cause confirmed:** On failure, `eventId` stays `null`. On success, `errorMessage` stays `null`. Both `null` values flow through to Agent Script where `null != ""` is truthy, meaning **both** the success and error branches could fire incorrectly depending on the scenario.

---

## Phase 3: Initial Fix Attempt — Agent Script Only

**Action:** Reorder conditions (error check first) and add a compound guard on the success condition.

**First attempt (used uppercase `AND`):**

```
      if @variables.error_msg == "" AND @variables.event_id != null AND @variables.event_id != "":
```

**Result:** `sf agent validate authoring-bundle` **FAILED**

```
SyntaxError: Unexpected 'AND' [Ln 63, Col 36]
```

**Reasoning:** Agent Script requires lowercase `and` for logical operators.

---

## Phase 4: Second Fix Attempt — Lowercase `and`

**Action:** Changed `AND` to `and`.

```
      if @variables.error_msg == "" and @variables.event_id != null and @variables.event_id != "":
```

**Result:** `sf agent validate authoring-bundle` **FAILED**

```
SyntaxError: Unexpected 'and' [Ln 63, Col 68]
```

**Reasoning:** Agent Script only supports **two-operand** compound conditions (`A and B`). Three-operand expressions (`A and B and C`) are not supported by the parser. Nested `if` is also forbidden.

---

## Phase 5: Root Cause Fix — Apex + Agent Script Together

**Reasoning:** Since Agent Script cannot express a three-way guard, and the null-vs-empty-string problem affects both `eventId` and `errorMessage`, the correct fix is to eliminate nulls at the source — initialize all Response fields to empty strings in the Apex action.

### Fix 1: `PropertyShowingSchedulerAction.cls` — Response class

**Before:**

```java
global class Response {
    @InvocableVariable
    public String eventId;

    @InvocableVariable
    public String confirmationMessage;

    @InvocableVariable
    public String errorMessage;
}
```

**After:**

```java
global class Response {
    @InvocableVariable
    public String eventId = '';

    @InvocableVariable
    public String confirmationMessage = '';

    @InvocableVariable
    public String errorMessage = '';
}
```

**Effect:** All three output fields now default to `''` instead of `null`. On failure, `eventId` remains `''` (not `null`), so `event_id != ""` correctly evaluates to `false`. On success, `errorMessage` remains `''` (not `null`), so `error_msg != ""` correctly evaluates to `false`.

### Fix 2: `Property_Showing_Scheduler.agent` — Reasoning block

**Before:**

```
  reasoning:
    instructions: ->
      if @variables.event_id != "":
        | The showing has been scheduled successfully.
        | Confirmation: {!@variables.confirmation_msg}
        | Ask if they would like to schedule another showing.

      if @variables.error_msg != "":
        | The last scheduling attempt failed: {!@variables.error_msg}
        | Ask the employee to correct the information and try again.
```

**After:**

```
  reasoning:
    instructions: ->
      if @variables.error_msg != "":
        | The last scheduling attempt failed: {!@variables.error_msg}
        | Ask the employee to correct the information and try again.

      if @variables.error_msg == "" and @variables.event_id != "":
        | The showing has been scheduled successfully.
        | Confirmation: {!@variables.confirmation_msg}
        | Ask if they would like to schedule another showing.
```

**Changes:**
1. **Error check moved first** — failures are caught before the success path is evaluated
2. **Success condition strengthened** — requires both `error_msg == ""` (no error) AND `event_id != ""` (action actually returned an ID), using a two-operand `and` that the parser supports

### Fix 3: `PropertyShowingSchedulerActionTest.cls` — Test assertions

Updated 7 assertions across 6 test methods to match the new empty-string initialization:

| Test Method | Changed Assertion |
|-------------|-------------------|
| `schedulesEventUsingBrokerContactWhenContactMissing` | `assertEquals(null, errorMessage)` → `assertEquals('', errorMessage)` |
| `returnsErrorWhenPropertyIsNotFound` | `assertEquals(null, eventId)` → `assertEquals('', eventId)` |
| `returnsErrorWhenBrokerContactCannotBeResolved` | `assertEquals(null, eventId)` → `assertEquals('', eventId)` |
| `returnsErrorWhenStartDateTimeIsInThePast` | `assertEquals(null, eventId)` → `assertEquals('', eventId)` |
| `returnsErrorWhenPropertyIdIsBlank` | `assertEquals(null, eventId)` → `assertEquals('', eventId)` |
| `usesDefaultDurationWhenNotProvided` | `assertEquals(null, errorMessage)` → `assertEquals('', errorMessage)` |
| `usesDefaultSubjectWhenNotProvided` | `assertEquals(null, errorMessage)` → `assertEquals('', errorMessage)` |
| `returnsErrorWhenBrokerHasNoContact` | `assertEquals(null, eventId)` → `assertEquals('', eventId)` |

---

## Phase 6: Validation

**Action:** `sf agent validate authoring-bundle --api-name Property_Showing_Scheduler -o tnd26-demo-org --json`

**Result:** SUCCESS

```json
{
  "status": 0,
  "result": {
    "success": true
  }
}
```

---

## Phase 7: Deployment

### Step 1 — Deploy Apex classes

**Action:** `sf project deploy start --source-dir` (both Apex class and test class)

**Result:** SUCCESS — 2 components deployed, 0 errors

```
"numberComponentErrors": 0,
"numberComponentsDeployed": 2,
"status": "Succeeded"
```

### Step 2 — Publish agent

**Action:** `sf agent publish authoring-bundle --api-name Property_Showing_Scheduler -o tnd26-demo-org --json`

**Result:** SUCCESS

```json
{
  "status": 0,
  "result": {
    "success": true,
    "botDeveloperName": "Property_Showing_Scheduler"
  }
}
```

### Step 3 — Activate agent

**Action:** `sf agent activate --api-name Property_Showing_Scheduler -o tnd26-demo-org --json`

**Result:** SUCCESS (exit code 0)

---

## Summary

| Step | Action | Result |
|------|--------|--------|
| 1 | Read agent script | Confirmed `null != ""` bug in success condition |
| 2 | Read Apex action | Confirmed Response fields default to `null` |
| 3 | Try `AND` in agent script | FAILED — uppercase not supported |
| 4 | Try `and` with 3 operands | FAILED — only 2-operand compounds supported |
| 5 | Initialize Apex Response fields to `''` | Eliminates null at the source |
| 6 | Simplify agent script to 2-operand `and` | Validates successfully |
| 7 | Update test assertions `null` → `''` | Aligned with new behavior |
| 8 | Deploy Apex to org | 2 components, 0 errors |
| 9 | Publish agent | Success |
| 10 | Activate agent | Success |

### Key Lessons

1. **Salesforce Agent Script treats `null != ""` as `true`** — this is a common pitfall when Apex actions return uninitialized String fields.
2. **Agent Script only supports two-operand compound conditions** — `if A and B:` works, but `if A and B and C:` does not compile.
3. **Agent Script boolean operators are case-sensitive** — `and`/`or`/`not` (lowercase) are valid; `AND`/`OR`/`NOT` are not.
4. **Fix nulls at the source** — initializing Apex Response fields to `''` is cleaner than trying to work around null semantics in the Agent Script DSL.
