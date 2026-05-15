# Lead Capture Form v0.1.0 - Implementation Plan

## Overview
Update the leadHouseCapture LWC to create a **single Lead** for all selected properties instead of creating multiple Leads. Introduce a junction object to maintain the many-to-many relationship between Leads and Properties.

---

## Current Architecture (v0.0.x)

```
┌─────────────────┐
│ Lead Capture    │
│ Form (LWC)      │
└────────┬────────┘
         │
         │ Submits with 1-3 properties
         │
         ▼
┌─────────────────────────────────────┐
│ LeadHouseCaptureController.cls      │
│ createLeadsForProperties()          │
└────────┬────────────────────────────┘
         │
         │ Creates Multiple Leads
         │ (1 Lead per Property)
         ▼
┌─────────────────────┐      ┌──────────────────┐
│ Lead 1              │──────│ Property A       │
│ - Property__c ─────▶│      │                  │
└─────────────────────┘      └──────────────────┘

┌─────────────────────┐      ┌──────────────────┐
│ Lead 2              │──────│ Property B       │
│ - Property__c ─────▶│      │                  │
└─────────────────────┘      └──────────────────┘

┌─────────────────────┐      ┌──────────────────┐
│ Lead 3              │──────│ Property C       │
│ - Property__c ─────▶│      │                  │
└─────────────────────┘      └──────────────────┘
```

**Problems:**
- Creates duplicate Lead records for same contact
- Lead has direct lookup to single Property__c
- Inefficient for reporting and data management

---

## New Architecture (v0.1.0)

```
┌─────────────────┐
│ Lead Capture    │
│ Form (LWC)      │
└────────┬────────┘
         │
         │ Submits with 1-3 properties
         │
         ▼
┌─────────────────────────────────────┐
│ LeadHouseCaptureController.cls      │
│ createLeadWithProperties()          │
└────────┬────────────────────────────┘
         │
         │ Creates 1 Lead + N Junction Records
         │
         ▼
┌─────────────────────┐
│ Lead                │
│ - FirstName         │
│ - LastName          │
│ - Email             │
│ - Phone             │
│ - Company           │
│ - Status            │
│ - Description       │
└──────────┬──────────┘
           │
           │ Has Many Property Interests
           │
           ▼
┌─────────────────────────┐      ┌──────────────────┐
│ Property_Interest__c    │──────│ Property A       │
│ - Lead__c (MD)         │      │                  │
│ - Property__c (MD) ────▶│      │                  │
└─────────────────────────┘      └──────────────────┘

┌─────────────────────────┐      ┌──────────────────┐
│ Property_Interest__c    │──────│ Property B       │
│ - Lead__c (MD)         │      │                  │
│ - Property__c (MD) ────▶│      │                  │
└─────────────────────────┘      └──────────────────┘

┌─────────────────────────┐      ┌──────────────────┐
│ Property_Interest__c    │──────│ Property C       │
│ - Lead__c (MD)         │      │                  │
│ - Property__c (MD) ────▶│      │                  │
└─────────────────────────┘      └──────────────────┘
```

**Benefits:**
- ✅ Single Lead per form submission
- ✅ Many-to-many relationship via junction object
- ✅ Better data integrity with Master-Detail relationships
- ✅ Cleaner reporting and analytics
- ✅ Extensible (can add fields to junction later)

---

## Implementation Details

### 1. Junction Object: Property_Interest__c

**Custom Object Metadata:**
```xml
API Name: Property_Interest__c
Label: Property Interest
Plural Label: Property Interests
Deployment Status: Deployed
Sharing Model: Controlled by Parent (Master-Detail)
```

**Fields:**

#### a) Lead__c (Master-Detail Relationship)
```xml
Type: Master-Detail
Parent Object: Lead
Child Relationship Name: Property_Interests
Required: true
Reparentable: true
Cascade Delete: Yes (automatic with Master-Detail)
```

#### b) Property__c (Master-Detail Relationship)
```xml
Type: Master-Detail
Parent Object: Property__c
Child Relationship Name: Lead_Interests
Required: true
Reparentable: true
Cascade Delete: Yes (automatic with Master-Detail)
```

#### c) Name (Auto Number)
```xml
Type: Auto Number
Display Format: PI-{0000}
Starting Number: 0001
```

**Compound Unique Index (Recommended):**
- Fields: `Lead__c`, `Property__c`
- Purpose: Prevent duplicate interest records

**File Structure:**
```
force-app/main/default/objects/Property_Interest__c/
├── Property_Interest__c.object-meta.xml
├── fields/
│   ├── Lead__c.field-meta.xml
│   ├── Property__c.field-meta.xml
│   └── Name.field-meta.xml
```

---

### 2. Apex Controller Updates

**File:** `force-app/main/default/classes/LeadHouseCaptureController.cls`

#### Changes Required:

**a) Add New Response Class**
```apex
public class CreateLeadResponse {
    @AuraEnabled public Id leadId;
    @AuraEnabled public Integer propertiesLinked;
    @AuraEnabled public Boolean success;
    @AuraEnabled public String message;
    
    public CreateLeadResponse(Id leadId, Integer propertiesLinked, Boolean success, String message) {
        this.leadId = leadId;
        this.propertiesLinked = propertiesLinked;
        this.success = success;
        this.message = message;
    }
}
```

**b) New Method: createLeadWithProperties**
```apex
@AuraEnabled
public static CreateLeadResponse createLeadWithProperties(
    List<Id> propertyIds, 
    String firstName, 
    String lastName, 
    String email, 
    String phone, 
    String cityOrState, 
    Integer bedrooms, 
    String style, 
    Decimal minPrice, 
    Decimal maxPrice
) {
    // Input validation
    if (propertyIds == null || propertyIds.isEmpty()) {
        throw new AuraHandledException('No properties selected.');
    }
    if (propertyIds.size() > 3) {
        throw new AuraHandledException('You can only submit up to 3 properties at a time.');
    }
    if (String.isBlank(firstName) || String.isBlank(lastName)) {
        throw new AuraHandledException('First Name and Last Name are required.');
    }
    if (String.isBlank(email) && String.isBlank(phone)) {
        throw new AuraHandledException('Please provide at least one contact method: Email or Phone.');
    }

    try {
        // Query properties for description
        Map<Id, Property__c> propsMap = new Map<Id, Property__c>([
            SELECT Id, Name, Price__c, Beds__c, City__c, State__c
            FROM Property__c 
            WHERE Id IN :propertyIds
        ]);

        // Create single Lead (no Property__c lookup)
        Lead newLead = new Lead();
        newLead.FirstName = firstName.trim();
        newLead.LastName = lastName.trim();
        newLead.Email = String.isBlank(email) ? null : email.trim();
        newLead.Phone = String.isBlank(phone) ? null : phone.trim();
        newLead.Company = 'Dreamhouse Prospect';
        newLead.Status = 'New';
        newLead.LeadSource = 'Marketing Event';
        newLead.Description = buildMultiPropertyDescription(
            propsMap.values(), 
            firstName, 
            lastName, 
            email, 
            phone, 
            cityOrState, 
            bedrooms, 
            style, 
            minPrice, 
            maxPrice
        );
        
        insert newLead;

        // Create junction records
        List<Property_Interest__c> interests = new List<Property_Interest__c>();
        for (Id propId : propertyIds) {
            if (propsMap.containsKey(propId)) {
                interests.add(new Property_Interest__c(
                    Lead__c = newLead.Id,
                    Property__c = propId
                ));
            }
        }
        
        insert interests;

        return new CreateLeadResponse(
            newLead.Id,
            interests.size(),
            true,
            'Lead created successfully with ' + interests.size() + ' properties'
        );

    } catch (DmlException e) {
        throw new AuraHandledException('Failed to create lead: ' + e.getDmlMessage(0));
    } catch (Exception e) {
        throw new AuraHandledException('Unexpected error: ' + e.getMessage());
    }
}
```

**c) New Helper Method: buildMultiPropertyDescription**
```apex
private static String buildMultiPropertyDescription(
    List<Property__c> properties,
    String firstName, 
    String lastName, 
    String email, 
    String phone, 
    String cityOrState, 
    Integer bedrooms, 
    String style, 
    Decimal minPrice, 
    Decimal maxPrice
) {
    List<String> lines = new List<String>();
    lines.add('Lead generated from Dreamhouse Home LWC.');
    lines.add('Contact: ' + firstName + ' ' + lastName);
    if (!String.isBlank(email)) {
        lines.add('Email: ' + email);
    }
    if (!String.isBlank(phone)) {
        lines.add('Phone: ' + phone);
    }
    lines.add('');
    lines.add('Interested in ' + properties.size() + ' properties:');
    
    for (Property__c p : properties) {
        lines.add('- ' + p.Name + ' | Price: ' + String.valueOf(p.Price__c) + 
                  ' | Beds: ' + String.valueOf(p.Beds__c) + 
                  ' | ' + p.City__c + ', ' + p.State__c);
    }
    
    lines.add('');
    lines.add('Buyer Preferences:');
    lines.add('- City/State: ' + (String.isBlank(cityOrState) ? 'Any' : cityOrState));
    lines.add('- Bedrooms: ' + (bedrooms == null ? 'Any' : String.valueOf(bedrooms) + '+'));
    lines.add('- Style: ' + (String.isBlank(style) ? 'Any' : style));
    
    String pricePref;
    if (minPrice != null && maxPrice != null) {
        pricePref = '$' + minPrice.setScale(0) + ' to $' + maxPrice.setScale(0);
    } else if (minPrice != null) {
        pricePref = '$' + minPrice.setScale(0) + '+';
    } else if (maxPrice != null) {
        pricePref = '<= $' + maxPrice.setScale(0);
    } else {
        pricePref = 'Any';
    }
    lines.add('- Price Range: ' + pricePref);
    
    String out = '';
    for (Integer i = 0; i < lines.size(); i++) {
        out += (i == 0 ? '' : '\n') + lines[i];
    }
    return out;
}
```

**d) Keep Existing Methods**
- `searchProperties()` - No changes needed
- `getDistinctStylesFromTags()` - No changes needed
- `PropertyDTO` - No changes needed
- `CreateLeadResult` - Keep for backward compatibility, but deprecated

---

### 3. Apex Test Class Updates

**File:** `force-app/main/default/classes/LeadHouseCaptureControllerTest.cls`

#### Add New Test Methods:

```apex
@isTest
static void testCreateLeadWithSingleProperty() {
    // Setup
    Property__c prop = new Property__c(
        Name = 'Test House',
        Price__c = 500000,
        Beds__c = 3,
        City__c = 'San Francisco',
        State__c = 'CA',
        Tags__c = 'Modern'
    );
    insert prop;

    // Execute
    Test.startTest();
    LeadHouseCaptureController.CreateLeadResponse result = 
        LeadHouseCaptureController.createLeadWithProperties(
            new List<Id>{ prop.Id },
            'John',
            'Doe',
            'john@example.com',
            '555-1234',
            'San Francisco',
            3,
            'Modern',
            null,
            null
        );
    Test.stopTest();

    // Verify
    System.assert(result.success, 'Should succeed');
    System.assertEquals(1, result.propertiesLinked, 'Should link 1 property');
    
    Lead createdLead = [SELECT Id, FirstName, LastName FROM Lead WHERE Id = :result.leadId];
    System.assertEquals('John', createdLead.FirstName);
    System.assertEquals('Doe', createdLead.LastName);
    
    List<Property_Interest__c> interests = [
        SELECT Id, Lead__c, Property__c 
        FROM Property_Interest__c 
        WHERE Lead__c = :result.leadId
    ];
    System.assertEquals(1, interests.size(), 'Should create 1 junction record');
    System.assertEquals(prop.Id, interests[0].Property__c);
}

@isTest
static void testCreateLeadWithMultipleProperties() {
    // Setup
    List<Property__c> props = new List<Property__c>{
        new Property__c(Name = 'House A', Price__c = 400000, Beds__c = 2, City__c = 'SF', State__c = 'CA'),
        new Property__c(Name = 'House B', Price__c = 500000, Beds__c = 3, City__c = 'SF', State__c = 'CA'),
        new Property__c(Name = 'House C', Price__c = 600000, Beds__c = 4, City__c = 'SF', State__c = 'CA')
    };
    insert props;

    // Execute
    Test.startTest();
    LeadHouseCaptureController.CreateLeadResponse result = 
        LeadHouseCaptureController.createLeadWithProperties(
            new List<Id>{ props[0].Id, props[1].Id, props[2].Id },
            'Jane',
            'Smith',
            'jane@example.com',
            null,
            'SF',
            2,
            'Any',
            400000,
            600000
        );
    Test.stopTest();

    // Verify
    System.assert(result.success);
    System.assertEquals(3, result.propertiesLinked, 'Should link 3 properties');
    
    List<Property_Interest__c> interests = [
        SELECT Id, Property__c 
        FROM Property_Interest__c 
        WHERE Lead__c = :result.leadId
    ];
    System.assertEquals(3, interests.size(), 'Should create 3 junction records');
}

@isTest
static void testCreateLeadValidationErrors() {
    // Test missing first name
    try {
        LeadHouseCaptureController.createLeadWithProperties(
            new List<Id>{ 'a00000000000000' },
            '',
            'Doe',
            'test@example.com',
            null,
            null,
            null,
            null,
            null,
            null
        );
        System.assert(false, 'Should throw exception');
    } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('First Name'));
    }
    
    // Test missing contact method
    try {
        LeadHouseCaptureController.createLeadWithProperties(
            new List<Id>{ 'a00000000000000' },
            'John',
            'Doe',
            '',
            '',
            null,
            null,
            null,
            null,
            null
        );
        System.assert(false, 'Should throw exception');
    } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('contact method'));
    }
}
```

---

### 4. LWC Component Updates

**File:** `force-app/main/default/lwc/leadHouseCapture/leadHouseCapture.js`

#### Changes Required:

**a) Update Import Statement**
```javascript
// OLD
import createLeadsForProperties from '@salesforce/apex/LeadHouseCaptureController.createLeadsForProperties';

// NEW
import createLeadWithProperties from '@salesforce/apex/LeadHouseCaptureController.createLeadWithProperties';
```

**b) Update handleSubmit Method**
```javascript
async handleSubmit() {
    if (this.selectedCount === 0) {
        this.toast('No selection', 'Please select at least one property to submit.', 'info');
        return;
    }
    
    const ids = this.properties.filter((p) => p.selected).map((p) => p.id).slice(0, 3);

    try {
        const result = await createLeadWithProperties({
            propertyIds: ids,
            firstName: (this.firstName || '').trim(),
            lastName: (this.lastName || '').trim(),
            email: (this.email || '').trim(),
            phone: (this.phone || '').trim(),
            cityOrState: (this.cityOrState || '').trim(),
            bedrooms: this.minBedrooms,
            style: this.selectedStyle || '',
            minPrice: this.minPrice,
            maxPrice: this.maxPrice
        });

        if (result.success) {
            this.toast(
                'Lead Created', 
                `Successfully created lead with ${result.propertiesLinked} property interest(s).`, 
                'success'
            );
            
            // Navigate to the new Lead record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.leadId,
                    objectApiName: 'Lead',
                    actionName: 'view'
                }
            });
        } else {
            this.toast('Error', result.message || 'Failed to create lead', 'error');
        }
    } catch (e) {
        this.toast('Submit failed', this.errorMessage(e), 'error');
    }
}
```

**No HTML changes required** - the template already handles the UI correctly.

---

### 5. Lead Layout Updates

**File:** `force-app/main/default/layouts/Lead-Lead Layout.layout-meta.xml`

#### Add Related List for Property Interests

```xml
<relatedLists>
    <relatedList>Property_Interests__r</relatedList>
    <fields>NAME</fields>
    <fields>Property__c</fields>
    <fields>CREATED_DATE</fields>
</relatedLists>
```

This allows users viewing a Lead record to see all properties the Lead is interested in.

---

### 6. Optional: Property Layout Update

**File:** `force-app/main/default/layouts/Property__c-Property Layout.layout-meta.xml`

#### Add Related List for Lead Interests

```xml
<relatedLists>
    <relatedList>Lead_Interests__r</relatedList>
    <fields>NAME</fields>
    <fields>Lead__c</fields>
    <fields>CREATED_DATE</fields>
</relatedLists>
```

This allows users viewing a Property record to see all Leads interested in that property.

---

## Deployment Order

Execute in this order to avoid dependency errors:

1. ✅ **Create Junction Object**
   - `Property_Interest__c.object-meta.xml`
   - `fields/Lead__c.field-meta.xml`
   - `fields/Property__c.field-meta.xml`
   - `fields/Name.field-meta.xml`

2. ✅ **Update Apex Controller**
   - Add `CreateLeadResponse` class
   - Add `createLeadWithProperties` method
   - Add `buildMultiPropertyDescription` helper

3. ✅ **Update Test Class**
   - Add test methods for new functionality
   - Ensure 75%+ code coverage

4. ✅ **Update LWC**
   - Change import statement
   - Update `handleSubmit()` method

5. ✅ **Update Layouts**
   - Add related lists to Lead and Property layouts

6. ✅ **Deploy All**
   - Use Salesforce CLI or VS Code to deploy
   - Run all tests

---

## Testing Checklist

### Functional Testing
- [ ] Form displays both screens correctly
- [ ] Contact validation works (required fields, email format)
- [ ] Property search returns results
- [ ] Can select 1-3 properties
- [ ] Cannot select more than 3 properties
- [ ] Submit creates single Lead
- [ ] Submit creates correct number of junction records
- [ ] Lead Description contains all property details
- [ ] Navigation to Lead record works
- [ ] Related list shows on Lead record
- [ ] Related list shows on Property record

### Apex Testing
- [ ] All test methods pass
- [ ] Code coverage ≥ 75%
- [ ] Test validates single property scenario
- [ ] Test validates multiple properties scenario
- [ ] Test validates error handling

### Edge Cases
- [ ] Test with special characters in names
- [ ] Test with missing optional fields
- [ ] Test with maximum values (3 properties)
- [ ] Test with non-existent property IDs
- [ ] Test concurrent submissions

---

## Rollback Plan

If issues arise after deployment:

1. **Disable Component**
   - Remove leadHouseCapture from Lightning pages

2. **Revert Apex**
   - Deploy previous version of controller
   - Keep junction object (won't break anything)

3. **Data Cleanup**
   - Delete junction records if needed: `DELETE [SELECT Id FROM Property_Interest__c]`
   - Keep Lead records (valuable data)

---

## Future Enhancements (Not in v0.1.0)

### Potential Junction Object Fields
- `Interest_Level__c` (Picklist: Low/Medium/High)
- `Notes__c` (Long Text Area)
- `Date_Interested__c` (Date - default to today)
- `Follow_Up_Date__c` (Date)
- `Status__c` (Picklist: New/Contacted/Toured