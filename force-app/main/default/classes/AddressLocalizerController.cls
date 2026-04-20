/**
 * AuraEnabled controller for the addressLocalizer LWC.
 *
 * Looks up a CityCentroid__c record for the user-supplied city/state, then
 * assigns each 311 Case a random latitude/longitude within MAX_RADIUS_MILES
 * of that centroid. No external API calls are made.
 *
 * Field name constants at the top of the class reflect the geolocation
 * compound sub-fields on the Case object. Update these if your org uses
 * different API names.
 *
 *   FIELD_LATITUDE   – Geolocation latitude sub-field  (e.g. MyLocation__Latitude__s)
 *   FIELD_LONGITUDE  – Geolocation longitude sub-field (e.g. MyLocation__Longitude__s)
 *   FIELD_CITY       – City text field on Case
 *   FIELD_STATE      – State text field on Case
 */
public with sharing class AddressLocalizerController {

    // ── Configuration ─────────────────────────────────────────────────────────
    private static final String FIELD_LATITUDE   = 'Location__Latitude__s';
    private static final String FIELD_LONGITUDE  = 'Location__Longitude__s';
    private static final String FIELD_CITY       = 'City__c';
    private static final String FIELD_STATE      = 'State__c';

    private static final String RECORD_TYPE_NAME = '311';
    private static final Double MAX_RADIUS_MILES = 5.0;

    // Miles per degree of latitude (constant)
    private static final Double MILES_PER_LAT_DEG = 69.0;

    // ── Public result wrapper ─────────────────────────────────────────────────

    public class LocalizeResult {
        @AuraEnabled public Integer updatedCount   { get; set; }
        @AuraEnabled public String  targetCity     { get; set; }
        @AuraEnabled public String  targetState    { get; set; }
        @AuraEnabled public String  errorMessage   { get; set; }
        @AuraEnabled public Boolean success        { get; set; }

        public LocalizeResult() {
            this.success = true;
        }
    }

    // ── AuraEnabled methods ───────────────────────────────────────────────────

    /**
     * Returns the count of 311 Case records that will be updated.
     * Used by the LWC Preview step.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getCaseCount() {
        return [
            SELECT COUNT() FROM Case
            WHERE RecordType.Name = :RECORD_TYPE_NAME
        ];
    }

    /**
     * Looks up the CityCentroid__c for the given city/state, then updates
     * every 311 Case with a random lat/long within MAX_RADIUS_MILES of
     * that centroid.
     */
    @AuraEnabled
    public static LocalizeResult relocateCases(String city, String state) {
        LocalizeResult result = new LocalizeResult();
        result.targetCity  = city;
        result.targetState = state;

        try {
            // 1. Resolve the centroid for the requested city/state
            String cleanCity  = city.trim();
            String cleanState = state.trim().toUpperCase();

            List<CityCentroid__c> centroids = [
                SELECT LatCentroid__c, LongCentroid__c
                FROM   CityCentroid__c
                WHERE  City__c  = :cleanCity
                AND    State__c = :cleanState
                LIMIT  1
            ];

            if (centroids.isEmpty()) {
                result.success      = false;
                result.errorMessage =
                    'No City Centroid record found for ' + city + ', ' + state + '. '
                    + 'Verify the city name and two-letter state abbreviation and try again.';
                return result;
            }

            Double centerLat = centroids[0].LatCentroid__c;
            Double centerLon = centroids[0].LongCentroid__c;

            // 2. Fetch all 311 Cases
            List<Case> cases = [
                SELECT Id
                FROM   Case
                WHERE  RecordType.Name = :RECORD_TYPE_NAME
            ];

            if (cases.isEmpty()) {
                result.success      = false;
                result.errorMessage = 'No Cases with the 311 record type were found in this org.';
                return result;
            }

            // 3. Assign a unique random point within the radius to each Case
            for (Case c : cases) {
                Double[] coords = randomPointInCircle(centerLat, centerLon, MAX_RADIUS_MILES);
                c.put(FIELD_LATITUDE,  coords[0]);
                c.put(FIELD_LONGITUDE, coords[1]);
                c.put(FIELD_CITY,      cleanCity);
                c.put(FIELD_STATE,     cleanState);
            }

            // 4. Bulk update — partial success so one bad record doesn't abort all
            Database.SaveResult[] saveResults = Database.update(cases, false);

            Integer successCount = 0;
            List<String> errors  = new List<String>();
            for (Database.SaveResult sr : saveResults) {
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        errors.add(err.getMessage());
                    }
                }
            }

            result.updatedCount = successCount;
            if (!errors.isEmpty()) {
                result.errorMessage =
                    successCount + ' record(s) updated successfully. '
                    + errors.size() + ' record(s) failed. Sample: '
                    + String.join(trimErrors(errors, 3), '; ');
                result.success = (successCount > 0);
            }

        } catch (Exception e) {
            result.success      = false;
            result.errorMessage = 'Unexpected error: ' + e.getMessage();
        }

        return result;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Returns a [latitude, longitude] pair chosen uniformly at random from
     * within a circle of radius maxMiles centered on (centerLat, centerLon).
     *
     * Uses the square-root trick for radius sampling so points are evenly
     * distributed over the disk rather than concentrated at the center.
     *
     * Longitude degrees shrink with latitude, so the offset is scaled by
     * cos(latitude) to keep the displacement physically accurate.
     */
    private static Double[] randomPointInCircle(
        Double centerLat, Double centerLon, Double maxMiles
    ) {
        Double r     = Math.sqrt(Math.random()) * maxMiles;
        Double theta = Math.random() * 2.0 * Math.PI;

        Double deltaLat = (r * Math.cos(theta)) / MILES_PER_LAT_DEG;
        Double deltaLon = (r * Math.sin(theta)) /
                          (MILES_PER_LAT_DEG * Math.cos(centerLat * Math.PI / 180.0));

        return new Double[]{ centerLat + deltaLat, centerLon + deltaLon };
    }

    private static List<String> trimErrors(List<String> errors, Integer max) {
        List<String> trimmed = new List<String>();
        for (Integer i = 0; i < Math.min(errors.size(), max); i++) {
            trimmed.add(errors[i]);
        }
        return trimmed;
    }
}
