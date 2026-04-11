global with sharing class LeadLookupAction {
    global class Request {
        @InvocableVariable(required=true)
        public String searchTerm;
    }

    global class Response {
        @InvocableVariable
        public String leadId = '';

        @InvocableVariable
        public String leadName = '';

        @InvocableVariable
        public String propertyId = '';

        @InvocableVariable
        public String propertyName = '';

        @InvocableVariable
        public String propertyAddress = '';

        @InvocableVariable
        public Integer matchCount = 0;

        @InvocableVariable
        public String matchList = '';

        @InvocableVariable
        public String errorMessage = '';
    }

    @InvocableMethod(label='Find Lead')
    global static List<Response> findLead(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Response>();
        }

        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(processRequest(req));
        }
        return responses;
    }

    private static Response processRequest(Request req) {
        Response resp = new Response();
        if (req == null || String.isBlank(req.searchTerm)) {
            resp.errorMessage = 'A search term is required. Please provide a lead name.';
            return resp;
        }

        String escapedTerm = '%' + escapeLike(req.searchTerm.trim()) + '%';
        List<Lead> matches = [
            SELECT Id, Name,
                   Property__c, Property__r.Name,
                   Property__r.Address__c, Property__r.City__c, Property__r.State__c
            FROM Lead
            WHERE Name LIKE :escapedTerm
            ORDER BY Name ASC
            LIMIT 10
        ];

        resp.matchCount = matches.size();

        if (matches.isEmpty()) {
            resp.errorMessage = 'No leads found matching "' + req.searchTerm.trim()
                + '". Try a different name.';
            return resp;
        }

        if (matches.size() == 1) {
            Lead ld = matches[0];
            resp.leadId = ld.Id;
            resp.leadName = ld.Name;
            if (ld.Property__c != null) {
                resp.propertyId = ld.Property__c;
                resp.propertyName = ld.Property__r.Name;
                resp.propertyAddress = formatAddress(ld.Property__r);
            } else {
                resp.errorMessage = 'Lead "' + ld.Name + '" does not have a property assigned.';
            }
            return resp;
        }

        List<String> lines = new List<String>();
        for (Integer i = 0; i < matches.size(); i++) {
            Lead ld = matches[i];
            String propertyInfo = ld.Property__c != null
                ? ' — Property: ' + ld.Property__r.Name
                : ' — No property';
            lines.add((i + 1) + '. ' + ld.Name + propertyInfo);
        }
        resp.matchList = String.join(lines, '\n');
        return resp;
    }

    private static String formatAddress(Property__c p) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(p.Address__c)) {
            parts.add(p.Address__c);
        }
        if (String.isNotBlank(p.City__c)) {
            parts.add(p.City__c);
        }
        if (String.isNotBlank(p.State__c)) {
            parts.add(p.State__c);
        }
        return parts.isEmpty() ? '' : String.join(parts, ', ');
    }

    private static String escapeLike(String input) {
        return input.replaceAll('\'', '\\\\\'')
                    .replaceAll('%', '\\%')
                    .replaceAll('_', '\\_');
    }
}
