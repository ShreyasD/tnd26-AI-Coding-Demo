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
            req.brokerContactId = brokerRecord.Contact__c;

            Integer duration = req.durationMinutes != null && req.durationMinutes > 0
                ? req.durationMinutes
                : 30;

            Event eventRecord = new Event(
                WhatId = propertyRecord.Id,
                Subject = String.isBlank(req.subject) ? 'Property Showing' : req.subject,
                Description = req.eventDescription,
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
                    'leadId' => req.leadId,
                    'brokerContactId' => req.brokerContactId,
                    'startDateTime' => String.valueOf(req.startDateTime),
                    'durationMinutes' => duration
                }
            );
            // #endregion
            eventsToInsert.add(eventRecord);
            eventRequestIndexes.add(i);
        }

        if (!eventsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(eventsToInsert, false);
            List<EventRelation> leadRelations = new List<EventRelation>();
            for (Integer pos = 0; pos < saveResults.size(); pos++) {
                Integer reqIdx = eventRequestIndexes[pos];
                Response resp = responses[reqIdx];
                if (saveResults[pos].isSuccess()) {
                    resp.eventId = String.valueOf(saveResults[pos].getId());
                    String baseUrl = URL.getOrgDomainURL().toExternalForm();
                    resp.eventLink = baseUrl + '/lightning/r/Event/' + resp.eventId + '/view';
                    resp.confirmationMessage = 'Property showing scheduled! '
                        + '[View Event](' + resp.eventLink + ')';
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
                        SELECT Id, WhoId, WhatId, Subject, Description, StartDateTime, EndDateTime
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
                            'errorMessage' => resp.errorMessage
                        }
                    );
                    // #endregion

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
            if (!leadRelations.isEmpty()) {
                Database.insert(leadRelations, false);
                // #region agent log
                logDebug(
                    'initial',
                    'H4,H5',
                    'PropertyShowingSchedulerAction.cls:createPropertyEvent:leadRelations',
                    'Inserted lead relations',
                    new Map<String, Object>{
                        'leadRelationCount' => leadRelations.size()
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

    private static Id parseId(String candidate) {
        try {
            return (Id) candidate?.trim();
        } catch (Exception e) {
            return null;
        }
    }
}