global with sharing class PropertyShowingSchedulerAction {
    global class Request {
        @InvocableVariable(required=true)
        public String propertyId;

        @InvocableVariable(required=true)
        public Datetime startDateTime;

        @InvocableVariable
        public Integer durationMinutes;

        @InvocableVariable
        public String subject;

        @InvocableVariable
        public String eventDescription;
    }

    global class Response {
        @InvocableVariable
        public String eventId;

        @InvocableVariable
        public String confirmationMessage;

        @InvocableVariable
        public String errorMessage;
    }

    @InvocableMethod(label='Create Property Event')
    global static List<Response> createPropertyEvent(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Response>();
        }

        List<Response> responses = new List<Response>();
        Set<Id> propertyIds = new Set<Id>();
        for (Integer i = 0; i < requests.size(); i++) {
            responses.add(new Response());
            Request req = requests[i];
            Response resp = responses[i];
            if (req == null) {
                resp.errorMessage = 'Request payload is missing.';
                continue;
            }
            if (String.isBlank(req.propertyId)) {
                resp.errorMessage = 'propertyId is required.';
                continue;
            }
            Id parsedPropertyId = parseId(req.propertyId);
            if (parsedPropertyId == null) {
                resp.errorMessage = 'propertyId is not a valid Salesforce Id.';
                continue;
            }
            propertyIds.add(parsedPropertyId);
        }

        Map<Id, Property__c> propertiesById = propertyIds.isEmpty()
            ? new Map<Id, Property__c>()
            : new Map<Id, Property__c>([
                SELECT Id, Name, Broker__c
                FROM Property__c
                WHERE Id IN :propertyIds
            ]);

        Set<Id> brokerIds = new Set<Id>();
        for (Property__c propertyRecord : propertiesById.values()) {
            if (propertyRecord.Broker__c != null) {
                brokerIds.add(propertyRecord.Broker__c);
            }
        }

        Map<Id, Broker__c> brokersById = brokerIds.isEmpty()
            ? new Map<Id, Broker__c>()
            : new Map<Id, Broker__c>([
                SELECT Id, Contact__c
                FROM Broker__c
                WHERE Id IN :brokerIds
            ]);

        List<Event> eventsToInsert = new List<Event>();
        List<Integer> eventRequestIndexes = new List<Integer>();
        for (Integer i = 0; i < requests.size(); i++) {
            Response resp = responses[i];
            if (!String.isBlank(resp.errorMessage)) {
                continue;
            }

            Request req = requests[i];
            if (req.startDateTime == null) {
                resp.errorMessage = 'startDateTime is required.';
                continue;
            }
            if (req.startDateTime <= System.now()) {
                resp.errorMessage = 'startDateTime must be in the future.';
                continue;
            }

            Id propertyId = parseId(req.propertyId);
            Property__c propertyRecord = propertiesById.get(propertyId);
            if (propertyRecord == null) {
                resp.errorMessage = 'Property not found for provided propertyId.';
                continue;
            }
            if (propertyRecord.Broker__c == null) {
                resp.errorMessage = 'No broker is set on the property.';
                continue;
            }

            Broker__c brokerRecord = brokersById.get(propertyRecord.Broker__c);
            if (brokerRecord == null || brokerRecord.Contact__c == null) {
                resp.errorMessage = 'No broker contact found on the property broker.';
                continue;
            }

            Integer duration = req.durationMinutes != null && req.durationMinutes > 0
                ? req.durationMinutes
                : 30;

            Event eventRecord = new Event(
                WhatId = propertyRecord.Id,
                WhoId = brokerRecord.Contact__c,
                Subject = String.isBlank(req.subject) ? 'Property Showing' : req.subject,
                Description = req.eventDescription,
                StartDateTime = req.startDateTime,
                EndDateTime = req.startDateTime.addMinutes(duration)
            );
            eventsToInsert.add(eventRecord);
            eventRequestIndexes.add(i);
        }

        if (!eventsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(eventsToInsert, false);
            for (Integer pos = 0; pos < saveResults.size(); pos++) {
                Integer reqIdx = eventRequestIndexes[pos];
                Response resp = responses[reqIdx];
                if (saveResults[pos].isSuccess()) {
                    resp.eventId = String.valueOf(saveResults[pos].getId());
                    resp.confirmationMessage = 'Created event ' + resp.eventId + '.';
                } else {
                    resp.errorMessage = saveResults[pos].getErrors()[0].getMessage();
                }
            }
        }

        return responses;
    }

    private static Id parseId(String candidate) {
        try {
            return (Id) candidate?.trim();
        } catch (Exception e) {
            return null;
        }
    }
}
