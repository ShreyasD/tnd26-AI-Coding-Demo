# Lead Capture Form - Multi-Screen Enhancement Plan
**Version**: 0.0.2  
**Date**: April 18, 2026  
**Status**: ✅ Completed

## Overview
Enhanced the leadHouseCapture LWC component to be a multi-screen form with comprehensive contact information capture and validation. The form now collects required contact details (First Name, Last Name, Email/Phone) before allowing users to search and select properties.

## Requirements

### Functional Requirements
1. **Multi-Screen Form**: Split the existing single-screen form into two screens
   - Screen 1: Contact Information
   - Screen 2: Property Preferences & Search (existing functionality)

2. **Contact Information Fields** (Screen 1):
   - First Name (required)
   - Last Name (required)
   - Email (conditionally required)
   - Phone (conditionally required)
   - At least one of Email OR Phone must be provided

3. **Validation Rules**:
   - First Name: Cannot be blank
   - Last Name: Cannot be blank
   - Email OR Phone: At least one must be filled
   - Email: If provided, must be valid email format
   - Clear error messaging for validation failures

4. **UI/UX Requirements**:
   - Progress indicator showing "Step 1 of 2" / "Step 2 of 2"
   - Clear helper text explaining conditional requirements
   - Error banner for validation messages
   - Next button (Screen 1) and Back button (Screen 2)
   - Form resets after successful submission

5. **Enhanced Empty Results Display**:
   - Show prominent warning message when no properties match search criteria
   - Message: "No houses match your search criteria. Please try adjusting your filters."

6. **Data Persistence**:
   - Contact information saved to Lead records
   - Lead.FirstName, Lead.LastName, Lead.Email, Lead.Phone populated
   - Description field includes contact information

## Technical Architecture

### Component Structure

#### HTML Template (`leadHouseCapture.html`)
```
├── Progress Indicator
├── Screen 1: Contact Information (if:true={isContactScreen})
│   ├── Header & Helper Text
│   ├── Error Banner (if validation fails)
│   ├── First Name Input (required)
│   ├── Last Name Input (required)
│   ├── Email Input (with helper text)
│   ├── Phone Input (with helper text)
│   └── Next Button
└── Screen 2: Property Search (if:true={isPropertyScreen})
    ├── Property Search Filters (existing)
    ├── Property Results Grid (existing)
    ├── Enhanced No Results Message (warning alert)
    └── Navigation Buttons (Back + Submit)
```

#### JavaScript Controller (`leadHouseCapture.js`)
```javascript
// New Properties
- currentScreen: 'contact' | 'property'
- firstName, lastName, email, phone
- contactValidationError

// New Computed Properties
- isContactScreen
- isPropertyScreen
- currentStepNumber

// New Methods
- handleFirstNameChange()
- handleLastNameChange()
- handleEmailChange()
- handlePhoneChange()
- validateContactInfo()
- handleNext()
- handleBack()
- resetForm()

// Modified Methods
- handleSubmit() - now passes contact info to Apex
```

#### Apex Controller (`LeadHouseCaptureController.cls`)
```apex
// Modified Method Signature
@AuraEnabled
public static List<CreateLeadResult> createLeadsForProperties(
    List<Id> propertyIds,
    String firstName,      // NEW
    String lastName,       // NEW
    String email,          // NEW
    String phone,          // NEW
    String cityOrState,
    Integer bedrooms,
    String style,
    Decimal minPrice,
    Decimal maxPrice
)

// New Validations
- Validate firstName and lastName are not blank
- Validate at least one of email or phone is provided

// Modified Lead Creation
- l.FirstName = firstName.trim()
- l.LastName = lastName.trim()
- l.Email = email (if provided)
- l.Phone = phone (if provided)
- Updated Description with contact info
```

### Validation Logic

#### Client-Side Validation (JavaScript)
```javascript
validateContactInfo() {
    // 1. Check First Name not blank
    // 2. Check Last Name not blank
    // 3. Check at least one of Email or Phone is filled
    // 4. If Email provided, validate email format (regex)
    // 5. Return true if all valid, false otherwise
    // 6. Set contactValidationError with appropriate message
}
```

#### Server-Side Validation (Apex)
```apex
// Validate required contact fields
if (String.isBlank(firstName) || String.isBlank(lastName)) {
    throw new AuraHandledException('First Name and Last Name are required.');
}

// Validate at least one contact method
if (String.isBlank(email) && String.isBlank(phone)) {
    throw new AuraHandledException('Please provide at least one contact method: Email or Phone.');
}
```

## Implementation Details

### Screen Flow
1. User lands on Screen 1 (Contact Information)
2. User fills First Name, Last Name, and at least Email or Phone
3. User clicks "Next" → validation runs
4. If validation passes → navigate to Screen 2
5. If validation fails → show error banner with specific message
6. On Screen 2, user can click "Back" to return to Screen 1 (data preserved)
7. User searches for properties, selects up to 3
8. User clicks "Submit Leads"
9. Leads created with contact info + property preferences
10. Success toast shown, form resets to Screen 1

### Error Handling
- **Client-side errors**: Displayed in error banner at top of Screen 1
- **Server-side errors**: Displayed via toast notifications
- **No results**: Warning alert banner in results area

### Data Flow
```
Screen 1 (Contact Info)
    ↓ (validation passes)
Screen 2 (Property Search)
    ↓ (user selects properties)
Submit Button
    ↓ (call Apex)
createLeadsForProperties(
    propertyIds,
    firstName, lastName, email, phone,  ← Contact info from Screen 1
    cityOrState, bedrooms, style, minPrice, maxPrice  ← Search criteria from Screen 2
)
    ↓
Lead Records Created
    ↓
Success Toast + Form Reset
```

## Test Coverage

### Test Scenarios (`LeadHouseCaptureControllerTest.cls`)

1. **testCreateLeadsForProperties_Success**
   - Create lead with all contact fields (firstName, lastName, email, phone)
   - Verify all fields populated correctly

2. **testCreateLeadsForProperties_WithEmailOnly**
   - Create lead with email but no phone
   - Verify email populated, phone is null

3. **testCreateLeadsForProperties_WithPhoneOnly**
   - Create lead with phone but no email
   - Verify phone populated, email is null

4. **testCreateLeadsForProperties_MissingContactInfo**
   - Attempt to create lead with blank firstName
   - Verify exception thrown with appropriate message

5. **testCreateLeadsForProperties_MissingEmailAndPhone**
   - Attempt to create lead with no email or phone
   - Verify exception thrown: "at least one contact method"

6. **testCreateLeadsForProperties_EnforceMaxThree**
   - Attempt to create leads for 4 properties
   - Verify exception thrown: "only submit up to 3"

7. **testGetDistinctStylesFromTags** (existing, unchanged)

8. **testSearchProperties_ByCity** (existing, unchanged)

9. **testSearchProperties_ByStateAndBedroomsAndStyleAndPrice** (existing, unchanged)

## Files Modified

### LWC Component
- ✅ `force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.html`
  - Added Screen 1 (contact form)
  - Added progress indicator
  - Modified Screen 2 (added Back button)
  - Enhanced "no results" message

- ✅ `force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.js`
  - Added contact information properties
  - Added screen management properties
  - Added validation logic
  - Added navigation handlers
  - Modified submit handler to include contact info

- ⚪ `force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.css` (unchanged)
- ⚪ `force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.js-meta.xml` (unchanged)

### Apex Classes
- ✅ `force-app/main/default/classes/LeadHouseCaptureController.cls`
  - Modified `createLeadsForProperties` method signature (added 4 parameters)
  - Added server-side validation for contact info
  - Modified Lead creation to populate FirstName, LastName, Email, Phone
  - Updated `buildDescription` method to include contact information

- ⚪ `force-app/main/default/classes/LeadHouseCaptureController.cls-meta.xml` (unchanged)

- ✅ `force-app/main/default/classes/LeadHouseCaptureControllerTest.cls`
  - Updated all existing test methods with new parameters
  - Added 3 new test methods for validation scenarios
  - Total: 9 test methods with comprehensive coverage

- ⚪ `force-app/main/default/classes/LeadHouseCaptureControllerTest.cls-meta.xml` (unchanged)

## Deployment Information

**Deploy Command**:
```bash
sfdx force:source:deploy -p force-app/main/default/lwc/leadHouseCapture,force-app/main/default/classes/LeadHouseCaptureController.cls,force-app/main/default/classes/LeadHouseCaptureController.cls-meta.xml,force-app/main/default/classes/LeadHouseCaptureControllerTest.cls,force-app/main/default/classes/LeadHouseCaptureControllerTest.cls-meta.xml -u agVibeDemoOrg
```

**Deployment Results**:
- Status: ✅ Succeeded
- Deploy ID: 0AfKj00002e1ASVKA2
- Target Org: yashika.garg@tnd26demo.org
- Elapsed Time: 27.36s
- Components Deployed: 8

## User Testing Guide

### Test Scenario 1: Valid Contact with Email
1. Fill First Name: "John"
2. Fill Last Name: "Doe"
3. Fill Email: "john.doe@example.com"
4. Leave Phone blank
5. Click Next
6. **Expected**: Navigate to property search screen

### Test Scenario 2: Valid Contact with Phone
1. Fill First Name: "Jane"
2. Fill Last Name: "Smith"
3. Leave Email blank
4. Fill Phone: "555-1234"
5. Click Next
6. **Expected**: Navigate to property search screen

### Test Scenario 3: Valid Contact with Both
1. Fill First Name: "Bob"
2. Fill Last Name: "Johnson"
3. Fill Email: "bob@example.com"
4. Fill Phone: "555-5678"
5. Click Next
6. **Expected**: Navigate to property search screen

### Test Scenario 4: Missing First Name
1. Leave First Name blank
2. Fill Last Name: "Test"
3. Fill Email: "test@example.com"
4. Click Next
5. **Expected**: Error banner: "First Name is required."

### Test Scenario 5: Missing Last Name
1. Fill First Name: "Test"
2. Leave Last Name blank
3. Fill Email: "test@example.com"
4. Click Next
5. **Expected**: Error banner: "Last Name is required."

### Test Scenario 6: Missing Both Contact Methods
1. Fill First Name: "Test"
2. Fill Last Name: "User"
3. Leave Email blank
4. Leave Phone blank
5. Click Next
6. **Expected**: Error banner: "Please provide at least one contact method: Email or Phone."

### Test Scenario 7: Invalid Email Format
1. Fill First Name: "Test"
2. Fill Last Name: "User"
3. Fill Email: "invalid-email"
4. Click Next
5. **Expected**: Error banner: "Please enter a valid email address."

### Test Scenario 8: Navigation - Back Button
1. Complete Screen 1 with valid data
2. Navigate to Screen 2
3. Search for properties
4. Select a property
5. Click Back button
6. **Expected**: Return to Screen 1, contact data preserved

### Test Scenario 9: Complete Flow
1. Fill valid contact information on Screen 1
2. Click Next
3. Search for properties on Screen 2
4. Select 1-3 properties
5. Click Submit Leads
6. **Expected**: 
   - Success toast: "Successfully created [X] lead(s)"
   - Form resets to Screen 1
   - All fields cleared

### Test Scenario 10: No Search Results
1. Complete Screen 1
2. On Screen 2, enter search criteria that match no properties
3. Click Search
4. **Expected**: Warning alert: "No houses match your search criteria. Please try adjusting your filters."

## Design Decisions

### Confirmed Decisions
1. **Progress Indicator**: "Step 1 of 2" / "Step 2 of 2" at the top
2. **Screen Transition**: Simple instant swap (no animation)
3. **Validation Timing**: Show errors when clicking "Next" button (not real-time)
4. **Error Message Position**: Banner at form top + inline helper text
5. **Mobile Optimization**: Component already mobile-ready via existing metadata

### Alternative Approaches Considered
1. **Real-time validation**: Decided against to avoid interrupting user flow
2. **Modal dialogs**: Decided against to keep navigation simple
3. **Single-screen with collapsible sections**: Decided against for clearer separation of concerns
4. **Required asterisks on Email/Phone**: Decided against as both fields are conditionally required

## Success Criteria

✅ **All criteria met:**
1. Multi-screen form implemented with clear navigation
2. Contact information captured on Screen 1
3. At least one of Email or Phone is required and validated
4. Clear error messaging for all validation scenarios
5. Property search functionality preserved from v0.0.1
6. Lead records populated with contact information
7. Form resets after successful submission
8. Enhanced "no results" message displayed
9. All test cases passing
10. Successfully deployed to org

## Next Steps / Future Enhancements

1. **Add field-level validation indicators**: Visual cues on individual fields
2. **Remember last search**: Store preferences in local storage
3. **Email format auto-correction**: Suggest corrections for common typos
4. **Phone format auto-formatting**: Format phone numbers as user types
5. **Duplicate lead detection**: Check for existing leads before creating
6. **Lead assignment rules**: Route leads to appropriate sales reps
7. **Integration with marketing automation**: Send confirmation emails
8. **Analytics tracking**: Track form completion rates and drop-off points