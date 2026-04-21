trigger AccountMetadataTrigger on Account (before insert, before update) {
    // Sample trigger — delegates to a handler class
    // Replace with your actual trigger logic
    // AccountHandler.run(Trigger.new, Trigger.old, Trigger.operationType);
}