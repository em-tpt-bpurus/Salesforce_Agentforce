/**
 * @description Agent action + Aura-enabled facade for Visualforce Component metadata.
 *              Lists all ApexComponent records in the org, detects which are referenced
 *              (via MetadataComponentDependency + VF page markup scan), and exposes the
 *              data to both Agentforce (@InvocableMethod) and the metadataDashboard LWC.
 * @group       Metadata Dashboard
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.NcssMethodCount,PMD.ApexCRUDViolation,PMD.ExcessiveClassLength,PMD.AvoidGlobalModifier')
public without sharing class VfComponentAgentAction {

    /** @description Per-component metadata returned to LWC / Agentforce. */
    public class VfCompInfo {
        /** @description API name of the ApexComponent. */
        @AuraEnabled public String  name;
        /** @description Master label of the ApexComponent. */
        @AuraEnabled public String  label;
        /** @description Namespace prefix (blank for unmanaged). */
        @AuraEnabled public String  namespacePrefix;
        /** @description API version of the component. */
        @AuraEnabled public String  apiVersion;
        /** @description Last-modified date (YYYY-MM-DD). */
        @AuraEnabled public String  lastModifiedDate;
        /** @description True if any VF page / Apex references this component. */
        @AuraEnabled public Boolean isReferenced;
        /** @description Human-readable description of references found. */
        @AuraEnabled public String  referencedBy;
        /** @description IN_USE / MANAGED / SAFE_TO_REVIEW. */
        @AuraEnabled public String  safetyStatus;
        /** @description True when the component belongs to a managed package. */
        @AuraEnabled public Boolean isManagedPackage;
    }

    /** @description Aggregate summary returned for a single org scan. */
    public class VfCompSummary {
        /** @description Total ApexComponent records found. */
        @AuraEnabled public Integer             total;
        /** @description Count with a non-blank namespace prefix. */
        @AuraEnabled public Integer             withNamespace;
        /** @description Count with a blank namespace prefix. */
        @AuraEnabled public Integer             withoutNamespace;
        /** @description Count flagged as referenced. */
        @AuraEnabled public Integer             referencedCount;
        /** @description Count flagged as unreferenced (safe to review). */
        @AuraEnabled public Integer             unreferencedCount;
        /** @description Full list of components. */
        @AuraEnabled public List<VfCompInfo>    allComponents;
        /** @description Subset where safetyStatus = SAFE_TO_REVIEW. */
        @AuraEnabled public List<VfCompInfo>    unreferencedComponents;
        /** @description Subset matching the namespace filter. */
        @AuraEnabled public List<VfCompInfo>    filteredComponents;
    }

    /** @description Invocable-friendly flattened output shape. */
    public class VfCompOutput {
        /** @description Human-readable summary block for Agentforce. */
        @AuraEnabled @InvocableVariable(label='Summary')
        public String summary;
        /** @description Total component count as string. */
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
        /** @description Pretty-printed list of every component. */
        @AuraEnabled @InvocableVariable(label='All Components')
        public String allComponents;
        /** @description Pretty-printed list of unreferenced components. */
        @AuraEnabled @InvocableVariable(label='Unreferenced Components')
        public String unreferencedComponents;
        /** @description Strongly-typed list for LWC consumption. */
        @AuraEnabled public List<VfCompInfo> allComponentObjects;
    }

    /** @description Invocable request shape. */
    public class VfCompRequest {
        /** @description Optional namespace filter (null/blank = all). */
        @InvocableVariable(label='Namespace Filter')
        public String namespaceFilter;
    }

    /**
     * @description Agentforce entry point. Returns a single-element list for invocable contract.
     * @param  requests List of namespace-filter requests (only first is used).
     * @return Single-element list containing the component summary.
     */
    @InvocableMethod(label='VF Components Metadata' description='Returns Visualforce component summary')
    public static List<VfCompOutput> run(List<VfCompRequest> requests) {
        String ns = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter : null;
        return new List<VfCompOutput>{ buildOutput(ns) };
    }

    /**
     * @description LWC entry point. Returns a single component summary for the dashboard.
     * @param  namespaceFilter Optional namespace prefix to filter on.
     * @return Populated VfCompOutput object.
     */
    @AuraEnabled(cacheable=false)
    public static VfCompOutput getVfComponentSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    /**
     * @description Builds the flattened output shape from a VfCompSummary.
     * @param  namespaceFilter Optional namespace prefix.
     * @return Populated VfCompOutput.
     */
    private static VfCompOutput buildOutput(String namespaceFilter) {
        VfCompSummary summary = getVfComponents(namespaceFilter);
        VfCompOutput  out     = new VfCompOutput();

        out.totalCount            = String.valueOf(summary.total);
        out.referencedCount       = String.valueOf(summary.referencedCount);
        out.unreferencedCount     = String.valueOf(summary.unreferencedCount);
        out.withNamespaceCount    = String.valueOf(summary.withNamespace);
        out.withoutNamespaceCount = String.valueOf(summary.withoutNamespace);
        out.allComponentObjects   = summary.allComponents;

        String allStr   = formatAllList(summary.allComponents);
        String unrefStr = formatUnreferencedList(summary.unreferencedComponents);

        out.allComponents          = allStr;
        out.unreferencedComponents = unrefStr;

        out.summary = 'This org has ' + summary.total + ' Visualforce components. ' +
            summary.referencedCount + ' are referenced, ' +
            summary.unreferencedCount + ' are unreferenced (safe to review).\n\n' +
            '--- ALL VF COMPONENTS (' + summary.total + ') ---\n' + allStr + '\n' +
            '--- UNREFERENCED (' + summary.unreferencedCount + ') ---\n' + unrefStr;

        return out;
    }

    /**
     * @description Formats the full component list as numbered text.
     * @param  comps List of VfCompInfo to format.
     * @return Multi-line string (or "None" when empty).
     */
    private static String formatAllList(List<VfCompInfo> comps) {
        if (comps == null || comps.isEmpty()) {
            return 'None';
        }
        String out = '';
        for (Integer i = 0; i < comps.size(); i++) {
            VfCompInfo c = comps[i];
            out += (i + 1) + '. ' + c.name +
                ' | API: ' + (c.apiVersion != null ? c.apiVersion : 'N/A') +
                ' | ' + (c.isReferenced ? 'Referenced' : 'Unreferenced') + '\n';
        }
        return out;
    }

    /**
     * @description Formats the unreferenced-component list as numbered text.
     * @param  comps List of VfCompInfo to format.
     * @return Multi-line string (or "None" when empty).
     */
    private static String formatUnreferencedList(List<VfCompInfo> comps) {
        if (comps == null || comps.isEmpty()) {
            return 'None';
        }
        String out = '';
        for (Integer i = 0; i < comps.size(); i++) {
            out += (i + 1) + '. ' + comps[i].name + '\n';
        }
        return out;
    }

    /**
     * @description Core engine: queries every ApexComponent in the org, detects references
     *              via MetadataComponentDependency + VF page markup scan, and builds the
     *              summary. Split into small helpers to satisfy PMD NCSS limits.
     * @param  namespaceFilter Optional namespace prefix.
     * @return Populated VfCompSummary.
     */
    public static VfCompSummary getVfComponents(String namespaceFilter) {
        VfCompSummary result = newEmptySummary();

        List<VfCompInfo> allComps = queryAllComponents();
        if (allComps.isEmpty()) {
            result.allComponents = allComps;
            return result;
        }

        Set<String> referencedNames = new Set<String>();
        addMcdReferences(allComps, referencedNames);
        addMarkupReferences(allComps, referencedNames);

        assignSafetyStatusAndCount(allComps, referencedNames, namespaceFilter, result);
        return result;
    }

    /**
     * @description Constructs an empty, zero-initialised VfCompSummary.
     * @return Fresh VfCompSummary with empty lists and zero counts.
     */
    private static VfCompSummary newEmptySummary() {
        VfCompSummary r = new VfCompSummary();
        r.allComponents          = new List<VfCompInfo>();
        r.unreferencedComponents = new List<VfCompInfo>();
        r.filteredComponents     = new List<VfCompInfo>();
        r.total                  = 0;
        r.withNamespace          = 0;
        r.withoutNamespace       = 0;
        r.referencedCount        = 0;
        r.unreferencedCount      = 0;
        return r;
    }

    /**
     * @description Queries ApexComponent records (up to 500) and maps them to VfCompInfo.
     * @return List of VfCompInfo (empty list on failure).
     */
    private static List<VfCompInfo> queryAllComponents() {
        List<VfCompInfo> allComps = new List<VfCompInfo>();
        try {
            for (ApexComponent ac : [
                SELECT Id, Name, MasterLabel, NamespacePrefix, ApiVersion,
                       LastModifiedDate
                FROM ApexComponent
                ORDER BY Name ASC
                LIMIT 500
            ]) {
                allComps.add(mapComponent(ac));
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'VF component SOQL failed: ' + ex.getMessage());
            throw new AuraHandledException('VF Components SOQL failed: ' + ex.getMessage());
        }
        return allComps;
    }

    /**
     * @description Maps a single ApexComponent SObject to a VfCompInfo with default flags.
     * @param  ac ApexComponent record.
     * @return Populated VfCompInfo.
     */
    private static VfCompInfo mapComponent(ApexComponent ac) {
        VfCompInfo info = new VfCompInfo();
        info.name             = ac.Name;
        info.label            = ac.MasterLabel;
        info.namespacePrefix  = ac.NamespacePrefix;
        info.apiVersion       = ac.ApiVersion != null ? String.valueOf(ac.ApiVersion) : null;
        info.lastModifiedDate = ac.LastModifiedDate != null
            ? String.valueOf(ac.LastModifiedDate).left(10) : null;
        info.isManagedPackage = String.isNotBlank(ac.NamespacePrefix);
        info.isReferenced     = false;
        info.referencedBy     = '';
        info.safetyStatus     = 'SAFE_TO_REVIEW';
        return info;
    }

    /**
     * @description Queries MetadataComponentDependency (Tooling API) in chunks of 50 and
     *              adds any referenced component name (lower-cased) to the set.
     * @param  allComps        Full component list (provides names to query).
     * @param  referencedNames Mutable set to accumulate matches into.
     */
    private static void addMcdReferences(List<VfCompInfo> allComps, Set<String> referencedNames) {
        try {
            List<String> compNames = new List<String>();
            for (VfCompInfo c : allComps) {
                if (String.isNotBlank(c.name)) {
                    compNames.add(c.name);
                }
            }
            Http http = new Http();
            for (Integer i = 0; i < compNames.size(); i += 50) {
                List<String> chunk = buildQuotedChunk(compNames, i, 50);
                String mcdSoql = 'SELECT MetadataComponentName, RefMetadataComponentName ' +
                                 'FROM MetadataComponentDependency ' +
                                 'WHERE RefMetadataComponentType = \'ApexComponent\' ' +
                                 'AND RefMetadataComponentName IN (' + String.join(chunk, ',') + ') ' +
                                 'LIMIT 500';
                HttpResponse mcdRes = doToolingQuery(http, mcdSoql);
                collectRefNamesFromMcd(mcdRes, referencedNames);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'VF component MCD check failed: ' + ex.getMessage());
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
            String compName = (String) ((Map<String, Object>) r).get('RefMetadataComponentName');
            if (String.isNotBlank(compName)) {
                referencedNames.add(compName.toLowerCase());
            }
        }
    }

    /**
     * @description Scans VF page markup for {@code <c:ComponentName>} or {@code <ns:ComponentName>}
     *              tags that the MCD index may have missed.
     * @param  allComps        Full component list.
     * @param  referencedNames Mutable set to accumulate matches into.
     */
    private static void addMarkupReferences(List<VfCompInfo> allComps, Set<String> referencedNames) {
        try {
            for (ApexPage pg : [
                SELECT Name, Markup FROM ApexPage
                WHERE NamespacePrefix = null LIMIT 300
            ]) {
                if (String.isBlank(pg.Markup)) {
                    continue;
                }
                String markupLow = pg.Markup.toLowerCase();
                for (VfCompInfo c : allComps) {
                    if (String.isBlank(c.name)) {
                        continue;
                    }
                    String cLow = c.name.toLowerCase();
                    if (markupLow.contains('<c:' + cLow) ||
                        markupLow.contains(':' + cLow + ' ') ||
                        markupLow.contains(':' + cLow + '>')) {
                        referencedNames.add(cLow);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'VF component markup scan failed: ' + ex.getMessage());
        }
    }

    /**
     * @description Walks every component, assigns safetyStatus, accumulates counts,
     *              applies the namespace filter, and populates the result lists.
     * @param  allComps        Full component list.
     * @param  referencedNames Lower-cased names known to be referenced.
     * @param  namespaceFilter Optional namespace prefix to filter on.
     * @param  result          Mutable summary to populate.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void assignSafetyStatusAndCount(
        List<VfCompInfo> allComps,
        Set<String>      referencedNames,
        String           namespaceFilter,
        VfCompSummary    result
    ) {
        Integer withNs   = 0;
        Integer noNs     = 0;
        Integer refCnt   = 0;
        Integer unrefCnt = 0;

        for (VfCompInfo c : allComps) {
            if (String.isNotBlank(c.namespacePrefix)) {
                withNs++;
            } else {
                noNs++;
            }

            Boolean isRef = c.isManagedPackage ||
                referencedNames.contains(c.name != null ? c.name.toLowerCase() : '');
            c.isReferenced = isRef;

            if (c.isManagedPackage) {
                c.safetyStatus = 'MANAGED';
                c.referencedBy = 'Managed Package (' + c.namespacePrefix + ')';
                refCnt++;
            } else if (isRef) {
                c.safetyStatus = 'IN_USE';
                c.referencedBy = 'Referenced by VF Page / Apex';
                refCnt++;
            } else {
                c.safetyStatus = 'SAFE_TO_REVIEW';
                c.referencedBy = '';
                unrefCnt++;
                result.unreferencedComponents.add(c);
            }

            result.allComponents.add(c);

            if (String.isBlank(namespaceFilter) ||
                (String.isNotBlank(c.namespacePrefix) &&
                 c.namespacePrefix.equalsIgnoreCase(namespaceFilter))) {
                result.filteredComponents.add(c);
            }
        }

        result.total             = allComps.size();
        result.withNamespace     = withNs;
        result.withoutNamespace  = noNs;
        result.referencedCount   = refCnt;
        result.unreferencedCount = unrefCnt;
    }
}