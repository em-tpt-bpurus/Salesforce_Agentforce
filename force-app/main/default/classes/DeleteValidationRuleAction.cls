public without sharing class DeleteValidationRuleAction {
    public class DeleteVRRequest {
        @InvocableVariable(label='Object API Name' description='API name of the object (e.g. Account)')
        public String objectName;
        @InvocableVariable(label='Validation Rule Name' description='ValidationName of the rule')
        public String ruleName;
    }
    public class DeleteVROutput {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Message') public String  message;
    }
    @InvocableMethod(label='Delete Validation Rule' description='Deletes a Validation Rule by Object and Rule Name')
    public static List<DeleteVROutput> deleteVR(List<DeleteVRRequest> requests) {
        List<DeleteVROutput> outputs = new List<DeleteVROutput>();
        for (DeleteVRRequest req : requests) {
            DeleteVROutput out = new DeleteVROutput();
            if (String.isBlank(req.objectName) || String.isBlank(req.ruleName)) {
                out.success = false; out.message = 'Both Object Name and Rule Name must be provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteValidationRuleByName(req.objectName.trim(), req.ruleName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }
}