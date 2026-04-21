public without sharing class DeleteAuraAction {
    public class DeleteAuraRequest {
        @InvocableVariable(label='Aura Component Name' description='DeveloperName of the Aura component to delete')
        public String componentName;
    }
    public class DeleteAuraOutput {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Message') public String  message;
    }
    @InvocableMethod(label='Delete Aura Component' description='Deletes an Aura (Lightning) component by its DeveloperName')
    public static List<DeleteAuraOutput> deleteAura(List<DeleteAuraRequest> requests) {
        List<DeleteAuraOutput> outputs = new List<DeleteAuraOutput>();
        for (DeleteAuraRequest req : requests) {
            DeleteAuraOutput out = new DeleteAuraOutput();
            if (String.isBlank(req.componentName)) {
                out.success = false; out.message = 'Aura component name was not provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteAuraByName(req.componentName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }
}