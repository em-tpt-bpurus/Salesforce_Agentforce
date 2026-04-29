public without sharing class DeletePermissionSetAction {
    public class DeletePSRequest {
        @InvocableVariable(label='Permission Set Name' description='API Name of the Permission Set to delete')
        public String permSetName;
    }
    public class DeletePSOutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }
    @InvocableMethod(label='Delete Permission Set' description='Removes all assignments then deletes a custom Permission Set')
    public static List<DeletePSOutput> deletePS(List<DeletePSRequest> requests) {
        List<DeletePSOutput> outputs = new List<DeletePSOutput>();
        for (DeletePSRequest req : requests) {
            DeletePSOutput out = new DeletePSOutput();
            if (String.isBlank(req.permSetName)) {
                out.success = false; out.message = 'Permission Set name was not provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deletePermissionSetByName(req.permSetName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    @AuraEnabled(cacheable=false)
    public static DeletePSOutput deletePermSetFromLWC(String permSetName) {
        DeletePSOutput out = new DeletePSOutput();
        if (String.isBlank(permSetName)) {
            out.success = false; out.message = 'Permission Set name was not provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deletePermissionSetByName(permSetName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }
}