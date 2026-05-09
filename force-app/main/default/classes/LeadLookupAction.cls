global with sharing class LeadLookupAction {
    private class SearchCriteria {
        String leadTerm;
        String propertyTerm;
    }

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

        SearchCriteria criteria = parseSearchCriteria(req.searchTerm.trim());
        String escapedLeadTerm = '%' + escapeLike(criteria.leadTerm) + '%';
        String escapedPropertyTerm = String.isBlank(criteria.propertyTerm)
            ? null
            : '%' + escapeLike(criteria.propertyTerm) + '%';

        List<Lead> matches;
        if (String.isBlank(escapedPropertyTerm)) {
            matches = [
                SELECT Id, Name,
                       Property__c, Property__r.Name,
                       Property__r.Address__c, Property__r.City__c, Property__r.State__c
                FROM Lead
                WHERE Name LIKE :escapedLeadTerm
                ORDER BY Name ASC
                LIMIT 10
            ];
        } else {
            matches = [
                SELECT Id, Name,
                       Property__c, Property__r.Name,
                       Property__r.Address__c, Property__r.City__c, Property__r.State__c
                FROM Lead
                WHERE Name LIKE :escapedLeadTerm
                    AND Property__c != null
                    AND (
                        Property__r.Name LIKE :escapedPropertyTerm
                        OR Property__r.Address__c LIKE :escapedPropertyTerm
                        OR Property__r.City__c LIKE :escapedPropertyTerm
                    )
                ORDER BY Name ASC
                LIMIT 10
            ];
        }

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

    private static SearchCriteria parseSearchCriteria(String searchTerm) {
        SearchCriteria criteria = new SearchCriteria();
        criteria.leadTerm = searchTerm;

        for (String delimiter : new List<String>{ ' assigned to ', ' for property ', ' at property ' }) {
            Integer delimiterIdx = searchTerm.toLowerCase().indexOf(delimiter);
            if (delimiterIdx > 0) {
                String leadTerm = searchTerm.substring(0, delimiterIdx).trim();
                String propertyTerm = searchTerm.substring(delimiterIdx + delimiter.length()).trim();
                if (String.isNotBlank(leadTerm) && String.isNotBlank(propertyTerm)) {
                    criteria.leadTerm = stripWrappingQuotes(leadTerm);
                    criteria.propertyTerm = stripWrappingQuotes(propertyTerm);
                    return criteria;
                }
            }
        }

        criteria.leadTerm = stripWrappingQuotes(criteria.leadTerm);
        return criteria;
    }

    private static String stripWrappingQuotes(String value) {
        if (String.isBlank(value)) {
            return value;
        }

        String trimmedValue = value.trim();
        if (
            trimmedValue.length() >= 2 &&
            (
                (trimmedValue.startsWith('"') && trimmedValue.endsWith('"')) ||
                (trimmedValue.startsWith('\'') && trimmedValue.endsWith('\''))
            )
        ) {
            return trimmedValue.substring(1, trimmedValue.length() - 1).trim();
        }
        return trimmedValue;
    }

    private static String escapeLike(String input) {
        return input.replaceAll('\'', '\\\\\'')
                    .replaceAll('%', '\\%')
                    .replaceAll('_', '\\_');
    }
}
