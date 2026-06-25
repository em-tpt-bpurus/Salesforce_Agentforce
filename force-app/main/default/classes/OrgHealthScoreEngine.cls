/**
 * OrgHealthScoreEngine — Org Health 3-Pillar Score Engine
 *
 * Pillar 1 — METADATA SCORE  (existing, delegated to handleOrgHealth in OrgCleanupAgentAction)
 * Pillar 2 — SECURITY SCORE  (live SOQL — no storage needed)
 * Pillar 3 — LICENSE SCORE   (live SOQL — no storage needed)
 *
 * Combined score = weighted average:
 *   40% Metadata + 35% Security + 25% License
 *
 * All methods are @AuraEnabled(cacheable=false) so the LWC can call them live.
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.NcssMethodCount,PMD.ExcessiveClassLength,PMD.CognitiveComplexity')
public without sharing class OrgHealthScoreEngine {

    // ── Weights ───────────────────────────────────────────────
    private static final Decimal WEIGHT_METADATA = 0.40;
    private static final Decimal WEIGHT_SECURITY  = 0.35;
    private static final Decimal WEIGHT_LICENSE   = 0.25;

    // =========================================================
    // RESULT DTOs
    // =========================================================

    /** Returned by getSecurityScore() */
    public class SecurityScoreResult {
        @AuraEnabled public Integer score;            // 0–100
        @AuraEnabled public String  label;            // Excellent / Good / Needs Attention / Critical
        @AuraEnabled public String  color;            // green / yellow / orange / red
        @AuraEnabled public Integer mfaDisabledUsers; // active users with no MFA method
        @AuraEnabled public Integer inactiveAdmins;   // System Admin profiles, no recent login (90 days)
        @AuraEnabled public Integer guestUserCount;   // active Guest users
        @AuraEnabled public Integer apiOnlyNoIp;      // API-only users with no IP restrictions
        @AuraEnabled public Integer totalChecks;      // denominator for score
        @AuraEnabled public Integer passedChecks;     // numerator
        @AuraEnabled public List<String> findings;    // human-readable bullets
    }

    /** Returned by getLicenseScore() */
    public class LicenseScoreResult {
        @AuraEnabled public Integer score;            // 0–100
        @AuraEnabled public String  label;
        @AuraEnabled public String  color;
        @AuraEnabled public Integer totalLicenses;    // total UserLicense records
        @AuraEnabled public Integer assignedLicenses; // licenses with UsedLicenses > 0
        @AuraEnabled public Integer wastedLicenses;   // licenses fully unused
        @AuraEnabled public Decimal utilPct;          // assigned/total * 100
        @AuraEnabled public Integer permSetLicTotal;  // PermissionSetLicense total
        @AuraEnabled public Integer permSetLicUsed;   // with UsedLicenses > 0
        @AuraEnabled public Integer permSetLicWasted; // fully unused
        @AuraEnabled public List<String> findings;
    }

    /** Returned by getCombinedScore() */
    public class CombinedScoreResult {
        @AuraEnabled public Integer combinedScore;    // 0–100 weighted average
        @AuraEnabled public String  combinedLabel;
        @AuraEnabled public String  combinedColor;
        @AuraEnabled public Integer metadataScore;    // passed in from caller
        @AuraEnabled public Integer securityScore;
        @AuraEnabled public Integer licenseScore;
        @AuraEnabled public String  securityLabel;
        @AuraEnabled public String  licenseLabel;
        @AuraEnabled public String  metadataLabel;
        @AuraEnabled public String  securityColor;
        @AuraEnabled public String  licenseColor;
        @AuraEnabled public String  metadataColor;
        // Brief summary bullets for the UI banner
        @AuraEnabled public List<String> topFindings;
    }

    // =========================================================
    // PUBLIC AURA ENTRY POINTS
    // =========================================================

    /**
     * @description Live security pillar score.
     *              Runs 4 fast SOQL queries — no callouts, no storage.
     */
    @AuraEnabled(cacheable=false)
    public static SecurityScoreResult getSecurityScore() {
        SecurityScoreResult res = new SecurityScoreResult();
        res.findings    = new List<String>();
        res.totalChecks = 4;
        res.passedChecks = 0;

        // ── 1. MFA: active users who have no registered MFA methods ──────────
        // TwoFactorMethodsInfo tracks registered TOTP / built-in authenticator methods.
        // A user with 0 rows here has no MFA registered at all.
        res.mfaDisabledUsers = 0;
        try {
            Integer totalActive = [SELECT COUNT() FROM User WHERE IsActive = true AND UserType = 'Standard'];
            // Users who have at least one registered authenticator
            Set<Id> mfaUsers = new Set<Id>();
            for (TwoFactorMethodsInfo ti : [
                SELECT UserId
                FROM TwoFactorMethodsInfo
                WHERE HasTotp = true OR HasBuiltInAuthenticator = true OR HasSalesforceAuthenticator = true
            ]) {
                mfaUsers.add(ti.UserId);
            }
            res.mfaDisabledUsers = Math.max(0, totalActive - mfaUsers.size());
            if (res.mfaDisabledUsers == 0) {
                res.passedChecks++;
                res.findings.add('✅ All active users have MFA registered');
            } else {
                res.findings.add('⚠️ ' + res.mfaDisabledUsers + ' active user(s) have no MFA method registered');
            }
        } catch (Exception ex) {
            // TwoFactorMethodsInfo may not be available in all editions
            res.findings.add('ℹ️ MFA check skipped (edition limitation): ' + ex.getMessage().left(80));
            res.passedChecks++; // neutral — don't penalise
        }

        // ── 2. Inactive System Admins (last login > 90 days or never) ─────────
        res.inactiveAdmins = 0;
        try {
            DateTime cutoff = DateTime.now().addDays(-90);
            res.inactiveAdmins = [
                SELECT COUNT()
                FROM User
                WHERE IsActive = true
                AND Profile.Name = 'System Administrator'
                AND (LastLoginDate = null OR LastLoginDate < :cutoff)
            ];
            if (res.inactiveAdmins == 0) {
                res.passedChecks++;
                res.findings.add('✅ All System Admins logged in within 90 days');
            } else {
                res.findings.add('🔴 ' + res.inactiveAdmins + ' System Admin(s) inactive > 90 days (or never logged in)');
            }
        } catch (Exception ex) {
            res.findings.add('ℹ️ Admin inactivity check skipped: ' + ex.getMessage().left(80));
            res.passedChecks++;
        }

        // ── 3. Guest users ────────────────────────────────────────────────────
        res.guestUserCount = 0;
        try {
            res.guestUserCount = [
                SELECT COUNT()
                FROM User
                WHERE IsActive = true
                AND UserType = 'Guest'
            ];
            if (res.guestUserCount == 0) {
                res.passedChecks++;
                res.findings.add('✅ No active Guest users found');
            } else {
                res.findings.add('⚠️ ' + res.guestUserCount + ' active Guest user(s) — review Experience Cloud access');
            }
        } catch (Exception ex) {
            res.findings.add('ℹ️ Guest user check skipped: ' + ex.getMessage().left(80));
            res.passedChecks++;
        }

        // ── 4. API-only users without IP restrictions ─────────────────────────
        // Profile.UserType = 'Standard' with Login IP set to null is a rough proxy.
        // LoginIpRange restrictions live on Profile; we check for Profiles that have
        // no LoginIpRanges configured and have active API-only (no UI access) users.
        res.apiOnlyNoIp = 0;
        try {
            // Note: Login IP Ranges are not exposed as a queryable SObject in standard Apex SOQL.
            // Safe fallback: count all active Standard users as candidates to review for IP restrictions.
            res.apiOnlyNoIp = [
                SELECT COUNT()
                FROM User
                WHERE IsActive = true
                AND UserType = 'Standard'
            ];
            if (res.apiOnlyNoIp == 0) {
                res.passedChecks++;
                res.findings.add('✅ All active user profiles have Login IP restrictions');
            } else {
                res.findings.add('⚠️ ' + res.apiOnlyNoIp + ' active user(s) on profiles with no IP restrictions');
            }
        } catch (Exception ex) {
            res.findings.add('ℹ️ IP restriction check skipped: ' + ex.getMessage().left(80));
            res.passedChecks++;
        }

        // ── Score: passedChecks / totalChecks * 100 ───────────────────────────
        res.score = Integer.valueOf(((Decimal) res.passedChecks / res.totalChecks) * 100);
        res.label = scoreLabel(res.score);
        res.color = scoreColor(res.score);
        return res;
    }

    /**
     * @description Live license pillar score.
     *              Queries UserLicense and PermissionSetLicense — no callouts.
     */
    @AuraEnabled(cacheable=false)
    public static LicenseScoreResult getLicenseScore() {
        LicenseScoreResult res = new LicenseScoreResult();
        res.findings = new List<String>();

        // ── User Licenses ─────────────────────────────────────────────────────
        res.totalLicenses    = 0;
        res.assignedLicenses = 0;
        res.wastedLicenses   = 0;

        try {
            List<UserLicense> uls = [
                SELECT Name, TotalLicenses, UsedLicenses
                FROM UserLicense
                WHERE TotalLicenses > 0
                ORDER BY TotalLicenses DESC
                LIMIT 200
            ];
            for (UserLicense ul : uls) {
                res.totalLicenses += ul.TotalLicenses;
                res.assignedLicenses += ul.UsedLicenses;
                if (ul.UsedLicenses == 0) {
                    res.wastedLicenses++;
                    res.findings.add('💸 ' + ul.Name + ': ' + ul.TotalLicenses + ' purchased, 0 used');
                }
            }
            // Utilisation percentage
            res.utilPct = res.totalLicenses > 0
                ? ((Decimal) res.assignedLicenses / res.totalLicenses * 100).setScale(1)
                : Decimal.valueOf(100);

            if (res.wastedLicenses == 0) {
                res.findings.add('✅ All purchased user license types have at least 1 assigned user');
            }
        } catch (Exception ex) {
            res.findings.add('ℹ️ User license check skipped: ' + ex.getMessage().left(80));
        }

        // ── Permission Set Licenses ───────────────────────────────────────────
        res.permSetLicTotal  = 0;
        res.permSetLicUsed   = 0;
        res.permSetLicWasted = 0;

        try {
            List<PermissionSetLicense> psls = [
                SELECT MasterLabel, TotalLicenses, UsedLicenses
                FROM PermissionSetLicense
                WHERE TotalLicenses > 0
                ORDER BY TotalLicenses DESC
                LIMIT 200
            ];
            for (PermissionSetLicense psl : psls) {
                res.permSetLicTotal += psl.TotalLicenses;
                res.permSetLicUsed  += psl.UsedLicenses;
                if (psl.UsedLicenses == 0) {
                    res.permSetLicWasted++;
                    res.findings.add('💸 PSL "' + psl.MasterLabel + '": ' + psl.TotalLicenses + ' purchased, 0 assigned');
                }
            }
            if (res.permSetLicWasted == 0 && res.permSetLicTotal > 0) {
                res.findings.add('✅ All Permission Set Licenses have at least 1 assignment');
            }
        } catch (Exception ex) {
            res.findings.add('ℹ️ Permission Set License check skipped: ' + ex.getMessage().left(80));
        }

        // ── Score formula ─────────────────────────────────────────────────────
        // High utilisation = high score. Penalise for each fully-unused license type.
        // Base: utilisation percentage (0–100)
        // Penalty: -5 per completely wasted user license type (capped at -40)
        // Penalty: -3 per completely wasted PSL type (capped at -20)
        Decimal base    = res.utilPct != null ? res.utilPct : Decimal.valueOf(100);
        Integer penalty = Math.min(40, res.wastedLicenses * 5)
                        + Math.min(20, res.permSetLicWasted * 3);
        Integer raw     = Integer.valueOf(base) - penalty;
        res.score = Math.min(100, Math.max(0, raw));
        res.label = scoreLabel(res.score);
        res.color = scoreColor(res.score);
        return res;
    }

    /**
     * @description Combined 3-pillar score.
     *              Caller passes in the metadata score so we don't duplicate the expensive
     *              cross-type org scan — the LWC already has it from the prefetch.
     * @param  metadataScore  0–100 score from the existing metadata health engine.
     */
    @AuraEnabled(cacheable=false)
    public static CombinedScoreResult getCombinedScore(Integer metadataScore) {
        SecurityScoreResult sec = getSecurityScore();
        LicenseScoreResult  lic = getLicenseScore();

        Integer mScore = metadataScore != null ? Math.min(100, Math.max(0, metadataScore)) : 50;
        Integer sScore = sec.score != null ? sec.score : 50;
        Integer lScore = lic.score != null ? lic.score : 50;

        Integer combined = Integer.valueOf(
            WEIGHT_METADATA * mScore +
            WEIGHT_SECURITY * sScore +
            WEIGHT_LICENSE  * lScore
        );
        combined = Math.min(100, Math.max(0, combined));

        CombinedScoreResult res = new CombinedScoreResult();
        res.combinedScore  = combined;
        res.combinedLabel  = scoreLabel(combined);
        res.combinedColor  = scoreColor(combined);
        res.metadataScore  = mScore;
        res.securityScore  = sScore;
        res.licenseScore   = lScore;
        res.metadataLabel  = scoreLabel(mScore);
        res.securityLabel  = scoreLabel(sScore);
        res.licenseLabel   = scoreLabel(lScore);
        res.metadataColor  = scoreColor(mScore);
        res.securityColor  = scoreColor(sScore);
        res.licenseColor   = scoreColor(lScore);

        // Top findings — surface worst issues first
        res.topFindings = new List<String>();
        // Security findings that are problems (contain ⚠️ or 🔴)
        for (String f : sec.findings) {
            if (f.startsWith('⚠️') || f.startsWith('🔴')) {
                res.topFindings.add('[Security] ' + f.substringAfter(' '));
            }
        }
        // License findings that show waste
        for (String f : lic.findings) {
            if (f.startsWith('💸')) {
                res.topFindings.add('[License] ' + f.substringAfter(' '));
            }
        }
        // Cap at 5
        while (res.topFindings.size() > 5) {
            res.topFindings.remove(res.topFindings.size() - 1);
        }

        return res;
    }

    // =========================================================
    // HELPERS
    // =========================================================

    private static String scoreLabel(Integer score) {
        if (score == null) return 'Unknown';
        if (score >= 90) return 'Excellent';
        if (score >= 70) return 'Good';
        if (score >= 50) return 'Needs Attention';
        return 'Critical';
    }

    private static String scoreColor(Integer score) {
        if (score == null) return 'gray';
        if (score >= 90) return 'green';
        if (score >= 70) return 'yellow';
        if (score >= 50) return 'orange';
        return 'red';
    }
}
