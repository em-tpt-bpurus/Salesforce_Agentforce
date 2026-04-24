public without sharing class DeleteCustomObjectAction {

    public class DeleteObjectRequest {
        @InvocableVariable(label='Object Developer Name' description='DeveloperName of the custom object (without __c, e.g. MyObject)')
        public String objectName;
    }

    public class DeleteObjectOutput {
        @AuraEnabled @InvocableVariable(label='Success')
        public Boolean success;

        @AuraEnabled @InvocableVariable(label='Message')
        public String message;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Delete Custom Object' description='Deletes a custom object by its DeveloperName')
    public static List<DeleteObjectOutput> deleteObject(List<DeleteObjectRequest> requests) {
        List<DeleteObjectOutput> outputs = new List<DeleteObjectOutput>();

        for (DeleteObjectRequest req : requests) {
            DeleteObjectOutput out = new DeleteObjectOutput();

            if (String.isBlank(req.objectName)) {
                out.success = false;
                out.message = 'Object Developer Name must be provided.';
            } else {
                try {
                    MetadataEngine.DeleteResult r = MetadataEngine.deleteCustomObjectByName(
                        req.objectName.trim().replace(' ', '_') // ← space to underscore
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
    public static DeleteObjectOutput deleteObjectFromLWC(String objectName) {
        DeleteObjectOutput out = new DeleteObjectOutput();

        if (String.isBlank(objectName)) {
            out.success = false;
            out.message = 'Object Developer Name must be provided.';
            return out;
        }

        try {
            MetadataEngine.DeleteResult r = MetadataEngine.deleteCustomObjectByName(
                objectName.trim().replace(' ', '_') // ← space to underscore
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