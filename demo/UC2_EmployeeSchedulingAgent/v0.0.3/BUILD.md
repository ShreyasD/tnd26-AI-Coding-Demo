# Build Transcript — v0.0.3: Lead-to-Property Showing Agent Enhancement

## Pre-Build Setup

### Branch Creation

On `main` — created feature branch per branching rules:

```
git checkout -b feature/lead-property-showing-agent
```

Confirmed on `feature/lead-property-showing-agent`.

### Task List

| # | Task | Status |
|---|------|--------|
| 1 | Create Lead.Property__c lookup field metadata XML | Completed |
| 2 | Create Lead-Lead Layout.layout-meta.xml with Property__c field | Completed |
| 3 | Create LeadLookupAction.cls invocable Apex class | Completed |
| 4 | Create LeadLookupActionTest.cls with PNB coverage | Completed |
| 5 | Update PropertyShowingSchedulerAction confirmation to include clickable Event link | Completed |
| 6 | Update Property_Showing_Scheduler.agent with find_lead topic and routing | Completed |
| 7 | Update both permission sets for Lead access and new Apex class | Completed |
| 8 | Run linter checks on all created/modified files | Completed |

---

## Step 1: Create `Lead.Property__c` Lookup Field

Created directory `force-app/main/default/objects/Lead/fields/`.

**File**: `force-app/main/default/objects/Lead/fields/Property__c.field-meta.xml`

- Type: `Lookup(Property__c)`
- Label: "Property"
- Relationship name: `Leads`
- Delete constraint: `SetNull`
- Required: `false`

---

## Step 2: Create Lead Layout

**File**: `force-app/main/default/layouts/Lead-Lead Layout.layout-meta.xml`

Sections:
- **Lead Information** (two-column): Name (required), Company (required), Email, Phone, Property__c (left); Status (required), Title, LeadSource, Owner (right)
- **Address** (two-column): Compound `Address` field
- **System Information** (two-column): CreatedBy, LastModifiedBy

### Layout Fix — Deployment Errors

Two issues encountered during deploy:

1. **`Field:Status must be Required`** — Changed `Status` field behavior from `Edit` to `Required`.
2. **`Cannot use field:Street in a layout`** — `Street`, `City`, `State`, `PostalCode` are compound address subfields that can't be placed individually on a Lead layout. Replaced with the compound `Address` field.

---

## Step 3: Create `LeadLookupAction.cls`

**Files**:
- `force-app/main/default/classes/LeadLookupAction.cls`
- `force-app/main/default/classes/LeadLookupAction.cls-meta.xml` (API v66.0)

### Design

- `@InvocableMethod(label='Find Lead')`
- `global with sharing class` — follows existing `PropertyLookupAction` pattern
- All Response fields initialized to `''` or `0` to avoid null-vs-empty-string Agent Script issues

### Input

| Field | Type | Required |
|-------|------|----------|
| `searchTerm` | String | Yes |

### Outputs

| Field | Type | Description |
|-------|------|-------------|
| `leadId` | String | Matched lead ID (single match only) |
| `leadName` | String | Matched lead name |
| `propertyId` | String | Auto-resolved from `Lead.Property__c` |
| `propertyName` | String | From `Property__r.Name` |
| `propertyAddress` | String | Formatted from `Property__r.Address__c`, `City__c`, `State__c` |
| `matchCount` | Integer | Number of matches found |
| `matchList` | String | Numbered list for disambiguation |
| `errorMessage` | String | Error details |

### Logic

1. SOQL: `SELECT Id, Name, Property__c, Property__r.Name, Property__r.Address__c, Property__r.City__c, Property__r.State__c FROM Lead WHERE Name LIKE :escapedTerm ORDER BY Name ASC LIMIT 10`
2. Single match with property → populate all fields
3. Single match without property → set errorMessage ("does not have a property assigned")
4. Multiple matches → build numbered list with lead name + property info
5. No matches → set errorMessage

---

## Step 4: Create `LeadLookupActionTest.cls`

**Files**:
- `force-app/main/default/classes/LeadLookupActionTest.cls`
- `force-app/main/default/classes/LeadLookupActionTest.cls-meta.xml` (API v66.0)

### Test Methods (9 total — PNB pattern)

| Method | Category | Description |
|--------|----------|-------------|
| `returnsSingleMatchWithProperty` | Positive | Lead with assigned property — verifies all output fields |
| `returnsSingleMatchWithoutProperty` | Negative | Lead without property — verifies error message |
| `returnsMultipleMatchesWithFormattedList` | Positive | 3 leads matching — verifies numbered list, "No property" label |
| `returnsErrorWhenNoMatchesFound` | Negative | No matching leads — verifies error message |
| `returnsErrorWhenSearchTermIsBlank` | Negative | Blank input — verifies validation |
| `returnsErrorWhenSearchTermIsNull` | Negative | Null input — verifies validation |
| `returnsEmptyListWhenRequestListIsNull` | Bulk/Edge | Null request list — verifies empty response |
| `returnsEmptyListWhenRequestListIsEmpty` | Bulk/Edge | Empty request list — verifies empty response |
| `formatsAddressWithMissingPropertyFields` | Edge | Property with no address fields — verifies empty address string |

---

## Step 5: Update `PropertyShowingSchedulerAction.cls` — Clickable Event Link

**File**: `force-app/main/default/classes/PropertyShowingSchedulerAction.cls`

Changed confirmation message from:

```apex
resp.confirmationMessage = 'Created event ' + resp.eventId + '.';
```

To:

```apex
String baseUrl = URL.getOrgDomainURL().toExternalForm();
resp.confirmationMessage = 'Property showing scheduled! '
    + '[View Event](' + baseUrl + '/lightning/r/Event/' + resp.eventId + '/view)';
```

This produces a markdown-style link that Agentforce renders as clickable in the chat panel. Existing tests are unaffected — none assert on the exact confirmation message text.

---

## Step 6: Update Agent Script — `Property_Showing_Scheduler.agent`

**File**: `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent`

### Changes

1. **Updated `agent_description`** and **`system.instructions`** to describe both workflows
2. **Updated welcome message** to mention both property and lead paths
3. **Added variables**: `lead_id`, `lead_name`
4. **Removed variable**: `match_count` (unused in reasoning conditionals; `integer` output type incompatible with `mutable string` variable)
5. **Updated `start_agent`** with dual routing:
   - `go_schedule_by_property` → `@topic.schedule_showing`
   - `go_schedule_by_lead` → `@topic.schedule_showing_for_lead`
6. **Existing `schedule_showing` topic** — preserved as-is (with updated confirmation message rendering instruction)
7. **New `schedule_showing_for_lead` topic** with:
   - `find_lead` action → `apex://LeadLookupAction`
   - `create_showing_for_lead` action → `apex://PropertyShowingSchedulerAction`
   - Reasoning instructions for: lead disambiguation, lead-without-property errors, property auto-resolution confirmation, clickable event link display

### Agent Script Fixes During Build

**Linter error**: `matchCount` typed as `integer` in action output but assigned to `match_count` (type `string`) variable.
- Initial fix: changed action output type to `string` — satisfied local linter
- **Publish rejected**: `sf agent publish` requires action output types to match the actual Apex InvocableVariable types
- Final fix: reverted `matchCount` to `integer`, removed `match_count` variable entirely (not used in any conditional), removed `set @variables.match_count` from both action bindings

---

## Step 7: Update Permission Sets

### `dreamhouse.permissionset-meta.xml`

Added:
- `fieldPermissions` for `Lead.Property__c` (editable + readable)

### `Employee_Scheduling_Agent_Access.permissionset-meta.xml`

Added:
- `classAccesses` for `LeadLookupAction` (enabled)
- `classAccesses` for `PropertyLookupAction` (enabled)
- `fieldPermissions` for `Lead.Property__c` (read-only)
- `objectPermissions` for `Lead` (read-only)

---

## Step 8: Linter Checks

Ran `ReadLints` on all 8 created/modified files. Results:
- **Initial**: 2 errors in agent script — `matchCount` type mismatch (see Step 6 fixes)
- **After fix**: 0 errors across all files

---

## Deployment

### Target Org

- **Alias**: `tnd26-demo-org`
- **Username**: `sdhond@tnd26demo.com`
- **Instance**: `trailsignup-499a6261e91e06.my.salesforce.com`

### Phase 1: Dry-Run Validation (Full Source)

```
sf project deploy start --dry-run --source-dir force-app --target-org tnd26-demo-org --wait 30 --json
```

**Result**: Failed with 5 component errors:
- `Lead-Lead Layout` — `Field:Status must be Required` (new — fixed)
- `GenAiPlannerBundle v6` — `Cannot update record as Agent is Active` (pre-existing)
- `Property_Scheduling_Assistant v1` — `Required fields are missing: [PlannerId]` (pre-existing)
- `Property_Showing_Scheduler v6` — `Can't edit an active bot version` (pre-existing)
- `Agent authoring bundle` — `content cannot be changed once the bundle version is published` (expected — requires `sf agent publish`)

### Phase 2: Deploy Field, Apex, Permission Sets

```
sf project deploy start \
  --metadata "CustomField:Lead.Property__c" \
  --metadata "ApexClass:LeadLookupAction" \
  --metadata "ApexClass:LeadLookupActionTest" \
  --metadata "ApexClass:PropertyShowingSchedulerAction" \
  --metadata "PermissionSet:dreamhouse" \
  --metadata "PermissionSet:Employee_Scheduling_Agent_Access" \
  --target-org tnd26-demo-org --wait 30 --json
```

**Result**: 6/6 succeeded. `Lead.Property__c` created, Apex classes created/updated, permission sets updated.

### Phase 3: Deploy Layout (Depends on Field)

```
sf project deploy start --metadata "Layout:Lead-Lead Layout" --target-org tnd26-demo-org --wait 30 --json
```

**Result**: 1/1 succeeded. Layout created.

### Phase 4: Publish Agent Script

```
sf agent publish authoring-bundle --api-name Property_Showing_Scheduler -o tnd26-demo-org --json
```

**First attempt** failed: `matchCount` output type mismatch (see Step 6 fix). After fixing, second attempt succeeded.

**Result**: Published successfully as new version (v7).

### Phase 5: Activate Agent

```
sf agent activate --api-name Property_Showing_Scheduler -o tnd26-demo-org
```

**Result**: Activated.

---

## Test Results

```
sf apex run test --class-names LeadLookupActionTest --class-names PropertyShowingSchedulerActionTest --class-names PropertyLookupActionTest --result-format human --wait 5 -o tnd26-demo-org
```

```
=== Test Summary
NAME                 VALUE
───────────────────  ────────────────────
Outcome              Passed
Tests Ran            29
Pass Rate            100%
Fail Rate            0%
Test Run Id          707Kj0000GdvQ5Z
Test Execution Time  1846 ms
Org Id               00DKj00000rCnrBMAS
Username             sdhond@tnd26demo.com
```

### Breakdown

| Test Class | Methods | Result |
|------------|---------|--------|
| `LeadLookupActionTest` | 9 | All passed |
| `PropertyShowingSchedulerActionTest` | 9 | All passed |
| `PropertyLookupActionTest` | 11 | All passed |

---

## Files Changed/Created Summary

| Action | File |
|--------|------|
| Created | `force-app/main/default/objects/Lead/fields/Property__c.field-meta.xml` |
| Created | `force-app/main/default/layouts/Lead-Lead Layout.layout-meta.xml` |
| Created | `force-app/main/default/classes/LeadLookupAction.cls` |
| Created | `force-app/main/default/classes/LeadLookupAction.cls-meta.xml` |
| Created | `force-app/main/default/classes/LeadLookupActionTest.cls` |
| Created | `force-app/main/default/classes/LeadLookupActionTest.cls-meta.xml` |
| Edited | `force-app/main/default/classes/PropertyShowingSchedulerAction.cls` |
| Edited | `force-app/main/default/permissionsets/dreamhouse.permissionset-meta.xml` |
| Edited | `force-app/main/default/permissionsets/Employee_Scheduling_Agent_Access.permissionset-meta.xml` |
| Edited | `force-app/main/default/aiAuthoringBundles/Property_Showing_Scheduler/Property_Showing_Scheduler.agent` |
| Created | `demo/UC2_EmployeeSchedulingAgent/v0.0.3/PLAN.md` |
