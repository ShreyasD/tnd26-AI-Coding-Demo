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
        System.assertNotEquals('', responses[0].eventLink, 'Event link should be returned');
        System.assert(responses[0].eventLink.contains('/lightning/r/Event/'), 'Event link should contain correct path');
        System.assert(responses[0].eventLink.contains(responses[0].eventId), 'Event link should contain the event ID');

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
        System.assertEquals('', responses[0].eventLink, 'No event link when error');
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
    static void addsLeadAsEventRelationWhenLeadIdProvided() {
        Contact c = new Contact(LastName = 'Lead Relation Contact');
        insert c;
        Property__c propertyRecord = makePropertyWithBrokerContact(c);

        Lead ld = new Lead(LastName = 'Showing Lead', Company = 'Test Co', Property__c = propertyRecord.Id);
        insert ld;

        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(1);
        req.leadId = ld.Id;

        Test.startTest();
        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals('', responses[0].errorMessage);
        System.assertNotEquals('', responses[0].eventId);
        System.assertNotEquals('', responses[0].eventLink, 'Event link should be returned for lead showing');
        System.assert(responses[0].eventLink.contains('/lightning/r/Event/'), 'Event link should contain correct path for lead showing');
        System.assert(responses[0].eventLink.contains(responses[0].eventId), 'Event link should contain event ID for lead showing');

        List<EventRelation> relations = [
            SELECT RelationId FROM EventRelation
            WHERE EventId = :responses[0].eventId AND RelationId = :ld.Id
        ];
        System.assertEquals(1, relations.size(), 'Lead should be added as an event relation');
    }

    @IsTest
    static void skipsLeadRelationWhenLeadIdIsNull() {
        Contact c = new Contact(LastName = 'No Lead Contact');
        insert c;
        Property__c propertyRecord = makePropertyWithBrokerContact(c);

        PropertyShowingSchedulerAction.Request req = new PropertyShowingSchedulerAction.Request();
        req.propertyId = propertyRecord.Id;
        req.startDateTime = System.now().addDays(1);

        Test.startTest();
        List<PropertyShowingSchedulerAction.Response> responses =
            PropertyShowingSchedulerAction.createPropertyEvent(
                new List<PropertyShowingSchedulerAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals('', responses[0].errorMessage);
        System.assertNotEquals('', responses[0].eventId);

        List<EventRelation> leadRelations = [
            SELECT RelationId FROM EventRelation
            WHERE EventId = :responses[0].eventId AND Relation.Type = 'Lead'
        ];
        System.assertEquals(0, leadRelations.size(), 'No lead relation when leadId is null');
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