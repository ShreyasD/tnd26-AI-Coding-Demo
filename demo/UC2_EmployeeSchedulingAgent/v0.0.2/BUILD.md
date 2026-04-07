# UC2: Property Name/Address Lookup Enhancement — Build Transcript (v0.0.2)

> **Mode:** Agent Mode (full implementation)
> **Date:** 2026-04-07
> **Target Org:** `tnd26-demo-org` (`sdhond@tnd26demo.com`)
> **Org URL:** https://trailsignup-499a6261e91e06.my.salesforce.com
> **Source Plan:** [PLANMODE_IMPLEMENTATION.md](PLANMODE_IMPLEMENTATION.md)
> **Branch:** `feature/property-name-lookup`

---

## Table of Contents

1. [Pre-Execution: Branch Setup](#pre-execution-branch-setup)
2. [Task 0: Plan Transcript](#task-0-plan-transcript)
3. [Task 1.1: Author PropertyLookupAction.cls](#task-11-author-propertylookupactioncls)
4. [Task 1.2: Author PropertyLookupActionTest.cls](#task-12-author-propertylookupactiontestcls)
5. [Task 1.3 + 2.1: Conversation Redesign and Agent Script Update](#task-13--21-conversation-redesign-and-agent-script-update)
6. [Task 3.1: Deploy, Test, and Validate](#task-31-deploy-test-and-validate)
7. [Task 3.2: Publish and Activate](#task-32-publish-and-activate)
8. [Task 4.1: Smoke Tests](#task-41-smoke-tests)
9. [Execution Summary](#execution-summary)

---

## Pre-Execution: Branch Setup

### Reasoning

The project branching strategy (`.cursor/rules/project-branching-strategy.mdc`) mandates that no file changes are made on `main` or `develop`. Must create a feature branch before any edits.

### Actions Taken

1. Checked current branch:
```bash
git branch --show-current
# Output: main
```

2. Created feature branch:
```bash
git checkout -b feature/property-name-lookup
# Output: Switched to a new branch 'feature/property-name-lookup'
```

3. Verified:
```bash
git branch --show-current
# Output: feature/property-name-lookup
```

---

## Task 0: Plan Transcript

### Role
`fde-strategist`

### Reasoning
The plan requires a `PLANMODE_IMPLEMENTATION.md` transcript documenting the entire planning conversation — problem statement, standard action evaluation, custom Apex rationale, architecture diagrams, subagent assignments, and constraints.

### Action
Created `demo/UC2_EmployeeSchedulingAgent/v0.0.2/PLANMODE_IMPLEMENTATION.md` with the full planning transcript.

### Result
File created with 10 sections covering the complete planning process from v0.0.1 analysis through v0.0.2 design.

---

## Task 1.1: Author PropertyLookupAction.cls

### Role
`ps-technical-architect`

### Reasoning
The plan specifies a new `@InvocableMethod` Apex class that searches `Property__c` by `Name`, `Address__c`, or `City__c` using `LIKE`. Key design decisions:

- **`with sharing`** — respects org sharing rules for the running employee
- **`global`** — required for `@InvocableMethod` visibility from Agent Script
- **All Response String fields initialized to `''`** — prevents the null-vs-empty-string bug discovered in v0.0.1
- **SOQL injection prevention** — `escapeLike()` method escapes `%`, `_`, `'` before building the LIKE term
- **Single SOQL query with OR** — searches Name, Address, and City in one query (1 SOQL per request)
- **LIMIT 10** — bounds results for governor limits and manageable disambiguation lists
- **Formatted matchList** — numbered list as a single String field since Agent Script cannot handle List outputs in mutable variables
- **`processRequest()` extracted** — keeps the bulk `findProperty()` method clean while handling per-request logic

### Action
Created `force-app/main/default/classes/PropertyLookupAction.cls`:

```java
global with sharing class PropertyLookupAction {
    global class Request {
        @InvocableVariable(required=true)
        public String searchTerm;
    }

    global class Response {
        @InvocableVariable
        public String propertyId = '';

        @InvocableVariable
        public String propertyName = '';

        @InvocableVariable
        public String propertyAddress = '';

        @InvocableVariable
        public Integer matchCount = 0;

        @InvocableVariable
        public String matchList = '';

        @InvocableVariable
        public String errorMessage = '';
    }

    @InvocableMethod(label='Find Property')
    global static List<Response> findProperty(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Response>();
        }

        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(processRequest(req));
        }
        return responses;
    }

    private static Response processRequest(Request req) {
        Response resp = new Response();
        if (req == null || String.isBlank(req.searchTerm)) {
            resp.errorMessage = 'A search term is required. Please provide a property name or address.';
            return resp;
        }

        String escapedTerm = '%' + escapeLike(req.searchTerm.trim()) + '%';
        List<Property__c> matches = [
            SELECT Id, Name, Address__c, City__c, State__c
            FROM Property__c
            WHERE Name LIKE :escapedTerm
               OR Address__c LIKE :escapedTerm
               OR City__c LIKE :escapedTerm
            ORDER BY Name ASC
            LIMIT 10
        ];

        resp.matchCount = matches.size();

        if (matches.isEmpty()) {
            resp.errorMessage = 'No properties found matching "' + req.searchTerm.trim()
                + '". Try a different name or address.';
            return resp;
        }

        if (matches.size() == 1) {
            Property__c p = matches[0];
            resp.propertyId = p.Id;
            resp.propertyName = p.Name;
            resp.propertyAddress = formatAddress(p);
            return resp;
        }

        List<String> lines = new List<String>();
        for (Integer i = 0; i < matches.size(); i++) {
            Property__c p = matches[i];
            lines.add((i + 1) + '. ' + p.Name + ' — ' + formatAddress(p));
        }
        resp.matchList = String.join(lines, '\n');
        return resp;
    }

    private static String formatAddress(Property__c p) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(p.Address__c)) {
            parts.add(p.Address__c);
        }
        if (String.isNotBlank(p.City__c)) {
            parts.add(p.City__c);
        }
        if (String.isNotBlank(p.State__c)) {
            parts.add(p.State__c);
        }
        return parts.isEmpty() ? '' : String.join(parts, ', ');
    }

    private static String escapeLike(String input) {
        return input.replaceAll('\'', '\\\\\'')
                    .replaceAll('%', '\\%')
                    .replaceAll('_', '\\_');
    }
}
```

Also created `PropertyLookupAction.cls-meta.xml` (API v66.0, Active).

### I/O Name Mapping

| Agent Script I/O Name | Apex @InvocableVariable Field | Type |
|------------------------|-------------------------------|------|
| `searchTerm` | `public String searchTerm` | Input |
| `propertyId` | `public String propertyId` | Output |
| `propertyName` | `public String propertyName` | Output |
| `propertyAddress` | `public String propertyAddress` | Output |
| `matchCount` | `public Integer matchCount` | Output |
| `matchList` | `public String matchList` | Output |
| `errorMessage` | `public String errorMessage` | Output |

---

## Task 1.2: Author PropertyLookupActionTest.cls

### Role
`ps-technical-architect`

### Reasoning
The plan requires 7+ test methods targeting 90%+ coverage. Created 11 test methods covering all code paths in `PropertyLookupAction`:

| Test Method | Code Path Covered |
|-------------|-------------------|
| `returnsExactNameMatch` | Single result via exact Name match |
| `returnsPartialNameMatch` | Single result via partial Name LIKE |
| `returnsAddressMatch` | Single result via Address__c LIKE |
| `returnsCityMatch` | Match via City__c LIKE |
| `returnsMultipleMatchesWithFormattedList` | 3 results, numbered matchList formatting |
| `returnsErrorWhenNoMatchesFound` | 0 results, errorMessage with search term |
| `returnsErrorWhenSearchTermIsBlank` | Blank string input, validation error |
| `returnsErrorWhenSearchTermIsNull` | Null input, validation error |
| `returnsEmptyListWhenRequestListIsNull` | Null request list, empty response |
| `returnsEmptyListWhenRequestListIsEmpty` | Empty request list, empty response |
| `formatsAddressWithMissingFields` | Property with no Address/City/State fields |

### Action
Created `force-app/main/default/classes/PropertyLookupActionTest.cls` with 11 test methods and a shared `createProperty()` helper.

Also created `PropertyLookupActionTest.cls-meta.xml` (API v66.0, Active).

---

## Task 1.3 + 2.1: Conversation Redesign and Agent Script Update

### Roles
`fde-experience-specialist` (conversation design) + `fde-engineer` (Agent Script authoring)

### Reasoning
Tasks 1.3 and 2.1 are tightly coupled — the conversation text lives inside the `.agent` file. Combined them into a single implementation step.

**Conversation changes:**
- **Welcome message:** Changed from "Which property would you like to schedule a showing for?" to "Tell me the property name or address and I will look it up for you."
- **System instructions:** Changed from "you need the property name or ID" to "ask for the property name or address — never ask for a Salesforce record ID"
- **Disambiguation prompt:** Added reasoning branch for `match_list != ""` that presents the numbered list and asks the user to pick
- **No-match prompt:** Added reasoning branch for `lookup_error != ""` that asks for a different name or address
- **Property-identified prompt:** Added reasoning branch for `property_id != "" and event_id == ""` that confirms the property and asks for date/time

**Agent Script changes:**
- **6 new variables:** `property_id`, `property_name`, `property_address`, `match_count`, `match_list`, `lookup_error`
- **New `find_property` action:** targets `apex://PropertyLookupAction`, `searchTerm` is `is_user_input: True`
- **`create_showing` input changed:** `propertyId` no longer has `is_user_input: True`; it is now variable-bound via `with propertyId = @variables.property_id`
- **Two reasoning tools:** `find_property_tool` (lookup) and `schedule_showing` (create event)
- **5 reasoning branches** (ordered by priority): scheduling error, scheduling success, lookup error, multiple matches, property identified

### Action
Rewrote `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent`.

**Before (v0.0.1 — 79 lines):**
- 1 action (`create_showing`)
- 3 variables (`event_id`, `confirmation_msg`, `error_msg`)
- `propertyId` as `is_user_input: True` — user must provide Salesforce record ID

**After (v0.0.2 — 132 lines):**
- 2 actions (`find_property` + `create_showing`)
- 9 variables (6 new for lookup state)
- `propertyId` bound from `@variables.property_id` — user provides name/address, agent resolves to ID

### Activation Checklist Verified
- [x] Exactly one `start_agent` block
- [x] No mixed tabs/spaces (consistent 2-space indent)
- [x] Booleans are `True` / `False`
- [x] No `else if` or nested `if`
- [x] No top-level `actions:` block
- [x] `agent_type: "AgentforceEmployeeAgent"` — explicit
- [x] No `default_agent_user`
- [x] `developer_name` matches bundle folder name (`Property_Showing_Scheduler`)
- [x] I/O names match `@InvocableVariable` field names exactly
- [x] `datetime` and `integer` used only in action I/O, not as variable types
- [x] Two-operand compound conditions only (`A and B`)

---

## Task 3.1: Deploy, Test, and Validate

### Role
`fde-qa-engineer`

### Step 1: Check Org Connection

```bash
sf org display --json
```

**Result:** Connected to `tnd26-demo-org`, username `sdhond@tnd26demo.com`, API v66.0.

### Step 2: Deploy New Apex Classes

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/PropertyLookupAction.cls \
  --source-dir force-app/main/default/classes/PropertyLookupAction.cls-meta.xml \
  --source-dir force-app/main/default/classes/PropertyLookupActionTest.cls \
  --source-dir force-app/main/default/classes/PropertyLookupActionTest.cls-meta.xml \
  --target-org tnd26-demo-org --json
```

**Result:**
```
Status: Succeeded
Components Deployed: 2 (PropertyLookupAction, PropertyLookupActionTest)
Component Errors: 0
Deploy ID: 0AfKj00002d4nPKKAY
```

### Step 3: Run PropertyLookupActionTest

```bash
sf apex run test \
  --class-names PropertyLookupActionTest \
  --target-org tnd26-demo-org \
  --result-format human \
  --code-coverage --wait 5
```

**Result:**
```
=== Test Results (11/11 Passed)
TEST NAME                                                         OUTCOME  RUNTIME (MS)
────────────────────────────────────────────────────────────────  ───────  ────────────
PropertyLookupActionTest.formatsAddressWithMissingFields          Pass     142
PropertyLookupActionTest.returnsAddressMatch                      Pass     27
PropertyLookupActionTest.returnsCityMatch                         Pass     31
PropertyLookupActionTest.returnsEmptyListWhenRequestListIsEmpty   Pass     5
PropertyLookupActionTest.returnsEmptyListWhenRequestListIsNull    Pass     5
PropertyLookupActionTest.returnsErrorWhenNoMatchesFound           Pass     14
PropertyLookupActionTest.returnsErrorWhenSearchTermIsBlank        Pass     5
PropertyLookupActionTest.returnsErrorWhenSearchTermIsNull         Pass     5
PropertyLookupActionTest.returnsExactNameMatch                    Pass     28
PropertyLookupActionTest.returnsMultipleMatchesWithFormattedList  Pass     65
PropertyLookupActionTest.returnsPartialNameMatch                  Pass     27

=== Apex Code Coverage
PropertyLookupAction: 100%

Pass Rate: 100%
Test Run Id: 707Kj0000GcOiuF
```

### Step 4: Run Existing PropertyShowingSchedulerActionTest (Regression)

```bash
sf apex run test \
  --class-names PropertyShowingSchedulerActionTest \
  --target-org tnd26-demo-org \
  --result-format human \
  --code-coverage --wait 5
```

**Result:**
```
=== Test Results (9/9 Passed)
PropertyShowingSchedulerAction: 90%
Pass Rate: 100%
Test Run Id: 707Kj0000GcOjXm
```

No regressions. All existing tests still pass.

### Step 5: Validate Agent Script Bundle

```bash
sf agent validate authoring-bundle \
  --api-name Property_Showing_Scheduler \
  --target-org tnd26-demo-org --json
```

**Result:**
```json
{
  "status": 0,
  "result": {
    "success": true
  }
}
```

---

## Task 3.2: Publish and Activate

### Role
`fde-release-engineer`

### Step 1: Publish Agent

```bash
sf agent publish authoring-bundle \
  --api-name Property_Showing_Scheduler \
  --target-org tnd26-demo-org --json
```

**Result:**
```json
{
  "status": 0,
  "result": {
    "success": true,
    "botDeveloperName": "Property_Showing_Scheduler"
  }
}
```

Elapsed time: ~60 seconds.

### Step 2: Activate Agent

```bash
sf agent activate \
  --api-name Property_Showing_Scheduler \
  --target-org tnd26-demo-org --json
```

**Result:** Exit code 0 — success.

### Step 3: Verify Version Status

```bash
sf data query -q "SELECT VersionNumber, Status FROM BotVersion
  WHERE BotDefinition.DeveloperName = 'Property_Showing_Scheduler'
  ORDER BY VersionNumber DESC LIMIT 5"
```

**Result:**
```
VERSIONNUMBER  STATUS
─────────────────────
6              Active
5              Inactive
4              Inactive
3              Inactive
2              Inactive
```

Version 6 is Active (v0.0.2 with property lookup).

---

## Task 4.1: Smoke Tests

### Role
`fde-qa-engineer`

### Reasoning
The `sf agent preview` command requires an interactive TTY and cannot be run from a non-interactive shell. Instead, ran smoke tests by executing the `PropertyLookupAction` directly via anonymous Apex against real org data, validating all three result branches (single match, multiple matches, no match) plus a partial name search.

### Step 1: List Properties in Org

```bash
sf data query -q "SELECT Id, Name, Address__c, City__c, State__c
  FROM Property__c ORDER BY Name LIMIT 15" --target-org tnd26-demo-org
```

**Result:** 12 properties in org (Boston and Cambridge, MA).

### Step 2: Run Smoke Tests via Anonymous Apex

```bash
sf apex run --target-org tnd26-demo-org
```

### Smoke Test 1: Search by Address — "Brattle St"

**Expected:** Single match (48 Brattle St is unique)

**Result:** PASSED
```
Match count: 1
Property ID: a08Kj00001PDHReIAP
Property Name: Heart of Harvard Square
Address: 48 Brattle St, Cambridge, MA
Error:
Match List:
```

### Smoke Test 2: Search by City — "Boston"

**Expected:** Multiple matches (8 Boston properties)

**Result:** PASSED
```
Match count: 8
Property ID:     (empty — disambiguation needed)
Error:           (empty)
Match List:
1. Architectural Details — 95 Gloucester St, Boston, MA
2. City Living — 127 Endicott St, Boston, MA
3. Contemporary City Living — 640 Harrison Ave, Boston, MA
4. Contemporary Luxury — 145 Commonwealth Ave, Boston, MA
5. Modern City Living — 72 Francis St, Boston, MA
6. Quiet Retreat — 448 Hanover St, Boston, MA
7. Seaport District Retreat — 121 Harborwalk, Boston, MA
8. Waterfront in the City — 110 Baxter Street, Boston, MA
```

### Smoke Test 3: No Match — "Nonexistent Galaxy Property XYZ"

**Expected:** 0 matches, error message returned

**Result:** PASSED
```
Match count: 0
Error: No properties found matching "Nonexistent Galaxy Property XYZ". Try a different name or address.
```

### Smoke Test 4: Search by Partial Name — "Heart of Harvard"

**Expected:** Single match via partial Name LIKE

**Result:** PASSED
```
Match count: 1
Property ID: a08Kj00001PDHReIAP
Property Name: Heart of Harvard Square
Address: 48 Brattle St, Cambridge, MA
```

### Governor Limit Usage (All 4 Tests Combined)

```
Number of SOQL queries: 4 out of 100
Number of query rows: 10 out of 50000
Number of DML statements: 0 out of 150
Maximum CPU time: 0 out of 10000
```

Well within all governor limits.

---

## Execution Summary

### Files Created

| File | Role |
|------|------|
| `force-app/main/default/classes/PropertyLookupAction.cls` | `ps-technical-architect` |
| `force-app/main/default/classes/PropertyLookupAction.cls-meta.xml` | `ps-technical-architect` |
| `force-app/main/default/classes/PropertyLookupActionTest.cls` | `ps-technical-architect` |
| `force-app/main/default/classes/PropertyLookupActionTest.cls-meta.xml` | `ps-technical-architect` |
| `demo/UC2_EmployeeSchedulingAgent/v0.0.2/PLANMODE_IMPLEMENTATION.md` | `fde-strategist` |
| `demo/UC2_EmployeeSchedulingAgent/v0.0.2/BUILD.md` | `fde-strategist` |

### Files Modified

| File | Role | Change |
|------|------|--------|
| `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent` | `fde-engineer` | Added `find_property` action, 6 new variables, lookup-first reasoning flow, `propertyId` now variable-bound |

### Test Results

| Test Class | Tests | Passed | Coverage |
|-----------|-------|--------|----------|
| PropertyLookupActionTest | 11 | 11 (100%) | 100% on PropertyLookupAction |
| PropertyShowingSchedulerActionTest | 9 | 9 (100%) | 90% on PropertyShowingSchedulerAction |

### Agent Status

```
Agent:   Property_Showing_Scheduler
Label:   Property Showing Scheduler
Version: 6
Status:  Active
```

### Smoke Test Results

| # | Test | Search Term | Expected | Result |
|---|------|------------|----------|--------|
| 1 | Address search | "Brattle St" | Single match | PASSED — Heart of Harvard Square |
| 2 | City search | "Boston" | Multiple matches | PASSED — 8 properties, numbered list |
| 3 | No match | "Nonexistent Galaxy Property XYZ" | Error message | PASSED — "No properties found..." |
| 4 | Partial name | "Heart of Harvard" | Single match | PASSED — Heart of Harvard Square |

### Task Execution Order (Actual)

```
0. Branch setup: feature/property-name-lookup                    [pre-execution]
1. Task 0: Write PLANMODE_IMPLEMENTATION.md                      [fde-strategist]
2. Task 1.1: Author PropertyLookupAction.cls                     [ps-technical-architect]
3. Task 1.2: Author PropertyLookupActionTest.cls                 [ps-technical-architect]
4. Task 1.3 + 2.1: Update .agent file (conversation + script)    [fde-experience-specialist + fde-engineer]
5. Task 3.1: Deploy Apex to org                                  [fde-qa-engineer]       → SUCCESS
6. Task 3.1: Run PropertyLookupActionTest (11/11, 100%)          [fde-qa-engineer]       → PASSED
7. Task 3.1: Run PropertyShowingSchedulerActionTest (9/9, 90%)   [fde-qa-engineer]       → PASSED (regression)
8. Task 3.1: Validate agent script                               [fde-qa-engineer]       → PASSED
9. Task 3.2: Publish agent                                       [fde-release-engineer]  → SUCCESS (Version 6)
10. Task 3.2: Activate agent                                     [fde-release-engineer]  → SUCCESS (Version 6 Active)
11. Task 4.1: Smoke tests (4 scenarios)                          [fde-qa-engineer]       → ALL PASSED
```

### How to Use the Updated Agent

The agent is live at: **https://trailsignup-499a6261e91e06.my.salesforce.com**

1. Log in as `sdhond@tnd26demo.com`
2. Open the Agentforce panel (Astro icon in the utility bar)
3. Try: *"Schedule a showing for the property on Brattle Street"*
4. The agent will find "Heart of Harvard Square" at 48 Brattle St, Cambridge, MA
5. Then ask for a date and time to complete the scheduling

**What's different from v0.0.1:**
- You no longer need to provide a Salesforce record ID
- Just say the property name, street address, or city
- If multiple properties match, the agent shows a numbered list for you to pick from
- If no properties match, the agent asks you to try a different search term
