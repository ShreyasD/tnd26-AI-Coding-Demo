public with sharing class LeadHouseCaptureController {
    public class PropertyDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal beds;
        @AuraEnabled public String style;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String thumbnailUrl;
        @AuraEnabled public List<String> tags;
    }

    public class CreateLeadResult {
        @AuraEnabled public Id propertyId;
        @AuraEnabled public Id leadId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctStylesFromTags() {
        // Derive style options from unique values in Property__c.Tags__c (semicolon- or comma-separated)
        Set<String> styles = new Set<String>();
        for (AggregateResult ar : [
            SELECT Tags__c agg
            FROM Property__c
            WHERE Tags__c != null
            GROUP BY Tags__c
        ]) {
            String tags = (String) ar.get('agg');
            if (String.isBlank(tags)) continue;
            // Split by semicolon or comma
            for (String token : tags.split('[;,]')) {
                String val = token != null ? token.trim() : null;
                if (!String.isBlank(val)) {
                    styles.add(val);
                }
            }
        }
        List<String> out = new List<String>(styles);
        out.sort();
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<PropertyDTO> searchProperties(String cityOrState, Integer minBedrooms, String style, Decimal minPrice, Decimal maxPrice) {
        String likeFilter = String.isBlank(cityOrState) ? null : '%' + cityOrState.trim() + '%';
        Boolean hasCityState = !String.isBlank(cityOrState);
        Boolean hasBedrooms = (minBedrooms != null && minBedrooms >= 0);
        Boolean hasStyle = !String.isBlank(style);
        Boolean hasMin = (minPrice != null);
        Boolean hasMax = (maxPrice != null);

        String soql = 'SELECT Id, Name, Price__c, Beds__c, City__c, State__c, Thumbnail__c, Tags__c ' +
                      'FROM Property__c WHERE Id != null';

        if (hasCityState) {
            // Match on City__c or State__c or Address fields as fallback
            soql += ' AND (City__c LIKE :likeFilter OR State__c LIKE :likeFilter OR Address__c LIKE :likeFilter)';
        }
        if (hasBedrooms) {
            soql += ' AND Beds__c >= :minBedrooms';
        }
        if (hasStyle) {
            // Match style contained within Tags__c tokens only (Style__c may not exist)
            String styleLike = '%' + style + '%';
            soql += ' AND (Tags__c LIKE :styleLike)';
        }
        if (hasMin) {
            soql += ' AND Price__c >= :minPrice';
        }
        if (hasMax) {
            soql += ' AND Price__c <= :maxPrice';
        }
        soql += ' ORDER BY Price__c ASC NULLS LAST LIMIT 25';

        List<PropertyDTO> out = new List<PropertyDTO>();
        for (SObject sob : Database.query(soql)) {
            Property__c p = (Property__c) sob;
            PropertyDTO dto = new PropertyDTO();
            dto.id = p.Id;
            dto.name = p.Name;
            dto.price = p.Price__c;
            dto.beds = p.Beds__c;
            // Derive style as first token in Tags__c when available
            if (p.Tags__c != null) {
                List<String> tokens = p.Tags__c.split('[;,]');
                dto.style = (tokens.isEmpty() || String.isBlank(tokens[0])) ? null : tokens[0].trim();
            } else {
                dto.style = null;
            }
            dto.city = p.City__c;
            dto.state = p.State__c;
            dto.thumbnailUrl = (String) p.get('Thumbnail__c');
            dto.tags = new List<String>();
            if (p.Tags__c != null) {
                for (String token : p.Tags__c.split('[;,]')) {
                    String val = token != null ? token.trim() : null;
                    if (!String.isBlank(val)) dto.tags.add(val);
                }
            }
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled
    public static List<CreateLeadResult> createLeadsForProperties(List<Id> propertyIds, String cityOrState, Integer bedrooms, String style, Decimal minPrice, Decimal maxPrice) {
        if (propertyIds == null || propertyIds.isEmpty()) {
            throw new AuraHandledException('No properties selected.');
        }
        // Enforce max 3
        if (propertyIds.size() > 3) {
            throw new AuraHandledException('You can only submit up to 3 properties at a time.');
        }

        Map<Id, Property__c> props = new Map<Id, Property__c>([
            SELECT Id, Name, Price__c, Beds__c, City__c, State__c
            FROM Property__c WHERE Id IN :propertyIds
        ]);

        List<Lead> toInsert = new List<Lead>();
        for (Id pid : propertyIds) {
            Property__c p = props.get(pid);
            if (p == null) continue;

            Lead l = new Lead();
            l.LastName = 'House Inquiry';
            l.Company = 'Dreamhouse Prospect';
            // Optional helpful fields
            l.Status = 'Open - Not Contacted';
            l.Description = buildDescription(p, cityOrState, bedrooms, style, minPrice, maxPrice);
            toInsert.add(l);
        }

        List<CreateLeadResult> results = new List<CreateLeadResult>();
        try {
            insert toInsert;
            for (Integer i = 0; i < toInsert.size(); i++) {
                CreateLeadResult r = new CreateLeadResult();
                r.propertyId = propertyIds[i];
                r.leadId = toInsert[i].Id;
                r.success = true;
                r.message = 'Created';
                results.add(r);
            }
        } catch (DmlException e) {
            // Partial success handling
            Integer idx = 0;
            for (Id pid : propertyIds) {
                CreateLeadResult r = new CreateLeadResult();
                r.propertyId = pid;
                r.success = (idx < toInsert.size() && toInsert[idx].Id != null);
                r.leadId = (idx < toInsert.size()) ? toInsert[idx].Id : null;
                r.message = r.success ? 'Created' : 'Failed: ' + e.getDmlMessage(Math.min(idx, e.getNumDml()) - 1);
                results.add(r);
                idx++;
            }
        }
        return results;
    }

    private static String buildDescription(Property__c p, String cityOrState, Integer bedrooms, String style, Decimal minPrice, Decimal maxPrice) {
        List<String> lines = new List<String>();
        lines.add('Lead generated from Dreamhouse Home LWC.');
        lines.add('Selected Property: ' + p.Name + ' (' + String.valueOf(p.Id) + ')');
        lines.add('Property Details: Price=' + String.valueOf(p.Price__c) + ', Beds=' + String.valueOf(p.Beds__c) + ', ' +
                  'City=' + p.City__c + ', State=' + p.State__c);
        lines.add('Buyer Preferences:');
        lines.add('- City/State: ' + (String.isBlank(cityOrState) ? 'Any' : cityOrState));
        lines.add('- Bedrooms: ' + (bedrooms == null ? 'Any' : String.valueOf(bedrooms) + '+'));
        lines.add('- Style: ' + (String.isBlank(style) ? 'Any' : style));
        String pricePref;
        if (minPrice != null && maxPrice != null) pricePref = '$' + minPrice.setScale(0) + ' to $' + maxPrice.setScale(0);
        else if (minPrice != null) pricePref = '$' + minPrice.setScale(0) + '+';
        else if (maxPrice != null) pricePref = '<= $' + maxPrice.setScale(0);
        else pricePref = 'Any';
        lines.add('- Price Range: ' + pricePref);
        // Safe join for older Apex versions
        String out = '';
        for (Integer i = 0; i < lines.size(); i++) {
            out += (i == 0 ? '' : '\n') + lines[i];
        }
        return out;
    }
}