# Event creation parameters for leads and properties
_Exported on 4/21/2026 at 17:23:34 EDT from Cursor (3.0.16)_

---

**User**

Feature: Change event creation to add Lead as WhatId, Broker Contact as WhoId, and a new lookup for Property. Also ensure  subject includes Lead Name and Property Name in format "Property Showing - <Lead Name> (<Property Name>)" and Location field has the property address. 

**Use the agents definitions in the agents folder** to create role specific to dos 

---

**Cursor**

I’m mapping this change before proposing an implementation plan. First I’m checking the relevant Agent Script guidance and the current scheduling action/agent definitions so I can scope the event field changes and the “role-specific todos” part accurately.

I found the current event logic and the repo’s role-definition pattern. One important constraint surfaced before I can write an accurate plan: standard Salesforce `Event.WhatId` cannot point to a `Lead`, so I need your intent on how you want that relationship represented.

**Clarify Event Relationship Mapping**

> **For the event's Lead relationship, which implementation do you want?**
> - Use standard Salesforce fields: Lead on `WhoId`, Broker Contact via `EventRelation`, plus new custom Property lookup field ✔
> - Create/use a custom Lead lookup on Event, keep Broker Contact on `WhoId`, plus new custom Property lookup field
> - I want a different mapping; I’ll describe it

> **What do you want for the role-specific todos from the `agents` folder?**
> - Include role-specific todos in the implementation plan only ✔
> - Include them in the plan and also propose a markdown task breakdown artifact
> - Skip the role-based breakdown and just plan the feature change

The mapping is clear now: plan around `Lead` on standard `WhoId`, `Broker Contact` as an additional attendee via `EventRelation`, and a custom Property lookup on `Event`. I’m checking whether that custom field or nearby tests already exist so the plan can be specific instead of speculative.

I confirmed there isn’t already an `Event`-level custom property lookup in metadata, and there is an existing `PropertyShowingSchedulerActionTest` to extend rather than invent a new testing pattern. I’m pulling that test file now so the plan can call out the right coverage points.

I have enough context to turn this into a concrete build plan. I’m structuring it by the repo’s role definitions so the implementation steps, dependencies, and test coverage are explicit before any code changes happen.

---

**User**

Property Showing Event Remap Plan

Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself.

To-do's from the plan have already been created. Do not create them again. Mark them as in_progress as you work, starting with the first one. Don't stop until you have completed all the to-dos.

---

**Cursor**

I’m moving from the approved plan into implementation now. First I’ll verify the current branch, create a feature branch if needed, and then start the first todo with the new `Event` property lookup metadata.

The repo is on `main`, so I need to branch before touching files. Next I’m creating a feature branch and then I’ll inspect the existing metadata patterns for custom fields and permission sets to add the new `Event` lookup cleanly.

I’ve confirmed the repo already has the `Lead.Property__c` field and both relevant permission sets. Next I’m wiring in the matching `Event.Property__c` metadata and permission entries so the action refactor can target a real field instead of `WhatId`.

I’ve confirmed there’s no existing `Event` metadata folder or Event field permissions in the repo, so this is a net-new platform addition. I’m creating that metadata now, then I’ll move directly into the Apex refactor that consumes it.

I’ve got the implementation shape pinned down now. I’m editing five files: the new `Event` field metadata, both permission sets, the Apex action, the agent definition, and the existing Apex test so the behavior is verified end to end.

The code edits are in place. I’m reviewing the updated Apex and tests for consistency now, then I’ll run targeted validation so I can catch any compile or metadata issues before closing out the remaining todos.

The implementation reads cleanly, and I’ve shifted from metadata setup into validation. I’m marking the first todo done, moving through the refactor/test todos, and checking diagnostics on the edited files before attempting any runnable verification.

The edits are lint-clean and scoped to the expected files. I’m doing one last deploy/test feasibility check now so I can close the final todo with real validation status rather than guessing.

The Salesforce CLI check hit a local permission issue from sandboxed logging, not a project problem. I’m rerunning that outside the sandbox so I can see whether a default org is configured and whether a targeted validation command is actually possible here.

The local project has `agVibeDemoOrg` configured, but the deploy preview command didn’t pick it up automatically, so I’m retrying with the org specified explicitly. If that works, I’ll also try the focused Apex test for the scheduler class.

---

**User**

Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself.

To-do's from the plan have already been created. Do not create them again. Mark them as in_progress as you work, starting with the first one. Don't stop until you have completed all the to-dos.

use tnd26-cursor-demo org

---

**Cursor**

I hit a CLI targeting mismatch during validation, and your note resolves it. I’m rerunning the Salesforce checks against the `tnd26-cursor-demo` org explicitly, then I’ll finish the remaining todo statuses based on those results.

The alias `tnd26-cursor-demo` isn’t authorized locally; the CLI suggests the available alias is `tnd26-demo-org`. I’m using that org for validation so I can finish the implementation and close the last todo with an actual deployment preview result.

The org is reachable, but `deploy preview` isn’t supported there because it isn’t source-tracked. I’m switching to a dry-run metadata deploy against `tnd26-demo-org`, which is the right validation path for a non-source-tracked org.

The dry-run deploy is running now with the Apex test class included. I’m polling the result and will finish the todo list as soon as I have the validation outcome.

The dry-run finished with a failure, so I’m reading the final deployment output now to isolate whether it’s from the new Event field metadata, the Apex changes, or the test method.

The dry-run surfaced a real platform issue: Salesforce is rejecting `Event.Property__c` as object-level metadata, which means custom activity fields in this org need to be modeled differently than I first wired them. I’m confirming the correct metadata target now and then I’ll patch the field references so the deploy can compile cleanly.

I confirmed the metadata-side fix: custom activity fields in Salesforce are defined on `Activity`, not directly on `Event`, and permission sets reference them as `Activity.<FieldName>__c`. I’m correcting the metadata/FLS now; the Apex can still target the field on `Event` once the shared activity field exists.

The metadata target is fixed. I’m rerunning lints and the dry-run deploy against `tnd26-demo-org` using the `Activity` metadata path so I can verify the Apex now compiles against the shared activity field.

The second dry-run is in flight now with the corrected `Activity` field metadata. I’m polling for the final deploy/test result and then I’ll close out all remaining todos.

The dry-run succeeded this time. I’m pulling the deploy summary now so I can confirm the test result and then mark every remaining todo complete.

The metadata dry-run succeeded, but Salesforce didn’t actually execute the specified Apex test in that dry-run path. I’m running `PropertyShowingSchedulerActionTest` directly in `tnd26-demo-org` so the testing todo is backed by a real test result, not just deployment validation.

I’ve finished the implementation work itself. The only wrinkle in verification is that running the Apex test in the org exercised the org’s currently deployed test class, not the un-deployed local edits, so it still reported the old broker/lead assertions; the dry-run deploy is the validation that the updated local code compiles cleanly together.

Implemented the plan on `feature/property-showing-event-remap`.

The main change is in `PropertyShowingSchedulerAction.cls`: events now put the lead on `WhoId`, store the property in a new shared activity lookup field `Activity.Property__c`, derive `Location` from the property address, and generate subjects as `Property Showing - <Lead Name> (<Property Name>)` when a lead is present, with a property-only fallback of `Property Showing (<Property Name>)`. Broker contacts are no longer put on `WhoId`; they’re added as `EventRelation` records instead. I also updated `Property_Showing_Scheduler.agent` so its action descriptions match the new field mapping and auto-generated subject/location behavior.

On the metadata side, I added `force-app/main/default/objects/Activity/fields/Property__c.field-meta.xml` and updated both permission sets to grant FLS on `Activity.Property__c`. I also expanded `PropertyShowingSchedulerActionTest.cls` to assert the new mapping, subject, location, and related-contact behavior.

Verification: `ReadLints` reported no issues, and a dry-run deploy to `tnd26-demo-org` succeeded. I also ran `sf apex run test` against that org, but those results reflect the org’s currently deployed test class rather than the un-deployed local edits, so the failures there are from the old assertions, not the updated local file. If you want, I can deploy these changes to `tnd26-demo-org` next and rerun the Apex test there.

