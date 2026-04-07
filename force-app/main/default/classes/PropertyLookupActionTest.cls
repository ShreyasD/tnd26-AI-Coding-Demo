@IsTest
private class PropertyLookupActionTest {
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

    @IsTest
    static void returnsExactNameMatch() {
        Property__c p = createProperty('Oceanview Villa', '100 Beach Rd', 'San Francisco', 'CA');

        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = 'Oceanview Villa';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(p.Id, responses[0].propertyId);
        System.assertEquals('Oceanview Villa', responses[0].propertyName);
        System.assertEquals(1, responses[0].matchCount);
        System.assertEquals('', responses[0].errorMessage);
        System.assertEquals('', responses[0].matchList);
    }

    @IsTest
    static void returnsPartialNameMatch() {
        Property__c p = createProperty('321 Oak Street Estate', '321 Oak St', 'Oakland', 'CA');

        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = 'Oak Street';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(p.Id, responses[0].propertyId);
        System.assertEquals(1, responses[0].matchCount);
        System.assertEquals('', responses[0].errorMessage);
    }

    @IsTest
    static void returnsAddressMatch() {
        Property__c p = createProperty('Sunset Home', '456 Elm Avenue', 'San Jose', 'CA');

        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = '456 Elm';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(p.Id, responses[0].propertyId);
        System.assertEquals('Sunset Home', responses[0].propertyName);
        System.assert(responses[0].propertyAddress.contains('456 Elm Avenue'));
    }

    @IsTest
    static void returnsCityMatch() {
        Property__c p = createProperty('Downtown Loft', '789 Market St', 'San Francisco', 'CA');

        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = 'San Francisco';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assert(responses[0].matchCount >= 1, 'Should find at least one match by city');
        System.assertEquals('', responses[0].errorMessage);
    }

    @IsTest
    static void returnsMultipleMatchesWithFormattedList() {
        createProperty('Oak House A', '100 Oak Lane', 'Berkeley', 'CA');
        createProperty('Oak House B', '200 Oak Lane', 'Berkeley', 'CA');
        createProperty('Oak House C', '300 Oak Lane', 'Berkeley', 'CA');

        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = 'Oak House';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(3, responses[0].matchCount);
        System.assertEquals('', responses[0].propertyId, 'No single property selected');
        System.assert(responses[0].matchList.contains('1.'), 'Match list should be numbered');
        System.assert(responses[0].matchList.contains('Oak House A'));
        System.assert(responses[0].matchList.contains('Oak House C'));
        System.assertEquals('', responses[0].errorMessage);
    }

    @IsTest
    static void returnsErrorWhenNoMatchesFound() {
        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = 'Nonexistent Galaxy Property';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(0, responses[0].matchCount);
        System.assertEquals('', responses[0].propertyId);
        System.assert(responses[0].errorMessage.contains('No properties found'));
        System.assert(responses[0].errorMessage.contains('Nonexistent Galaxy Property'));
    }

    @IsTest
    static void returnsErrorWhenSearchTermIsBlank() {
        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = '   ';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assert(responses[0].errorMessage.contains('search term is required'));
        System.assertEquals('', responses[0].propertyId);
    }

    @IsTest
    static void returnsErrorWhenSearchTermIsNull() {
        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = null;

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assert(responses[0].errorMessage.contains('search term is required'));
    }

    @IsTest
    static void returnsEmptyListWhenRequestListIsNull() {
        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(null);

        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void returnsEmptyListWhenRequestListIsEmpty() {
        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>());

        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void formatsAddressWithMissingFields() {
        Property__c p = new Property__c(
            Name = 'Minimal Property',
            Price__c = 100000
        );
        insert p;

        PropertyLookupAction.Request req = new PropertyLookupAction.Request();
        req.searchTerm = 'Minimal Property';

        List<PropertyLookupAction.Response> responses =
            PropertyLookupAction.findProperty(new List<PropertyLookupAction.Request>{ req });

        System.assertEquals(1, responses.size());
        System.assertEquals(p.Id, responses[0].propertyId);
        System.assertEquals('', responses[0].propertyAddress);
    }
}
