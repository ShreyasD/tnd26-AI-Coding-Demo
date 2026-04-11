# UC1 Lead Capture Form — Build Transcript (v0.0.1)

This document records the end-to-end build transcript, including file edits and deployment attempts for the Lead House Capture LWC, Apex controller, and related metadata. FlexiPage deployment was intentionally excluded per instruction.

Date/Time (Local): 2026-04-11

## Summary

- Implemented and refined LWC `leadHouseCapture` template to remove forbidden expressions and function calls in attributes
- Introduced computed getter for submit state and per-item selection disable flags
- Deployed Apex controller `LeadHouseCaptureController` and tests
- Successfully deployed updated LWC bundle
- Iterated on FlexiPage metadata (multiple template/region variants) but ultimately excluded FlexiPage from deployment per user instruction

---

## Detailed Transcript

### 1) LWC HTML Update

File: `force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.html`

Key changes:
- Replaced inline expressions and function calls with properties/getters
- Submit button disabled bound to `{isSubmitDisabled}`
- Per-item Select button disabled bound to `{prop.selectDisabled}`

Final saved content excerpt:
```
<lightning-button
    variant="brand"
    label="Submit Leads"
    title="Submit Leads"
    onclick={handleSubmit}
    disabled={isSubmitDisabled}
></lightning-button>
...
<lightning-button
    data-id={prop.id}
    label="Select"
    onclick={toggleSelect}
    disabled={prop.selectDisabled}
></lightning-button>
```

Result:
- Saved successfully.

### 2) Initial LWC Deploy Attempt — Failure Due to Missing Apex

Attempted deploy:
- Source: `force-app/main/default/lwc/leadHouseCapture`

Deployment result: FAILED  
Error (condensed):
- Unable to find Apex action class referenced as `LeadHouseCaptureController`.

Resolution plan:
- Deploy Apex class and test first.

### 3) Deploy Apex Controller and Test

Sources:
- `force-app/main/default/classes/LeadHouseCaptureController.cls`
- `force-app/main/default/classes/LeadHouseCaptureController.cls-meta.xml`
- `force-app/main/default/classes/LeadHouseCaptureControllerTest.cls`
- `force-app/main/default/classes/LeadHouseCaptureControllerTest.cls-meta.xml`

Deployment result: SUCCEEDED  
- ApexClass: LeadHouseCaptureController (created)
- ApexClass: LeadHouseCaptureControllerTest (created)

### 4) Re-deploy LWC Bundle

Sources:
- `force-app/main/default/lwc/leadHouseCapture`

Deployment result: SUCCEEDED  
- LightningComponentBundle: leadHouseCapture (updated)

### 5) FlexiPage Authoring Iterations (Not Deployed)

Goal:
- Reference `c:leadHouseCapture` on a home/app page.

Edits attempted in `force-app/main/default/flexipages/Dreamhouse_Home.flexipage-meta.xml`:
- Corrected component reference from `c__leadHouseCapture` to `c:leadHouseCapture`.
- Adjusted regions to match template expectations; multiple templates tested:
  - `home:desktopTemplate`
  - `flexipage:appHomeTemplateHeaderAndOneRegion`
  - `flexipage:appHomeTemplateHeaderAndThreeColumns`
  - `flexipage:appHomeTemplateHeaderAndLeftRightRegions`
  - `flexipage:appHomeTemplateHeaderAndThreeRegions`

Observed errors (condensed over attempts):
- Region mismatch messages (e.g., `'header' region doesn't exist`, `'left' region doesn't exist`)
- Template not found messages (e.g., `Template flexipage:appHomeTemplateHeaderAnd… doesn't exist`)
- Mixed item instance constraint (`An ItemInstance can contain a componentInstance or a fieldInstance, but not both.`) — addressed by removing empty `itemInstances` in non-target regions.

Outcome:
- Per instruction “Leave the flexipage and deploy everything else,” FlexiPage was excluded from deployment.

Note:
- The final on-disk state reflects the last edited template/regions, but it has not been deployed.

### 6) Final Deployment — Everything Except FlexiPage

Sources included:
- LWC: `force-app/main/default/lwc/leadHouseCapture`
- Apex: `LeadHouseCaptureController*` (class + test)

Deployment result: SUCCEEDED  
- 3 components deployed (Apex already present; LWC updated)

---

## Current State

Deployed in org:
- Apex: `LeadHouseCaptureController`, `LeadHouseCaptureControllerTest`
- LWC: `leadHouseCapture` (updated template logic, proper disabled bindings)

Not deployed:
- `Dreamhouse_Home.flexipage-meta.xml` (left out intentionally)

---

## Next Steps (Optional)

- Decide on a supported FlexiPage template available in the target org.
- Align `<flexiPageRegions>` with the template’s exact region names.
- Deploy the finalized FlexiPage and assign it to desired apps/profiles as needed.
- Add `leadHouseCapture` to a Lightning App Builder page for manual verification:
  - Confirm “Search”/“Clear” buttons work
  - Property selection enables/disables correctly
  - Submit button disabled until valid selections