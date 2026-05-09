# Lead Capture Form v0.0.3 - Plan

## Overview
Version 0.0.3 focuses on bug fixes and enhancements to the lead capture functionality, including UX improvements for property selection and proper data linking.

## Objectives

### 1. Fix Property Linking Issue
**Problem**: Leads were being created but not linked to the selected property
**Solution**: Update the Apex controller to properly set the `Property__c` lookup field when creating leads

### 2. Improve House Selection UX
**Problem**: Button state was not intuitive - users couldn't tell which house was selected
**Solution**: 
- Change button label from "Select" to "Selected" when a house is chosen
- Update button variant from "brand" (blue) to "success" (green) for selected state
- Add checkmark icon to selected state
- Use LWC template directives (`if:true`/`if:false`) instead of ternary operators

### 3. Update Lead Default Values
**Requirements**:
- Set default Lead Status to "New" (instead of "Open - Not Contacted")
- Set default Lead Source to "Marketing Event"

### 4. Enhance Lead Page Layout
**Requirement**: Add Description field to Lead page layout for better visibility of captured preferences and property details

## Technical Approach

### Components to Modify

1. **LeadHouseCaptureController.cls** (Apex)
   - Add `l.Property__c = pid` to link lead to property
   - Change `l.Status = 'New'`
   - Add `l.LeadSource = 'Marketing Event'`

2. **leadHouseCapture.html** (LWC Template)
   - Replace ternary operators with `if:true` and `if:false` template blocks
   - Create separate templates for selected and unselected button states

3. **Lead-Lead Layout.layout-meta.xml** (Metadata)
   - Add Description field to the right column of the Lead Information section
   - Maintain all existing fields in their current positions

## Implementation Steps

1. ✅ Analyze the current implementation and identify issues
2. ✅ Fix the Apex controller to properly link properties
3. ✅ Update button UX with conditional templates
4. ✅ Update lead default status and source values
5. ✅ Add Description field to lead layout
6. ✅ Deploy changes to org
7. ✅ Document changes in BUILD.md

## Success Criteria

- [x] Leads are properly linked to selected properties via Property__c lookup
- [x] Button clearly indicates selected state with green color and checkmark
- [x] Users can deselect a property by clicking "Selected" button
- [x] New leads have Status = "New" and LeadSource = "Marketing Event"
- [x] Description field is visible on Lead record page
- [x] All changes deployed successfully to org

## Notes

- Used proper LWC patterns with `if:true`/`if:false` instead of template expressions
- SOQL query in createLeadsForProperties fetches property details for building description only
- Description field placement: right column, between LeadSource and OwnerId