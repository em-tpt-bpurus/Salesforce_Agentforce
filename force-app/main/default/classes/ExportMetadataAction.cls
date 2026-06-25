/**
 * ExportMetadataAction
 *
 * Saves the metadata export to Salesforce Files (ContentVersion).
 * Supports CSV, JSON, and TXT formats.
 * The file appears in the org's Files tab and is shareable via Chatter.
 *
 * Called by: metadataDashboard LWC via saveToFiles import
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ExportMetadataAction {

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
    }

    @AuraEnabled
    public static SaveResult saveToFiles(String fileName, String fileContent, String fileType) {
        SaveResult res = new SaveResult();

        if (String.isBlank(fileName)) {
            res.success = false;
            res.message = 'File name is required.';
            return res;
        }
        if (String.isBlank(fileContent)) {
            res.success = false;
            res.message = 'No content to save. Please load data in a tab or ask the agent first.';
            return res;
        }

        try {
            // Normalise extension — never double-append
            String ext      = String.isBlank(fileType) ? MetadataConstants.FORMAT_CSV : fileType.toLowerCase().trim();
            String baseName = fileName.endsWith('.' + ext)
                              ? fileName
                              : (fileName.contains('.') ? fileName.substringBeforeLast('.') : fileName) + '.' + ext;

            // Determine MIME type for PathOnClient so Salesforce previews it correctly
            String mime = ext == MetadataConstants.FORMAT_JSON ? MetadataConstants.MIME_JSON
                        : ext == MetadataConstants.FORMAT_TXT  ? MetadataConstants.MIME_TXT
                        : MetadataConstants.MIME_CSV;

            ContentVersion cv  = new ContentVersion();
            cv.Title           = baseName;
            cv.PathOnClient    = baseName;
            cv.VersionData     = Blob.valueOf(fileContent);
            cv.IsMajorVersion  = true;
            cv.ContentLocation = MetadataConstants.CONTENT_LOCATION;          // S = Salesforce storage
            insert cv;

            res.success = true;
            res.message = 'Saved: ' + baseName;

        } catch (DmlException dmlEx) {
            res.success = false;
            res.message = 'Save failed (DML): ' + dmlEx.getDmlMessage(0);
        } catch (Exception ex) {
            res.success = false;
            res.message = 'Save failed: ' + ex.getMessage();
        }

        return res;
    }
}