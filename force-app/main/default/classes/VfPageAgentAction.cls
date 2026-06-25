/**
 * @description Agent action + Aura-enabled facade for Visualforce Page metadata.
 *              Lists all ApexPage records in the org, detects which are referenced
 *              (via MetadataComponentDependency + Apex body / Tab / FlexiPage scans),
 *              and exposes the data to both Agentforce (@InvocableMethod) and the
 *              metadataDashboard LWC.
 * @group       Metadata Dashboard
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.NcssMethodCount,PMD.ApexCRUDViolation,PMD.ExcessiveClassLength,PMD.AvoidGlobalModifier')
public without sharing class VfPageAgentAction {

    /** @description Per-page metadata returned to LWC / Agentforce. */
    public class VfPageInfo {
        /** @description API name of the ApexPage. */
        @AuraEnabled public String  name;
        /** @description Master label of the ApexPage. */
        @AuraEnabled public String  label;
        /** @description Namespace prefix (blank for unmanaged). */
        @AuraEnabled public String  namespacePrefix;
        /** @description API version of the page. */
        @AuraEnabled public String  apiVersion;
        /** @description Last-modified date (YYYY-MM-DD). */
        @AuraEnabled public String  lastModifiedDate;
        /** @description True if any Apex / Tab / FlexiPage references this page. */
        @AuraEnabled public Boolean isReferenced;
        /** @description Human-readable description of references found. */
        @AuraEnabled public String  referencedBy;
        /** @description IN_USE / MANAGED / SAFE_TO_REVIEW. */
        @AuraEnabled public String  safetyStatus;
        /** @description True when the page belongs to a managed package. */
        @AuraEnabled public Boolean isManagedPackage;
    }

    /** @description Aggregate summary returned for a single org scan. */
    public class VfSummary {
        /** @description Total ApexPage records found. */
        @AuraEnabled public Integer           total;
        /** @description Count with a non-blank namespace prefix. */
        @AuraEnabled public Integer           withNamespace;
        /** @description Count with a blank namespace prefix. */
        @AuraEnabled public Integer           withoutNamespace;
        /** @description Count flagged as referenced. */
        @AuraEnabled public Integer           referencedCount;
        /** @description Count flagged as unreferenced (safe to review). */
        @AuraEnabled public Integer           unreferencedCount;
        /** @description Full list of pages. */
        @AuraEnabled public List<VfPageInfo>  allPages;
        /** @description Subset where safetyStatus = SAFE_TO_REVIEW. */
        @AuraEnabled public List<VfPageInfo>  unreferencedPages;
        /** @description Subset matching the namespace filter. */
        @AuraEnabled public List<VfPageInfo>  filteredPages;
    }

    /** @description Invocable-friendly flattened output shape. */
    public class VfOutput {
        /** @description Human-readable summary block for Agentforce. */
        @AuraEnabled @InvocableVariable(label='Summary')
        public String summary;
        /** @description Total page count as string. */
        @AuraEnabled @InvocableVariable(label='Total Count')
        public String totalCount;
        /** @description Referenced count as string. */
        @AuraEnabled @InvocableVariable(label='Referenced Count')
        public String referencedCount;
        /** @description Unreferenced count as string. */
        @AuraEnabled @InvocableVariable(label='Unreferenced Count')
        public String unreferencedCount;
        /** @description With-namespace count as string. */
        @AuraEnabled @InvocableVariable(label='With Namespace Count')
        public String withNamespaceCount;
        /** @description Without-namespace count as string. */
        @AuraEnabled @InvocableVariable(label='Without Namespace Count')
        public String withoutNamespaceCount;
        /** @description Pretty-printed list of every page. */
        @AuraEnabled @InvocableVariable(label='All Pages')
        public String allPages;
        /** @description Pretty-printed list of unreferenced pages. */
        @AuraEnabled @InvocableVariable(label='Unreferenced Pages')
        public String unreferencedPages;
        /** @description Strongly-typed list for LWC consumption. */
        @AuraEnabled public List<VfPageInfo> allPageObjects;
    }

    /** @description Invocable request shape. */
    public class VfRequest {
        /** @description Optional namespace filter (null/blank = all). */
        @InvocableVariable(label='Namespace Filter')
        public String namespaceFilter;
    }

    /**
     * @description Agentforce entry point. Returns a single-element list for invocable contract.
     * @param  requests List of namespace-filter requests (only first is used).
     * @return Single-element list containing the page summary.
     */
    @InvocableMethod(label='VF Pages Metadata' description='Returns Visualforce page summary')
    public static List<VfOutput> run(List<VfRequest> requests) {
        String ns = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter : null;
        return new List<VfOutput>{ buildOutput(ns) };
    }

    /**
     * @description LWC entry point. Returns a single page summary for the dashboard.
     * @param  namespaceFilter Optional namespace prefix to filter on.
     * @return Populated VfOutput object.
     */
    @AuraEnabled(cacheable=false)
    public static VfOutput getVfSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    /**
     * @description Builds the flattened output shape from a VfSummary.
     * @param  namespaceFilter Optional namespace prefix.
     * @return Populated VfOutput.
     */
    private static VfOutput buildOutput(String namespaceFilter) {
        VfSummary summary = getVfPages(namespaceFilter);
        VfOutput  out     = new VfOutput();

        out.totalCount            = String.valueOf(summary.total);
        out.referencedCount       = String.valueOf(summary.referencedCount);
        out.unreferencedCount     = String.valueOf(summary.unreferencedCount);
        out.withNamespaceCount    = String.valueOf(summary.withNamespace);
        out.withoutNamespaceCount = String.valueOf(summary.withoutNamespace);
        out.allPageObjects        = summary.allPages;

        String allStr   = formatAllList(summary.allPages);
        String unrefStr = formatUnreferencedList(summary.unreferencedPages);

        out.allPages          = allStr;
        out.unreferencedPages = unrefStr;

        out.summary = 'This org has ' + summary.total + ' Visualforce pages. ' +
            summary.referencedCount + ' are referenced, ' +
            summary.unreferencedCount + ' are unreferenced (safe to review).\n\n' +
            '--- ALL VF PAGES (' + summary.total + ') ---\n' + allStr + '\n' +
            '--- UNREFERENCED (' + summary.unreferencedCount + ') ---\n' + unrefStr;

        return out;
    }

    /**
     * @description Formats the full page list as numbered text.
     * @param  pages List of VfPageInfo to format.
     * @return Multi-line string (or "None" when empty).
     */
    private static String formatAllList(List<VfPageInfo> pages) {
        if (pages == null || pages.isEmpty()) {
            return 'None';
        }
        String out = '';
        for (Integer i = 0; i < pages.size(); i++) {
            VfPageInfo p = pages[i];
            out += (i + 1) + '. ' + p.name +
                ' | API: ' + (p.apiVersion != null ? p.apiVersion : 'N/A') +
                ' | ' + (p.isReferenced ? 'Referenced' : 'Unreferenced') + '\n';
        }
        return out;
    }

    /**
     * @description Formats the unreferenced-page list as numbered text.
     * @param  pages List of VfPageInfo to format.
     * @return Multi-line string (or "None" when empty).
     */
    private static String formatUnreferencedList(List<VfPageInfo> pages) {
        if (pages == null || pages.isEmpty()) {
            return 'None';
        }
        String out = '';
        for (Integer i = 0; i < pages.size(); i++) {
            out += (i + 1) + '. ' + pages[i].name + '\n';
        }
        return out;
    }

    /**
     * @description Core engine: queries every ApexPage in the org, detects references via
     *              MCD + Apex body / Tab / FlexiPage scans, and builds the summary.
     * @param  namespaceFilter Optional namespace prefix.
     * @return Populated VfSummary.
     */
    public static VfSummary getVfPages(String namespaceFilter) {
        VfSummary result = newEmptySummary();

        List<VfPageInfo> allPages = queryAllPages();
        if (allPages.isEmpty()) {
            result.allPages = allPages;
            return result;
        }

        Set<String> referencedNames = new Set<String>();
        addMcdReferences(allPages, referencedNames);
        addApexBodyReferences(allPages, referencedNames);
        addTabReferences(referencedNames);
        addFlexiPageReferences(allPages, referencedNames);

        assignSafetyStatusAndCount(allPages, referencedNames, namespaceFilter, result);
        return result;
    }

    /**
     * @description Constructs an empty, zero-initialised VfSummary.
     * @return Fresh VfSummary with empty lists and zero counts.
     */
    private static VfSummary newEmptySummary() {
        VfSummary r = new VfSummary();
        r.allPages          = new List<VfPageInfo>();
        r.unreferencedPages = new List<VfPageInfo>();
        r.filteredPages     = new List<VfPageInfo>();
        r.total             = 0;
        r.withNamespace     = 0;
        r.withoutNamespace  = 0;
        r.referencedCount   = 0;
        r.unreferencedCount = 0;
        return r;
    }

    /**
     * @description Queries ApexPage records (up to 500) and maps them to VfPageInfo.
     * @return List of VfPageInfo (empty list on failure).
     */
    private static List<VfPageInfo> queryAllPages() {
        List<VfPageInfo> allPages = new List<VfPageInfo>();
        try {
            for (ApexPage pg : [
                SELECT Id, Name, MasterLabel, NamespacePrefix, ApiVersion,
                       LastModifiedDate
                FROM ApexPage
                ORDER BY Name ASC
                LIMIT 500
            ]) {
                allPages.add(mapPage(pg));
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'VF page SOQL failed: ' + ex.getMessage());
            throw new AuraHandledException('VF Pages SOQL failed: ' + ex.getMessage());
        }
        return allPages;
    }

    /**
     * @description Maps a single ApexPage SObject to a VfPageInfo with default flags.
     * @param  pg ApexPage record.
     * @return Populated VfPageInfo.
     */
    private static VfPageInfo mapPage(ApexPage pg) {
        VfPageInfo info = new VfPageInfo();
        info.name             = pg.Name;
        info.label            = pg.MasterLabel;
        info.namespacePrefix  = pg.NamespacePrefix;
        info.apiVersion       = pg.ApiVersion != null ? String.valueOf(pg.ApiVersion) : null;
        info.lastModifiedDate = pg.LastModifiedDate != null
            ? String.valueOf(pg.LastModifiedDate).left(10) : null;
        info.isManagedPackage = String.isNotBlank(pg.NamespacePrefix);
        info.isReferenced     = false;
        info.referencedBy     = '';
        info.safetyStatus     = 'SAFE_TO_REVIEW';
        return info;
    }

    /**
     * @description Queries MetadataComponentDependency (Tooling API) in chunks of 50 and
     *              adds any referenced page name (lower-cased) to the set.
     * @param  allPages        Full page list (provides names to query).
     * @param  referencedNames Mutable set to accumulate matches into.
     */
    private static void addMcdReferences(List<VfPageInfo> allPages, Set<String> referencedNames) {
        try {
            List<String> pageNames = new List<String>();
            for (VfPageInfo p : allPages) {
                if (String.isNotBlank(p.name)) {
                    pageNames.add(p.name);
                }
            }
            Http http = new Http();
            for (Integer i = 0; i < pageNames.size(); i += 50) {
                List<String> chunk = buildQuotedChunk(pageNames, i, 50);
                String mcdSoql = 'SELECT MetadataComponentName, RefMetadataComponentName ' +
                                 'FROM MetadataComponentDependency ' +
                                 'WHERE RefMetadataComponentType = \'ApexPage\' ' +
                                 'AND RefMetadataComponentName IN (' + String.join(chunk, ',') + ') ' +
                                 'LIMIT 500';
                HttpResponse mcdRes = doToolingQuery(http, mcdSoql);
                collectRefNamesFromMcd(mcdRes, referencedNames);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'VF MCD check failed: ' + ex.getMessage());
        }
    }

    /**
     * @description Returns a chunk of escaped+quoted names from a source list.
     * @param  src   Full source list of names.
     * @param  start Start index (inclusive).
     * @param  size  Chunk size.
     * @return List of quoted, single-quote-escaped names.
     */
    private static List<String> buildQuotedChunk(List<String> src, Integer start, Integer size) {
        List<String> chunk = new List<String>();
        for (Integer j = start; j < Math.min(start + size, src.size()); j++) {
            chunk.add('\'' + String.escapeSingleQuotes(src[j]) + '\'');
        }
        return chunk;
    }

    /**
     * @description Executes a Tooling-API SOQL via the Metadata_API named credential.
     * @param  http Reusable Http instance.
     * @param  soql SOQL string to execute.
     * @return Raw HttpResponse.
     */
    private static HttpResponse doToolingQuery(Http http, String soql) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                        EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        return http.send(req);
    }

    /**
     * @description Parses an MCD Tooling-API response and adds RefMetadataComponentName
     *              values (lower-cased) to the referenced-names set.
     * @param  res             HttpResponse from a Tooling MCD query.
     * @param  referencedNames Mutable set to accumulate matches into.
     */
    private static void collectRefNamesFromMcd(HttpResponse res, Set<String> referencedNames) {
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return;
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object>        recs = (List<Object>) body.get('records');
        if (recs == null) {
            return;
        }
        for (Object r : recs) {
            String refName = (String) ((Map<String, Object>) r).get('RefMetadataComponentName');
            if (String.isNotBlank(refName)) {
                referencedNames.add(refName.toLowerCase());
            }
        }
    }

    /**
     * @description Scans Apex class bodies for {@code Page.X}, {@code PageReference('X')}
     *              or {@code "X"} substrings that imply a VF page reference.
     * @param  allPages        Full page list.
     * @param  referencedNames Mutable set to accumulate matches into.
     */
    private static void addApexBodyReferences(List<VfPageInfo> allPages, Set<String> referencedNames) {
        try {
            for (ApexClass ac : [
                SELECT Name, Body FROM ApexClass
                WHERE NamespacePrefix = null LIMIT 300
            ]) {
                if (String.isBlank(ac.Body)) {
                    continue;
                }
                String bodyLow = ac.Body.toLowerCase();
                for (VfPageInfo p : allPages) {
                    if (String.isBlank(p.name)) {
                        continue;
                    }
                    String pLow = p.name.toLowerCase();
                    if (bodyLow.contains('page.' + pLow) ||
                        bodyLow.contains('pagereference(\'' + pLow + '\'') ||
                        bodyLow.contains('"' + pLow + '"')) {
                        referencedNames.add(pLow);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'VF Apex body scan failed: ' + ex.getMessage());
        }
    }

    /**
     * @description Adds custom-tab SobjectName values to the referenced-names set.
     * @param  referencedNames Mutable set to accumulate matches into.
     */
    private static void addTabReferences(Set<String> referencedNames) {
        try {
            List<TabDefinition> tabs = [SELECT Name, SobjectName FROM TabDefinition LIMIT 200];
            for (TabDefinition t : tabs) {
                if (String.isNotBlank(t.SobjectName)) {
                    referencedNames.add(t.SobjectName.toLowerCase());
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'VF tab check failed: ' + ex.getMessage());
        }
    }

    /**
     * @description Queries FlexiPage metadata (Tooling API) and flags any page whose
     *              name appears inside the serialised metadata blob.
     * @param  allPages        Full page list.
     * @param  referencedNames Mutable set to accumulate matches into.
     */
    private static void addFlexiPageReferences(List<VfPageInfo> allPages, Set<String> referencedNames) {
        try {
            String fpSoql = 'SELECT DeveloperName, Metadata FROM FlexiPage LIMIT 200';
            Http http = new Http();
            HttpResponse fpRes = doToolingQuery(http, fpSoql);
            if (fpRes.getStatusCode() < 200 || fpRes.getStatusCode() >= 300) {
                return;
            }
            Map<String, Object> fpBody = (Map<String, Object>) JSON.deserializeUntyped(fpRes.getBody());
            List<Object>        fpRecs = (List<Object>) fpBody.get('records');
            if (fpRecs == null) {
                return;
            }
            for (Object r : fpRecs) {
                Object meta = ((Map<String, Object>) r).get('Metadata');
                if (meta == null) {
                    continue;
                }
                String metaStr = JSON.serialize(meta).toLowerCase();
                for (VfPageInfo p : allPages) {
                    if (String.isNotBlank(p.name) && metaStr.contains(p.name.toLowerCase())) {
                        referencedNames.add(p.name.toLowerCase());
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'VF FlexiPage scan failed: ' + ex.getMessage());
        }
    }

    /**
     * @description Walks every page, assigns safetyStatus, accumulates counts,
     *              applies the namespace filter, and populates the result lists.
     * @param  allPages        Full page list.
     * @param  referencedNames Lower-cased names known to be referenced.
     * @param  namespaceFilter Optional namespace prefix to filter on.
     * @param  result          Mutable summary to populate.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void assignSafetyStatusAndCount(
        List<VfPageInfo> allPages,
        Set<String>      referencedNames,
        String           namespaceFilter,
        VfSummary        result
    ) {
        Integer withNs   = 0;
        Integer noNs     = 0;
        Integer refCnt   = 0;
        Integer unrefCnt = 0;

        for (VfPageInfo p : allPages) {
            if (String.isNotBlank(p.namespacePrefix)) {
                withNs++;
            } else {
                noNs++;
            }

            Boolean isRef = p.isManagedPackage ||
                referencedNames.contains(p.name != null ? p.name.toLowerCase() : '');
            p.isReferenced = isRef;

            if (p.isManagedPackage) {
                p.safetyStatus = 'MANAGED';
                p.referencedBy = 'Managed Package (' + p.namespacePrefix + ')';
                refCnt++;
            } else if (isRef) {
                p.safetyStatus = 'IN_USE';
                p.referencedBy = 'Referenced by Apex / Tab / FlexiPage';
                refCnt++;
            } else {
                p.safetyStatus = 'SAFE_TO_REVIEW';
                p.referencedBy = '';
                unrefCnt++;
                result.unreferencedPages.add(p);
            }

            result.allPages.add(p);

            if (String.isBlank(namespaceFilter) ||
                (String.isNotBlank(p.namespacePrefix) &&
                 p.namespacePrefix.equalsIgnoreCase(namespaceFilter))) {
                result.filteredPages.add(p);
            }
        }

        result.total            = allPages.size();
        result.withNamespace    = withNs;
        result.withoutNamespace = noNs;
        result.referencedCount  = refCnt;
        result.unreferencedCount = unrefCnt;
    }
}