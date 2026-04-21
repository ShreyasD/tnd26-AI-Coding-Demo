@IsTest
private class LeadHouseCaptureControllerTest {
    @TestSetup
    static void setup() {
        // Create a few properties with different tags, styles, beds, price, city/state
        List<Property__c> props = new List<Property__c>();
        props.add(new Property__c(
            Name = 'Maple Condo',
            Price__c = 300000,
            Beds__c = 2,
            City__c = 'Austin',
            State__c = 'TX',
            Tags__c = 'Condo;Modern'
        ));
        props.add(new Property__c(
            Name = 'Cedar Townhouse',
            Price__c = 550000,
            Beds__c = 3,
            City__c = 'Austin',
            State__c = 'TX',
            Tags__c = 'Townhouse, Contemporary'
        ));
        props.add(new Property__c(
            Name = 'Pine Single Family',
            Price__c = 800000,
            Beds__c = 4,
            City__c = 'Denver',
            State__c = 'CO',
            Tags__c = 'Single Family;Spacious'
        ));
        insert props;
    }

    @IsTest
    static void testGetDistinctStylesFromTags() {
        Test.startTest();
        List<String> styles = LeadHouseCaptureController.getDistinctStylesFromTags();
        Test.stopTest();
        System.assertNotEquals(0, styles.size(), 'Should return distinct style tokens from Tags__c');
        System.assert(styles.contains('Condo'), 'Tokenized styles should include Condo');
        System.assert(styles.contains('Townhouse'), 'Tokenized styles should include Townhouse');
        System.assert(styles.contains('Single Family'), 'Tokenized styles should include Single Family');
    }

    @IsTest
    static void testSearchProperties_ByCity() {
        Test.startTest();
        List<LeadHouseCaptureController.PropertyDTO> res =
            LeadHouseCaptureController.searchProperties('Austin', 0, null, null, null);
        Test.stopTest();
        System.assertEquals(2, res.size(), 'Two Austin properties expected');
        System.assertEquals('Austin'.toLowerCase(), String.valueOf(res[0].city).toLowerCase());
        System.assertEquals('TX'.toLowerCase(), String.valueOf(res[0].state).toLowerCase());
    }

    @IsTest
    static void testSearchProperties_ByStateAndBedroomsAndStyleAndPrice() {
        Test.startTest();
        // Match Denver/CO with Single Family, min beds 4, price <= 900k
        List<LeadHouseCaptureController.PropertyDTO> res =
            LeadHouseCaptureController.searchProperties('CO', 4, 'Single Family', 100000, 900000);
        Test.stopTest();

        System.assertEquals(1, res.size(), 'Should match the Denver Single Family');
        System.assertEquals('Denver'.toLowerCase(), String.valueOf(res[0].city).toLowerCase());
        System.assertEquals(true, res[0].tags != null && res[0].tags.size() > 0, 'Tags should be populated');
        System.assert(res[0].price <= 900000);
    }

    @IsTest
    static void testCreateLeadsForProperties_Success() {
        Property__c p = [SELECT Id, Name FROM Property__c WHERE Name = 'Maple Condo' LIMIT 1];

        Test.startTest();
        List<LeadHouseCaptureController.CreateLeadResult> results =
            LeadHouseCaptureController.createLeadsForProperties(
                new List<Id>{ p.Id }, 
                'John', 
                'Doe', 
                'john.doe@example.com', 
                '555-1234',
                'Austin', 
                2, 
                'Condo', 
                200000, 
                400000
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        System.assert(results[0].success, 'Lead creation should succeed');
        System.assertNotEquals(null, results[0].leadId, 'Lead Id should be present');
        Lead created = [SELECT Id, FirstName, LastName, Email, Phone, Company, Status, Description FROM Lead WHERE Id = :results[0].leadId];
        System.assertEquals('John', created.FirstName, 'FirstName should match');
        System.assertEquals('Doe', created.LastName, 'LastName should match');
        System.assertEquals('john.doe@example.com', created.Email, 'Email should match');
        System.assertEquals('555-1234', created.Phone, 'Phone should match');
        System.assertEquals('Dreamhouse Prospect', created.Company);
        System.assert(created.Description != null && created.Description.contains('Lead generated from Dreamhouse Home LWC.'));
        System.assert(created.Description.contains('John Doe'), 'Description should contain contact name');
    }

    @IsTest
    static void testCreateLeadsForProperties_WithEmailOnly() {
        Property__c p = [SELECT Id, Name FROM Property__c WHERE Name = 'Cedar Townhouse' LIMIT 1];

        Test.startTest();
        List<LeadHouseCaptureController.CreateLeadResult> results =
            LeadHouseCaptureController.createLeadsForProperties(
                new List<Id>{ p.Id }, 
                'Jane', 
                'Smith', 
                'jane.smith@example.com', 
                '',
                'Austin', 
                3, 
                'Townhouse', 
                500000, 
                600000
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].success);
        Lead created = [SELECT Id, FirstName, LastName, Email, Phone FROM Lead WHERE Id = :results[0].leadId];
        System.assertEquals('Jane', created.FirstName);
        System.assertEquals('Smith', created.LastName);
        System.assertEquals('jane.smith@example.com', created.Email);
        System.assertEquals(null, created.Phone, 'Phone should be null when not provided');
    }

    @IsTest
    static void testCreateLeadsForProperties_WithPhoneOnly() {
        Property__c p = [SELECT Id, Name FROM Property__c WHERE Name = 'Pine Single Family' LIMIT 1];

        Test.startTest();
        List<LeadHouseCaptureController.CreateLeadResult> results =
            LeadHouseCaptureController.createLeadsForProperties(
                new List<Id>{ p.Id }, 
                'Bob', 
                'Johnson', 
                '', 
                '555-9876',
                'Denver', 
                4, 
                'Single Family', 
                700000, 
                900000
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].success);
        Lead created = [SELECT Id, FirstName, LastName, Email, Phone FROM Lead WHERE Id = :results[0].leadId];
        System.assertEquals('Bob', created.FirstName);
        System.assertEquals('Johnson', created.LastName);
        System.assertEquals(null, created.Email, 'Email should be null when not provided');
        System.assertEquals('555-9876', created.Phone);
    }

    @IsTest
    static void testCreateLeadsForProperties_MissingContactInfo() {
        Property__c p = [SELECT Id, Name FROM Property__c WHERE Name = 'Maple Condo' LIMIT 1];

        Test.startTest();
        Boolean threw = false;
        try {
            LeadHouseCaptureController.createLeadsForProperties(
                new List<Id>{ p.Id }, 
                '', 
                'Doe', 
                'john.doe@example.com', 
                '555-1234',
                'Austin', 
                2, 
                'Condo', 
                200000, 
                400000
            );
        } catch (AuraHandledException ahe) {
            threw = true;
            System.assert(ahe.getMessage().contains('First Name and Last Name are required'), 'Should validate required fields');
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for missing FirstName');
    }

    @IsTest
    static void testCreateLeadsForProperties_MissingEmailAndPhone() {
        Property__c p = [SELECT Id, Name FROM Property__c WHERE Name = 'Maple Condo' LIMIT 1];

        Test.startTest();
        Boolean threw = false;
        try {
            LeadHouseCaptureController.createLeadsForProperties(
                new List<Id>{ p.Id }, 
                'John', 
                'Doe', 
                '', 
                '',
                'Austin', 
                2, 
                'Condo', 
                200000, 
                400000
            );
        } catch (AuraHandledException ahe) {
            threw = true;
            System.assert(ahe.getMessage().contains('at least one contact method'), 'Should validate at least one contact method');
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for missing contact methods');
    }

    @IsTest
    static void testCreateLeadsForProperties_EnforceMaxThree() {
        List<Property__c> ps = [SELECT Id FROM Property__c LIMIT 3];
        System.assertEquals(3, ps.size());

        // Add a 4th to exceed limit
        Property__c extra = new Property__c(
            Name = 'Extra Home',
            Price__c = 450000,
            Beds__c = 3,
            City__c = 'Austin',
            State__c = 'TX',
            Tags__c = 'Townhouse'
        );
        insert extra;

        List<Id> ids = new List<Id>();
        ids.addAll(new List<Id>{ ps[0].Id, ps[1].Id, ps[2].Id, extra.Id });

        Boolean threw = false;
        try {
            Test.startTest();
            LeadHouseCaptureController.createLeadsForProperties(
                ids, 
                'John', 
                'Doe', 
                'john.doe@example.com', 
                '555-1234',
                null, 
                null, 
                null, 
                null, 
                null
            );
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            threw = true;
            System.assert(ahe.getMessage().contains('only submit up to 3'), 'Should enforce max 3 property selection');
        }
        System.assert(threw, 'Expected AuraHandledException due to exceeding limit');
    }
}