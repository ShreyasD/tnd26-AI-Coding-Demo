# Bug Fix: Agent Returns Incorrect Event Link (LLM Hallucination)

**Date:** April 11, 2026
**Agent:** Property_Showing_Scheduler
**Target Org:** tnd26-demo-org
**Files Changed:** 3 (Apex Action, Apex Test, Agent Script)

---

## Issue Reported

After scheduling a property showing, the agent returns an incorrect link pointing to the Lead object (`/lightning/o/Lead/...`) instead of the created Event record (`/lightning/r/Event/{eventId}/view`). The Apex code constructs the correct URL, but the LLM rewrites/hallucinates a different URL when presenting the confirmation to the user.

**Observed URL:** `https://trailsignup-499a6261e91e06.lightning.force.com/lightning/o/Lead/URL_Redacted`
**Expected URL:** `https://trailsignup-499a6261e91e06.my.salesforce.com/lightning/r/Event/{eventId}/view`

---

## Phase 1: Root Cause Analysis

**Action:** Read `PropertyShowingSchedulerAction.cls` and `Property_Showing_Scheduler.agent` to trace the link from creation to display.

### Apex — URL Construction (lines 143–145)

```apex
String baseUrl = URL.getOrgDomainURL().toExternalForm();
resp.confirmationMessage = 'Property showing scheduled! '
    + '[View Event](' + baseUrl + '/lightning/r/Event/' + resp.eventId + '/view)';
```

The Apex code correctly builds a markdown link to the Event record. The URL is embedded inside the `confirmationMessage` string alongside prose text.

### Agent Script — How the Link Reaches the User

Both topics (`schedule_showing` and `schedule_showing_for_lead`) display the confirmation via:

```
if @variables.error_msg == "" and @variables.event_id != "":
  | The showing has been scheduled successfully.
  | Confirmation: {!@variables.confirmation_msg}
  | The confirmation message contains a clickable link to the event. Display it as-is so the employee can click through.
```

### Root Cause

The LLM is **hallucinating the URL**. Despite the instruction to "display it as-is," the URL is embedded inside a longer text field (`confirmationMessage`) alongside prose. This gives the LLM an opportunity to reformulate the content rather than outputting it verbatim. The LLM substitutes a fabricated Lead object URL for the actual Event record URL.

This is a well-known pattern with LLMs: URLs buried in prose are treated as "content to be summarized" rather than "opaque data to pass through."

---

## Phase 2: Fix Strategy

Two complementary changes to make the URL tamper-proof:

1. **Apex:** Extract the URL into a dedicated `eventLink` output field, separate from the prose `confirmationMessage`
2. **Agent Script:** Add an `event_link` variable, bind it to the new output, and reference it directly in the reasoning instructions with explicit anti-hallucination guards

By isolating the URL in its own variable, the Agent Script can inject it via `{!@variables.event_link}` — a merge field the LLM cannot rewrite.

---

## Phase 3: Apex Changes

### Fix 1: `PropertyShowingSchedulerAction.cls` — Add `eventLink` output field

**Response class — added `eventLink` field:**

```apex
global class Response {
    @InvocableVariable
    public String eventId = '';

    @InvocableVariable
    public String eventLink = '';

    @InvocableVariable
    public String confirmationMessage = '';

    @InvocableVariable
    public String errorMessage = '';
}
```

**Success path — populate `eventLink` separately:**

```apex
if (saveResults[pos].isSuccess()) {
    resp.eventId = String.valueOf(saveResults[pos].getId());
    String baseUrl = URL.getOrgDomainURL().toExternalForm();
    resp.eventLink = baseUrl + '/lightning/r/Event/' + resp.eventId + '/view';
    resp.confirmationMessage = 'Property showing scheduled! '
        + '[View Event](' + resp.eventLink + ')';
```

### Fix 2: `PropertyShowingSchedulerActionTest.cls` — Add assertions for `eventLink`

Added assertions in three test methods:

| Test Method | Assertions Added |
|-------------|-----------------|
| `schedulesEventUsingBrokerContactWhenContactMissing` | `eventLink` contains `/lightning/r/Event/` and the event ID |
| `returnsErrorWhenPropertyIsNotFound` | `eventLink` is empty on error |
| `addsLeadAsEventRelationWhenLeadIdProvided` | `eventLink` contains `/lightning/r/Event/` and the event ID (lead path) |

---

## Phase 4: Agent Script Changes

### `Property_Showing_Scheduler.agent`

**1. Added `event_link` variable:**

```
variables:
  ...
  event_id: mutable string = ""
  event_link: mutable string = ""
  confirmation_msg: mutable string = ""
  ...
```

**2. Added `eventLink` output to both action definitions** (`create_showing` and `create_showing_for_lead`):

```
outputs:
  eventId: string
    description: "The ID of the created Event record"
  eventLink: string
    description: "The direct URL to the created Event record in Lightning Experience"
  confirmationMessage: string
    description: "A confirmation message with the event details and a clickable link to the event"
  errorMessage: string
    description: "Error message if the event could not be created"
```

**3. Bound `eventLink` output in both action invocations:**

```
set @variables.event_link = @outputs.eventLink
```

**4. Rewrote success reasoning blocks in both topics:**

**Before (topic `schedule_showing`):**

```
if @variables.error_msg == "" and @variables.event_id != "":
  | The showing has been scheduled successfully.
  | Confirmation: {!@variables.confirmation_msg}
  | The confirmation message contains a clickable link to the event. Display it as-is so the employee can click through.
  | Ask if they would like to schedule another showing.
```

**After:**

```
if @variables.error_msg == "" and @variables.event_id != "":
  | The showing has been scheduled successfully.
  | Display this exact link for the employee: [View Event]({!@variables.event_link})
  | IMPORTANT: Use the event_link URL exactly as provided. Do not modify, shorten, or replace it with a different URL.
  | Ask if they would like to schedule another showing.
```

**Before (topic `schedule_showing_for_lead`):**

```
if @variables.error_msg == "" and @variables.event_id != "":
  | The showing has been scheduled successfully for lead {!@variables.lead_name}.
  | Confirmation: {!@variables.confirmation_msg}
  | The confirmation message contains a clickable link to the event. Display it as-is so the employee can click through.
  | Ask if they would like to schedule another showing.
```

**After:**

```
if @variables.error_msg == "" and @variables.event_id != "":
  | The showing has been scheduled successfully for lead {!@variables.lead_name}.
  | Display this exact link for the employee: [View Event]({!@variables.event_link})
  | IMPORTANT: Use the event_link URL exactly as provided. Do not modify, shorten, or replace it with a different URL.
  | Ask if they would like to schedule another showing.
```

---

## Phase 5: Deployment

### Step 1 — Deploy Apex classes

**Command:** `sf project deploy start --metadata "ApexClass:PropertyShowingSchedulerAction" --metadata "ApexClass:PropertyShowingSchedulerActionTest" --target-org tnd26-demo-org --wait 30 --json`

**Result:** SUCCESS — 2 components deployed, 0 errors

```
"numberComponentErrors": 0,
"numberComponentsDeployed": 2,
"status": "Succeeded"
```

### Step 2 — Run tests

**Command:** `sf apex run test --class-names PropertyShowingSchedulerActionTest --result-format human --wait 5 -o tnd26-demo-org`

**Result:** SUCCESS — 11/11 tests passed, 100% pass rate

```
Outcome              Passed
Tests Ran            11
Pass Rate            100%
Fail Rate            0%
Test Execution Time  1498 ms
```

### Step 3 — Deactivate agent

**Command:** `sf agent deactivate --api-name Property_Showing_Scheduler -o tnd26-demo-org --json`

**Result:** SUCCESS (exit code 0)

### Step 4 — Publish agent

**Command:** `sf agent publish authoring-bundle --api-name Property_Showing_Scheduler -o tnd26-demo-org --json`

**First attempt:** FAILED — transient "Internal Error, try again later"
**Second attempt:** SUCCESS

```json
{
  "status": 0,
  "result": {
    "success": true,
    "botDeveloperName": "Property_Showing_Scheduler"
  }
}
```

### Step 5 — Activate agent

**Command:** `sf agent activate --api-name Property_Showing_Scheduler -o tnd26-demo-org --json`

**Result:** SUCCESS (exit code 0)

---

## Summary

| Step | Action | Result |
|------|--------|--------|
| 1 | Read Apex and Agent Script | Confirmed LLM hallucination of URL embedded in prose field |
| 2 | Add `eventLink` output field to Apex Response | Isolates URL from prose text |
| 3 | Add `event_link` variable and binding to Agent Script | Passes URL through as opaque merge field |
| 4 | Rewrite reasoning with anti-hallucination instructions | Explicit instruction to use URL verbatim |
| 5 | Add test assertions for `eventLink` | Validates correct URL path and event ID |
| 6 | Deploy Apex to org | 2 components, 0 errors |
| 7 | Run tests | 11/11 passed |
| 8 | Deactivate, publish, activate agent | All succeeded |

### Key Lessons

1. **LLMs treat URLs in prose as content to summarize** — embedding a URL inside a longer text field gives the model latitude to rewrite it, including hallucinating a completely different URL.
2. **Isolate opaque data in dedicated output fields** — by separating the URL into its own `eventLink` field, the Agent Script can reference it via a merge field (`{!@variables.event_link}`) that the LLM cannot modify.
3. **Construct the markdown link in the reasoning instructions** — building `[View Event]({!@variables.event_link})` in the Agent Script rather than in the Apex `confirmationMessage` means the URL is injected at render time, not passed through LLM generation.
4. **Anti-hallucination instructions help but are not sufficient alone** — the original "display it as-is" instruction was ignored. Combining structural isolation (dedicated field) with explicit instructions ("do not modify, shorten, or replace") is more robust.
