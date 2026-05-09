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
        // #region agent log
        logDebug(
            'initial',
            'H1,H3,H4,H5',
            'PropertyShowingSchedulerAction.cls:createPropertyEvent:entry',
            'Entered createPropertyEvent',
            new Map<String, Object>{
                'requestCount' => requests == null ? 0 : requests.size(),
                'hasRequests' => requests != null && !requests.isEmpty()
            }
        );
        // #endregion
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
<<<<<<< HEAD
                WhoId = leadRecord == null ? null : leadRecord.Id,
                WhatId = leadRecord == null ? propertyRecord.Id : null,
                Subject = eventSubject,
=======
                WhatId = propertyRecord.Id,
                Subject = String.isBlank(req.subject) ? 'Property Showing' : req.subject,
>>>>>>> origin
                Description = req.eventDescription,
                Location = propertyAddress,
                StartDateTime = req.startDateTime,
                EndDateTime = req.startDateTime.addMinutes(duration)
            );
            // #region agent log
            logDebug(
                'initial',
                'H4,H5',
                'PropertyShowingSchedulerAction.cls:createPropertyEvent:preInsert',
                'Prepared event for insert',
                new Map<String, Object>{
                    'requestIndex' => i,
                    'propertyId' => String.valueOf(propertyRecord.Id),
<<<<<<< HEAD
                    'leadId' => leadRecord == null ? null : String.valueOf(leadRecord.Id),
                    'brokerContactId' => req.brokerContactId,
                    'startDateTime' => String.valueOf(req.startDateTime),
                    'durationMinutes' => duration,
                    'subject' => eventSubject,
                    'location' => propertyAddress
=======
                    'leadId' => req.leadId,
                    'brokerContactId' => req.brokerContactId,
                    'startDateTime' => String.valueOf(req.startDateTime),
                    'durationMinutes' => duration
>>>>>>> origin
                }
            );
            // #endregion
            eventsToInsert.add(eventRecord);
            eventRequestIndexes.add(i);
        }

        if (!eventsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(eventsToInsert, false);
<<<<<<< HEAD
            List<EventRelation> relatedContacts = new List<EventRelation>();
=======
            List<EventRelation> leadRelations = new List<EventRelation>();
>>>>>>> origin
            for (Integer pos = 0; pos < saveResults.size(); pos++) {
                Integer reqIdx = eventRequestIndexes[pos];
                Response resp = responses[reqIdx];
                if (saveResults[pos].isSuccess()) {
                    resp.eventId = String.valueOf(saveResults[pos].getId());
                    String baseUrl = URL.getOrgDomainURL().toExternalForm();
                    resp.eventLink = baseUrl + '/lightning/r/Event/' + resp.eventId + '/view';
<<<<<<< HEAD
                    resp.confirmationMessage = 'Property showing scheduled! Event link: '
                        + resp.eventLink;
=======
                    resp.confirmationMessage = 'Property showing scheduled! '
                        + '[View Event](' + resp.eventLink + ')';
>>>>>>> origin
                    // #region agent log
                    logDebug(
                        'initial',
                        'H1,H2,H3,H4,H5',
                        'PropertyShowingSchedulerAction.cls:createPropertyEvent:postInsert',
                        'Event insert succeeded',
                        new Map<String, Object>{
                            'requestIndex' => reqIdx,
                            'eventId' => resp.eventId,
                            'eventLink' => resp.eventLink,
                            'leadId' => requests[reqIdx].leadId,
                            'brokerContactId' => requests[reqIdx].brokerContactId,
                            'confirmationMessage' => resp.confirmationMessage,
                            'baseUrlPresent' => !String.isBlank(baseUrl)
                        }
                    );
                    // #endregion

                    // Add the event record to the response
                    Event eventRecord = [
<<<<<<< HEAD
                        SELECT Id, WhoId, WhatId, Property__c, Subject, Description, Location, StartDateTime, EndDateTime
=======
                        SELECT Id, WhoId, WhatId, Subject, Description, StartDateTime, EndDateTime
>>>>>>> origin
                        FROM Event
                        WHERE Id = :resp.eventId
                        LIMIT 1
                    ];
                    resp.eventRecord = eventRecord;
                    // #region agent log
                    logDebug(
                        'initial',
                        'H1,H2,H3,H5',
                        'PropertyShowingSchedulerAction.cls:createPropertyEvent:responseAssembly',
                        'Assembled successful response payload',
                        new Map<String, Object>{
                            'requestIndex' => reqIdx,
                            'eventId' => resp.eventId,
                            'eventRecordId' => resp.eventRecord == null ? null : String.valueOf(resp.eventRecord.Id),
                            'eventRecordWhatId' => resp.eventRecord == null ? null : String.valueOf(resp.eventRecord.WhatId),
                            'eventRecordWhoId' => resp.eventRecord == null ? null : String.valueOf(resp.eventRecord.WhoId),
<<<<<<< HEAD
                            'eventRecordPropertyId' => resp.eventRecord == null ? null : String.valueOf(resp.eventRecord.Property__c),
=======
>>>>>>> origin
                            'errorMessage' => resp.errorMessage
                        }
                    );
                    // #endregion

<<<<<<< HEAD
                    Id brokerContactId = parseId(requests[reqIdx].brokerContactId);
                    if (brokerContactId != null) {
                        relatedContacts.add(new EventRelation(
                            EventId = saveResults[pos].getId(),
                            RelationId = brokerContactId,
                            IsInvitee = false,
                            IsParent = false,
=======
                    Id parsedLeadId = parseId(requests[reqIdx].leadId);
                    if (parsedLeadId != null) {
                        leadRelations.add(new EventRelation(
                            EventId = saveResults[pos].getId(),
                            RelationId = parsedLeadId,
                            IsInvitee = false, //(this used to be true)
                            IsParent = true,
                            IsWhat = false
                        ));

                        leadRelations.add(new EventRelation(
                            EventId = saveResults[pos].getId(),
                            RelationId = requests[reqIdx].brokerContactId,
                            IsInvitee = false, //(this used to be true)
                            IsParent = true,
>>>>>>> origin
                            IsWhat = false
                        ));
                    }
                } else {
                    resp.errorMessage = saveResults[pos].getErrors()[0].getMessage();
                    // #region agent log
                    logDebug(
                        'initial',
                        'H4,H5',
                        'PropertyShowingSchedulerAction.cls:createPropertyEvent:insertError',
                        'Event insert failed',
                        new Map<String, Object>{
                            'requestIndex' => reqIdx,
                            'errorMessage' => resp.errorMessage
                        }
                    );
                    // #endregion
                }
            }
<<<<<<< HEAD
            if (!relatedContacts.isEmpty()) {
                Database.insert(relatedContacts, false);
=======
            if (!leadRelations.isEmpty()) {
                Database.insert(leadRelations, false);
>>>>>>> origin
                // #region agent log
                logDebug(
                    'initial',
                    'H4,H5',
                    'PropertyShowingSchedulerAction.cls:createPropertyEvent:leadRelations',
                    'Inserted lead relations',
                    new Map<String, Object>{
<<<<<<< HEAD
                        'contactRelationCount' => relatedContacts.size()
=======
                        'leadRelationCount' => leadRelations.size()
>>>>>>> origin
                    }
                );
                // #endregion
            }
        }

        // #region agent log
        logDebug(
            'initial',
            'H1,H2,H3,H4,H5',
            'PropertyShowingSchedulerAction.cls:createPropertyEvent:return',
            'Returning responses to agent',
            new Map<String, Object>{
                'responseCount' => responses.size(),
                'successCount' => countSuccessResponses(responses),
                'errorCount' => countErrorResponses(responses)
            }
        );
        // #endregion
        return responses;
    }

    private static Integer countSuccessResponses(List<Response> responses) {
        Integer successCount = 0;
        for (Response responseItem : responses) {
            if (responseItem != null && String.isBlank(responseItem.errorMessage) && !String.isBlank(responseItem.eventId)) {
                successCount++;
            }
        }
        return successCount;
    }

    private static Integer countErrorResponses(List<Response> responses) {
        Integer errorCount = 0;
        for (Response responseItem : responses) {
            if (responseItem != null && !String.isBlank(responseItem.errorMessage)) {
                errorCount++;
            }
        }
        return errorCount;
    }

    private static void logDebug(
        String runId,
        String hypothesisId,
        String location,
        String message,
        Map<String, Object> data
    ) {
        System.debug(LoggingLevel.ERROR, JSON.serialize(new Map<String, Object>{
            'sessionId' => '6581d0',
            'runId' => runId,
            'hypothesisId' => hypothesisId,
            'location' => location,
            'message' => message,
            'data' => data,
            'timestamp' => Datetime.now().getTime()
        }));
    }

<<<<<<< HEAD
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

=======
>>>>>>> origin
    private static Id parseId(String candidate) {
        try {
            return (Id) candidate?.trim();
        } catch (Exception e) {
            return null;
        }
    }
}