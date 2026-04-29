public without sharing class DeleteLwcAction {
    public class DeleteLwcRequest {
        @InvocableVariable(label='LWC Component Name' description='DeveloperName of the LWC component to delete')
        public String componentName;
    }
    public class DeleteLwcOutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }
    @InvocableMethod(label='Delete LWC Component' description='Deletes a Lightning Web Component by its DeveloperName')
    public static List<DeleteLwcOutput> deleteLwc(List<DeleteLwcRequest> requests) {
        List<DeleteLwcOutput> outputs = new List<DeleteLwcOutput>();
        for (DeleteLwcRequest req : requests) {
            DeleteLwcOutput out = new DeleteLwcOutput();
            if (String.isBlank(req.componentName)) {
                out.success = false; out.message = 'LWC component name was not provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteLwcByName(req.componentName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    @AuraEnabled(cacheable=false)
    public static DeleteLwcOutput deleteLwcFromLWC(String componentName) {
        DeleteLwcOutput out = new DeleteLwcOutput();
        if (String.isBlank(componentName)) {
            out.success = false; out.message = 'LWC component name was not provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deleteLwcByName(componentName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }
}