public without sharing class DeactivateProfileAction {
    public class DeactivateProfileRequest {
        @InvocableVariable(label='Profile Name' description='Name of the Profile to empty and deactivate')
        public String profileName;
        @InvocableVariable(label='Fallback Profile Name' description='Profile to reassign existing users to (e.g. Standard User)')
        public String fallbackProfileName;
    }
    public class DeactivateProfileOutput {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Message') public String  message;
    }
    @InvocableMethod(label='Deactivate Profile' description='Reassigns all users from a Profile to a fallback Profile so it can be deleted in Setup')
    public static List<DeactivateProfileOutput> deactivateProfile(List<DeactivateProfileRequest> requests) {
        List<DeactivateProfileOutput> outputs = new List<DeactivateProfileOutput>();
        for (DeactivateProfileRequest req : requests) {
            DeactivateProfileOutput out = new DeactivateProfileOutput();
            if (String.isBlank(req.profileName) || String.isBlank(req.fallbackProfileName)) {
                out.success = false; out.message = 'Both Profile Name and Fallback Profile Name must be provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deactivateProfileByName(req.profileName.trim(), req.fallbackProfileName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }
}