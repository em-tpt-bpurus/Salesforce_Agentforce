public without sharing class DeleteCustomObjectAction {
    public class DeleteObjectRequest {
        @InvocableVariable(label='Object Developer Name' description='DeveloperName of the custom object (without __c)')
        public String objectName;
    }
    public class DeleteObjectOutput {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Message') public String  message;
    }
    @InvocableMethod(label='Delete Custom Object' description='Permanently deletes a custom object and all its data. Use with extreme caution.')
    public static List<DeleteObjectOutput> deleteObject(List<DeleteObjectRequest> requests) {
        List<DeleteObjectOutput> outputs = new List<DeleteObjectOutput>();
        for (DeleteObjectRequest req : requests) {
            DeleteObjectOutput out = new DeleteObjectOutput();
            if (String.isBlank(req.objectName)) {
                out.success = false; out.message = 'Object name was not provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteCustomObjectByName(req.objectName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }
}