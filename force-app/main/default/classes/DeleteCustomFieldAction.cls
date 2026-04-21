public without sharing class DeleteCustomFieldAction {
    public class DeleteFieldRequest {
        @InvocableVariable(label='Object API Name' description='API name of the object (e.g. Account, MyObject__c)')
        public String objectName;
        @InvocableVariable(label='Field Developer Name' description='DeveloperName of the field (without __c)')
        public String fieldName;
    }
    public class DeleteFieldOutput {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Message') public String  message;
    }
    @InvocableMethod(label='Delete Custom Field' description='Deletes a custom field by Object and Field DeveloperName')
    public static List<DeleteFieldOutput> deleteField(List<DeleteFieldRequest> requests) {
        List<DeleteFieldOutput> outputs = new List<DeleteFieldOutput>();
        for (DeleteFieldRequest req : requests) {
            DeleteFieldOutput out = new DeleteFieldOutput();
            if (String.isBlank(req.objectName) || String.isBlank(req.fieldName)) {
                out.success = false; out.message = 'Both Object Name and Field Name must be provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteCustomFieldByName(req.objectName.trim(), req.fieldName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }
}