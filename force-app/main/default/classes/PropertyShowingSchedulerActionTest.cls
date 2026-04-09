@IsTest
private class PropertyShowingSchedulerActionTest {
    private static Property__c makePropertyWithBrokerContact(Contact brokerContact) {
        Broker__c broker = new Broker__c(
            Name = 'Broker For Scheduling',
            Contact__c = brokerContact.Id
        );
        insert broker;

        Property__c propertyRecord = new Property__c(
            Name = '123 Testing Ave',
            Broker__c = broker.Id,
            Address__c = '123 Testing Ave',
            City__c = 'San Francisco',
            State__c = 'CA',
            Zip__c = '94105',
            Price__c = 500000
        );
        insert propertyRecord;
        return propertyRecord;
    }

    @IsTest
    static void schedulesEventUsingBrokerContactWhenContactMissing() {
        Contact c = new Contact(LastName = 'Broker Contact');
        insert c;
        Property__c propertyRecord = makePropertyWithBrokerContact(c);

        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(1);
        req.durationMinutes = 45;
        req.subject = 'Showing Appointment';

        Test.startTest();
        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response expected');
        System.assertEquals('', responses[0].errorMessage, 'No error expected');
        System.assertNotEquals(null, responses[0].eventId, 'Event Id should be returned');

        Event createdEvent = [
            SELECT Id, WhoId, WhatId, Subject
            FROM Event
            WHERE Id = :responses[0].eventId
            LIMIT 1
        ];
        System.assertEquals(c.Id, createdEvent.WhoId, 'Event should be linked to broker contact');
        System.assertEquals(propertyRecord.Id, createdEvent.WhatId, 'Event should be linked to property');
        System.assertEquals('Showing Appointment', createdEvent.Subject);
    }

    @IsTest
    static void returnsErrorWhenPropertyIsNotFound() {
        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = 'a00000000000001';
        req.startDateTime = System.now().addDays(1);

        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );

        System.assertEquals(1, responses.size());
        System.assertEquals('Property not found for provided propertyId.', responses[0].errorMessage);
        System.assertEquals('', responses[0].eventId, 'No event should be created');
    }

    @IsTest
    static void returnsErrorWhenBrokerContactCannotBeResolved() {
        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        Property__c propertyRecord = new Property__c(
            Name = 'No Broker Property',
            Address__c = '100 Empty Lane',
            City__c = 'San Francisco',
            State__c = 'CA',
            Zip__c = '94105',
            Price__c = 650000
        );
        insert propertyRecord;

        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(1);

        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );

        System.assertEquals('No broker is set on the property.', responses[0].errorMessage);
        System.assertEquals('', responses[0].eventId);
    }

    @IsTest
    static void returnsErrorWhenStartDateTimeIsInThePast() {
        Contact c = new Contact(LastName = 'Past Date Contact');
        insert c;
        Property__c propertyRecord = makePropertyWithBrokerContact(c);

        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(-1);

        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );

        System.assertEquals('startDateTime must be in the future.', responses[0].errorMessage);
        System.assertEquals('', responses[0].eventId);
    }

    @IsTest
    static void returnsErrorWhenPropertyIdIsBlank() {
        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = '';
        req.startDateTime = System.now().addDays(1);

        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );

        System.assertEquals('propertyId is required.', responses[0].errorMessage);
        System.assertEquals('', responses[0].eventId);
    }

    @IsTest
    static void returnsEmptyListWhenRequestListIsNull() {
        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(null);

        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void usesDefaultDurationWhenNotProvided() {
        Contact c = new Contact(LastName = 'Duration Contact');
        insert c;
        Property__c propertyRecord = makePropertyWithBrokerContact(c);

        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(2);

        Test.startTest();
        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals('', responses[0].errorMessage);
        Event createdEvent = [
            SELECT StartDateTime, EndDateTime FROM Event WHERE Id = :responses[0].eventId LIMIT 1
        ];
        Long diffMs = createdEvent.EndDateTime.getTime() - createdEvent.StartDateTime.getTime();
        System.assertEquals(30 * 60 * 1000, diffMs, 'Default duration should be 30 minutes');
    }

    @IsTest
    static void usesDefaultSubjectWhenNotProvided() {
        Contact c = new Contact(LastName = 'Subject Contact');
        insert c;
        Property__c propertyRecord = makePropertyWithBrokerContact(c);

        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(3);

        Test.startTest();
        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals('', responses[0].errorMessage);
        Event createdEvent = [
            SELECT Subject FROM Event WHERE Id = :responses[0].eventId LIMIT 1
        ];
        System.assertEquals('Property Showing', createdEvent.Subject);
    }

    @IsTest
    static void returnsErrorWhenBrokerHasNoContact() {
        Broker__c broker = new Broker__c(Name = 'No Contact Broker');
        insert broker;

        Property__c propertyRecord = new Property__c(
            Name = 'Broker No Contact Property',
            Broker__c = broker.Id,
            Address__c = '200 Null Contact Ln',
            City__c = 'San Francisco',
            State__c = 'CA',
            Zip__c = '94105',
            Price__c = 700000
        );
        insert propertyRecord;

        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(1);

        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );

        System.assertEquals('No broker contact found on the property broker.', responses[0].errorMessage);
        System.assertEquals('', responses[0].eventId);
    }
}