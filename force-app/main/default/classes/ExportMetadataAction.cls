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
        @AuraEnabled public String  fileUrl;
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
            res.message = 'No data to export.';
            return res;
        }

        try {
            String ext      = String.isBlank(fileType) ? 'csv' : fileType.toLowerCase();
            String fullName = fileName.endsWith('.' + ext) ? fileName : fileName + '.' + ext;

            ContentVersion cv      = new ContentVersion();
            cv.Title               = fullName;
            cv.PathOnClient        = fullName;
            cv.VersionData         = Blob.valueOf(fileContent);
            cv.IsMajorVersion      = true;
            cv.ContentLocation     = 'S';
            insert cv;

            ContentVersion inserted = [
                SELECT ContentDocumentId
                FROM   ContentVersion
                WHERE  Id = :cv.Id
                LIMIT  1
            ];

            res.success = true;
            res.message = 'File saved: ' + fullName;
            res.fileUrl = '/lightning/r/ContentDocument/' + inserted.ContentDocumentId + '/view';

        } catch (Exception ex) {
            res.success = false;
            res.message = 'Failed to save file: ' + ex.getMessage();
        }

        return res;
    }
}