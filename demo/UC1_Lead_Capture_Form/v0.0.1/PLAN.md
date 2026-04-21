intent=app | best_matched_skill=sf-lwc | skill_selection=complete

Title: Lead Capture + House Suggestions LWC for Dreamhouse Home Page

Overview
Build a Lightning Web Component (LWC) that helps sales users capture leads for house searches directly from the Dreamhouse app&#39;s Home page. The component asks four questions, suggests properties that match, allows selecting up to three properties, and creates Lead records based on those selections.

User Questions (Inputs)
1) Which city or state are you looking?
2) How many bedrooms are you looking for?
3) What style of house are you looking for?
4) What price range are you looking for?

High-Level Design
- Component: lwc/leadHouseCapture
  - Purpose: 
    - Collect the four user inputs
    - Query Property__c for matching suggestions
    - Allow selection of up to three properties
    - Submit Leads for selected properties
  - Data Sources:
    - Property__c: existing Dreamhouse sample data
    - Apex controller to encapsulate search and lead creation
  - UI/UX:
    - Section 1: Questions
      - City or State: text input (optional typeahead in a future enhancement)
      - Bedrooms: number or picklist
      - House style: picklist (default options: Condo, Townhouse, Single Family, Multi Family)
      - Price range: min and max currency fields
    - Section 2: Suggested houses
      - Tile/Card list showing image (if available), price, beds, address (city, state), style
      - Checkbox or Select button, enforcing a maximum of 3 selections
    - Section 3: Submit
      - Creates one Lead per selected property (default approach)
      - Success/failure toasts

Data and Logic Details
- Search Logic (Property__c):
  - City/State:
    - If input resembles a state (abbrev/name), filter State__c
    - Else filter City__c
    - Fallback: LIKE on Address fields if needed
  - Bedrooms: Beds__c >= requested
  - Style: Style__c = selected (optional)
  - Price: Price__c BETWEEN min and max
  - Pagination: return first 25 (future enhancement: "Load more")
- Lead Creation:
  - One Lead per selected property (max 3)
  - Minimal required fields:
    - LastName = "House Inquiry"
    - Company = "Dreamhouse Prospect" (or another standard default)
  - Description includes:
    - User answers: city/state, bedrooms, style, price range
    - Selected property details: Name, Id, URL
  - Returns list of created Lead Ids mapped to property Ids

Implementation Plan
1) Apex Controller: LeadHouseCaptureController
   - @AuraEnabled(cacheable=true)
     - searchProperties(cityOrState, minBedrooms, style, minPrice, maxPrice) 
       - Returns lightweight DTO: Id, Name, Price__c, Beds__c, Style__c, City__c, State__c, ThumbnailUrl__c (if available)
   - @AuraEnabled
     - createLeadsForProperties(propertyIds, cityOrState, bedrooms, style, minPrice, maxPrice)
       - Inserts one Lead per property Id (max 3) with a standardized mapping
       - Returns result list with created Lead Ids and status
   - Unit Tests: LeadHouseCaptureControllerTest
     - Cover positive/negative search filters
     - Cover lead creation happy path and validation errors

2) LWC Bundle: leadHouseCapture
   - leadHouseCapture.html:
     - Form fields for the 4 questions
     - Result list area with select controls
     - Selection count indicator (max 3)
     - Submit button with disabled state when no selection
   - leadHouseCapture.js:
     - Imperative Apex calls for search and submit
     - Parse inputs and handle defaults
     - Selection state and max-3 enforcement
     - Toast notifications for success/error
     - Optional: debounce search input
   - leadHouseCapture.css:
     - SLDS layout and spacing
   - leadHouseCapture.js-meta.xml:
     - targets: lightning__AppPage, lightning__HomePage
     - isExposed: true

3) Placement
   - Add to Dreamhouse Home page:
     - If Home flexipage exists, place component there
     - Else create a new flexipage (Dreamhouse_Home) with a simple 1- or 2-column layout and add the component

Optional Enhancements (Future)
- Datalist/typeahead for City/State suggestions
- Saved preferences (local storage) to auto-fill next session
- More sophisticated style options: pull distinct values from Property__c
- Support picklist price ranges in addition to min/max
- Pagination or infinite scroll for suggestions

Assumptions
- Property__c contains fields like Price__c, Beds__c, Style__c, City__c, State__c consistent with Dreamhouse sample data.
- Lead creation requires only LastName and Company; remaining info fits in Description unless custom fields are specified.
- Suggesting 25 results initially is sufficient for sales workflow.

Decisions to Confirm
- Style options:
  - Use fixed list [Condo, Townhouse, Single Family, Multi Family] 
  - OR derive distinct values from Property__c.Style__c
- Price input:
  - Two currency fields (min and max) 
  - OR predefined ranges (e.g., <$250k, $250k–$500k, $500k–$1M, >$1M)
- Lead creation model:
  - Default: one Lead per selected property (max 3)
  - Alternative: single Lead referencing up to three properties in Description
- Placement:
  - Add to existing Dreamhouse Home page if present
  - Else create a new Home flexipage and add the component

Deliverables (when implemented)
- Apex:
  - force-app/main/default/classes/LeadHouseCaptureController.cls
  - force-app/main/default/classes/LeadHouseCaptureController.cls-meta.xml
  - force-app/main/default/classes/LeadHouseCaptureControllerTest.cls
  - force-app/main/default/classes/LeadHouseCaptureControllerTest.cls-meta.xml
- LWC:
  - force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.html
  - force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.js
  - force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.css
  - force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.js-meta.xml
- Flexipage (if needed):
  - force-app/main/default/flexipages/Dreamhouse_Home.flexipage-meta.xml (new) or edit existing Home page

Next Steps
- Upon approval, toggle to Act mode to implement:
  - Apex controller + tests
  - LWC bundle
  - Flexipage placement/update
  - Deploy and verify in org