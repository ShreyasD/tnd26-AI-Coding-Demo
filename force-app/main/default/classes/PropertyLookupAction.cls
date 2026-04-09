global with sharing class PropertyLookupAction {
    global class Request {
        @InvocableVariable(required=true)
        public String searchTerm;
    }

    global class Response {
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

    @InvocableMethod(label='Find Property')
    global static List<Response> findProperty(List<Request> requests) {
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
            resp.errorMessage = 'A search term is required. Please provide a property name or address.';
            return resp;
        }

        String escapedTerm = '%' + escapeLike(req.searchTerm.trim()) + '%';
        List<Property__c> matches = [
            SELECT Id, Name, Address__c, City__c, State__c
            FROM Property__c
            WHERE Name LIKE :escapedTerm
               OR Address__c LIKE :escapedTerm
               OR City__c LIKE :escapedTerm
            ORDER BY Name ASC
            LIMIT 10
        ];

        resp.matchCount = matches.size();

        if (matches.isEmpty()) {
            resp.errorMessage = 'No properties found matching "' + req.searchTerm.trim()
                + '". Try a different name or address.';
            return resp;
        }

        if (matches.size() == 1) {
            Property__c p = matches[0];
            resp.propertyId = p.Id;
            resp.propertyName = p.Name;
            resp.propertyAddress = formatAddress(p);
            return resp;
        }

        List<String> lines = new List<String>();
        for (Integer i = 0; i < matches.size(); i++) {
            Property__c p = matches[i];
            lines.add((i + 1) + '. ' + p.Name + ' — ' + formatAddress(p));
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