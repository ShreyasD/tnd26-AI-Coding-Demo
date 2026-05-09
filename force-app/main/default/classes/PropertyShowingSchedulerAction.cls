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

        @InvocableVariable
        public String leadId;

        public String brokerContactId;
    }

    global class Response {
        @InvocableVariable
        public String eventId = '';

        @InvocableVariable
        public String eventLink = '';

        @InvocableVariable
        public Event eventRecord = null;

        @InvocableVariable
        public String confirmationMessage = '';

        @InvocableVariable
        public String errorMessage = '';
    }

    @InvocableMethod(label='Create Property Event')
    global static List<Response> createPropertyEvent(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Response>();
        }

        List<Response> responses = new List<Response>();
        Set<Id> propertyIds = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();
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
            Id parsedLeadId = parseId(req.leadId);
            if (parsedLeadId != null) {
                leadIds.add(parsedLeadId);
            }
        }

        Map<Id, Property__c> propertiesById = propertyIds.isEmpty()
            ? new Map<Id, Property__c>()
            : new Map<Id, Property__c>([
                SELECT Id, Name, Address__c, City__c, State__c, Zip__c, Broker__c
                FROM Property__c
                WHERE Id IN :propertyIds
            ]);

        Map<Id, Lead> leadsById = leadIds.isEmpty()
            ? new Map<Id, Lead>()
            : new Map<Id, Lead>([
                SELECT Id, Name
                FROM Lead
                WHERE Id IN :leadIds
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
            req.brokerContactId = brokerRecord.Contact__c;

            Integer duration = req.durationMinutes != null && req.durationMinutes > 0
                ? req.durationMinutes
                : 30;
            Id parsedLeadId = parseId(req.leadId);
            Lead leadRecord = parsedLeadId == null ? null : leadsById.get(parsedLeadId);
            String propertyAddress = buildPropertyAddress(propertyRecord);
            String eventSubject = buildEventSubject(leadRecord, propertyRecord);

            Event eventRecord = new Event(
                WhoId = leadRecord == null ? null : leadRecord.Id,
                WhatId = leadRecord == null ? propertyRecord.Id : null,
                Subject = eventSubject,
                Description = req.eventDescription,
                Location = propertyAddress,
                StartDateTime = req.startDateTime,
                EndDateTime = req.startDateTime.addMinutes(duration)
            );
            eventsToInsert.add(eventRecord);
            eventRequestIndexes.add(i);
        }

        if (!eventsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(eventsToInsert, false);
            List<EventRelation> relatedContacts = new List<EventRelation>();
            for (Integer pos = 0; pos < saveResults.size(); pos++) {
                Integer reqIdx = eventRequestIndexes[pos];
                Response resp = responses[reqIdx];
                if (saveResults[pos].isSuccess()) {
                    resp.eventId = String.valueOf(saveResults[pos].getId());
                    String baseUrl = URL.getOrgDomainURL().toExternalForm();
                    resp.eventLink = baseUrl + '/lightning/r/Event/' + resp.eventId + '/view';
                    resp.confirmationMessage = 'Property showing scheduled! Event link: '
                        + resp.eventLink;

                    // Add the event record to the response
                    Event eventRecord = [
                        SELECT Id, WhoId, WhatId, Property__c, Subject, Description, Location, StartDateTime, EndDateTime
                        FROM Event
                        WHERE Id = :resp.eventId
                        LIMIT 1
                    ];
                    resp.eventRecord = eventRecord;

                    Id brokerContactId = parseId(requests[reqIdx].brokerContactId);
                    if (brokerContactId != null) {
                        relatedContacts.add(new EventRelation(
                            EventId = saveResults[pos].getId(),
                            RelationId = brokerContactId,
                            IsInvitee = false,
                            IsParent = false,
                            IsWhat = false
                        ));
                    }
                } else {
                    resp.errorMessage = saveResults[pos].getErrors()[0].getMessage();
                }
            }
            if (!relatedContacts.isEmpty()) {
                Database.insert(relatedContacts, false);
            }
        }

        return responses;
    }

    private static String buildEventSubject(Lead leadRecord, Property__c propertyRecord) {
        String propertyName = propertyRecord == null || String.isBlank(propertyRecord.Name)
            ? 'Property'
            : propertyRecord.Name.trim();
        if (leadRecord != null && !String.isBlank(leadRecord.Name)) {
            return 'Property Showing - ' + leadRecord.Name.trim() + ' (' + propertyName + ')';
        }
        return 'Property Showing (' + propertyName + ')';
    }

    private static String buildPropertyAddress(Property__c propertyRecord) {
        if (propertyRecord == null) {
            return null;
        }
        List<String> addressParts = new List<String>();
        if (!String.isBlank(propertyRecord.Address__c)) {
            addressParts.add(propertyRecord.Address__c.trim());
        }
        if (!String.isBlank(propertyRecord.City__c)) {
            addressParts.add(propertyRecord.City__c.trim());
        }
        if (!String.isBlank(propertyRecord.State__c)) {
            addressParts.add(propertyRecord.State__c.trim());
        }
        if (!String.isBlank(propertyRecord.Zip__c)) {
            addressParts.add(propertyRecord.Zip__c.trim());
        }
        return addressParts.isEmpty() ? null : String.join(addressParts, ', ');
    }

    private static Id parseId(String candidate) {
        try {
            return (Id) candidate?.trim();
        } catch (Exception e) {
            return null;
        }
    }
}