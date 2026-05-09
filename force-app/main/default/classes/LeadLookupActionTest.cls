@IsTest
private class LeadLookupActionTest {
    private static Property__c createProperty(String name, String address, String city, String state) {
        Property__c p = new Property__c(
            Name = name,
            Address__c = address,
            City__c = city,
            State__c = state,
            Zip__c = '94105',
            Price__c = 500000
        );
        insert p;
        return p;
    }

    private static Lead createLead(String lastName, String company, Property__c prop) {
        Lead ld = new Lead(
            LastName = lastName,
            Company = company,
            Property__c = prop?.Id
        );
        insert ld;
        return ld;
    }

    @IsTest
    static void returnsSingleMatchWithProperty() {
        Property__c p = createProperty('Oceanview Villa', '100 Beach Rd', 'San Francisco', 'CA');
        Lead ld = createLead('Smith', 'Acme Corp', p);

        LeadLookupAction.Request req = new LeadLookupAction.Request();
        req.searchTerm = 'Smith';

        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(ld.Id, responses[0].leadId);
        System.assertEquals(p.Id, responses[0].propertyId);
        System.assertEquals('Oceanview Villa', responses[0].propertyName);
        System.assert(responses[0].propertyAddress.contains('100 Beach Rd'));
        System.assertEquals(1, responses[0].matchCount);
        System.assertEquals('', responses[0].errorMessage);
        System.assertEquals('', responses[0].matchList);
    }

    @IsTest
    static void returnsSingleMatchWithoutProperty() {
        Lead ld = createLead('Johnson', 'Beta Inc', null);

        LeadLookupAction.Request req = new LeadLookupAction.Request();
        req.searchTerm = 'Johnson';

        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(ld.Id, responses[0].leadId);
        System.assertEquals('', responses[0].propertyId);
        System.assert(responses[0].errorMessage.contains('does not have a property assigned'));
    }

    @IsTest
    static void returnsMultipleMatchesWithFormattedList() {
        Property__c p1 = createProperty('Beach House', '1 Shore Dr', 'Malibu', 'CA');
        Property__c p2 = createProperty('Hill Condo', '2 Peak Ave', 'Denver', 'CO');
        createLead('Williams', 'Alpha LLC', p1);
        createLead('Williamson', 'Bravo LLC', p2);
        createLead('Willard', 'Charlie LLC', null);

        LeadLookupAction.Request req = new LeadLookupAction.Request();
        req.searchTerm = 'Will';

        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(3, responses[0].matchCount);
        System.assertEquals('', responses[0].leadId, 'No single lead selected');
        System.assert(responses[0].matchList.contains('1.'), 'Match list should be numbered');
        System.assert(responses[0].matchList.contains('No property'));
        System.assertEquals('', responses[0].errorMessage);
    }

    @IsTest
    static void returnsErrorWhenNoMatchesFound() {
        LeadLookupAction.Request req = new LeadLookupAction.Request();
        req.searchTerm = 'Zzzyxyz Nonexistent';

        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(0, responses[0].matchCount);
        System.assertEquals('', responses[0].leadId);
        System.assert(responses[0].errorMessage.contains('No leads found'));
    }

    @IsTest
    static void returnsErrorWhenSearchTermIsBlank() {
        LeadLookupAction.Request req = new LeadLookupAction.Request();
        req.searchTerm = '   ';

        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assert(responses[0].errorMessage.contains('search term is required'));
        System.assertEquals('', responses[0].leadId);
    }

    @IsTest
    static void returnsErrorWhenSearchTermIsNull() {
        LeadLookupAction.Request req = new LeadLookupAction.Request();
        req.searchTerm = null;

        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assert(responses[0].errorMessage.contains('search term is required'));
    }

    @IsTest
    static void returnsEmptyListWhenRequestListIsNull() {
        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(null);

        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void returnsEmptyListWhenRequestListIsEmpty() {
        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>());

        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void formatsAddressWithMissingPropertyFields() {
        Property__c p = new Property__c(
            Name = 'Minimal Property',
            Price__c = 100000
        );
        insert p;
        Lead ld = createLead('Adams', 'Delta Corp', p);

        LeadLookupAction.Request req = new LeadLookupAction.Request();
        req.searchTerm = 'Adams';

        List<LeadLookupAction.Response> responses =
            LeadLookupAction.findLead(new List<LeadLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(ld.Id, responses[0].leadId);
        System.assertEquals(p.Id, responses[0].propertyId);
        System.assertEquals('', responses[0].propertyAddress);
    }
}
