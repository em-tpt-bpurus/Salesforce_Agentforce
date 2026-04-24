public without sharing class DeleteCustomFieldAction {

    public class DeleteFieldRequest {
        @InvocableVariable(label='Object API Name' description='API name of the object (e.g. Account, MyObject__c)')
        public String objectName;

        @InvocableVariable(label='Field Developer Name' description='DeveloperName of the field (without __c)')
        public String fieldName;
    }

    public class DeleteFieldOutput {
        @AuraEnabled @InvocableVariable(label='Success')
        public Boolean success;

        @AuraEnabled @InvocableVariable(label='Message')
        public String message;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Delete Custom Field' description='Deletes a custom field by Object and Field DeveloperName')
    public static List<DeleteFieldOutput> deleteField(List<DeleteFieldRequest> requests) {
        List<DeleteFieldOutput> outputs = new List<DeleteFieldOutput>();

        for (DeleteFieldRequest req : requests) {
            DeleteFieldOutput out = new DeleteFieldOutput();

            if (String.isBlank(req.objectName) || String.isBlank(req.fieldName)) {
                out.success = false;
                out.message = 'Both Object Name and Field Name must be provided.';
            } else {
                try {
                    MetadataEngine.DeleteResult r = MetadataEngine.deleteCustomFieldByName(
                        req.objectName.trim(),
                        req.fieldName.trim()
                    );
                    out.success = r.success;
                    out.message = r.message;
                } catch (Exception e) {
                    out.success = false;
                    out.message = 'Unexpected error: ' + e.getMessage();
                }
            }

            outputs.add(out);
        }
        return outputs;
    }

    // ── Called by LWC via @AuraEnabled ─────────────────────────
    @AuraEnabled(cacheable=false)
    public static DeleteFieldOutput deleteFieldFromLWC(String objectName, String fieldName) {
        DeleteFieldOutput out = new DeleteFieldOutput();

        if (String.isBlank(objectName) || String.isBlank(fieldName)) {
            out.success = false;
            out.message = 'Both Object Name and Field Name must be provided.';
            return out;
        }

        try {
            MetadataEngine.DeleteResult r = MetadataEngine.deleteCustomFieldByName(
                objectName.trim(),
                fieldName.trim()
            );
            out.success = r.success;
            out.message = r.message;
        } catch (Exception e) {
            out.success = false;
            out.message = 'Unexpected error: ' + e.getMessage();
        }

        return out;
    }
}