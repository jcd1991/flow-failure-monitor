public with sharing class FFM_RecoveryPreviewService {
    private static final Integer HARD_LIMIT = 200;

    public class PreviewResponse {
        @AuraEnabled public Recovery_Job__c job;
        @AuraEnabled public List<Recovery_Result__c> results;
        public PreviewResponse(Recovery_Job__c value, List<Recovery_Result__c> items) { job = value; results = items; }
    }

    @AuraEnabled(cacheable=true)
    public static List<Recovery_Action__c> activeActions() {
        return [SELECT Id,Name,Action_Key__c,Label__c,Flow_Name__c,Active__c,Max_Batch_Size__c,Description__c
                FROM Recovery_Action__c WHERE Active__c=true WITH USER_MODE ORDER BY Label__c LIMIT 200];
    }

    @AuraEnabled
    public static PreviewResponse preview(Id failureGroupId, Id recoveryActionId, List<Id> errorIds, Integer requestedLimit) {
        if (failureGroupId == null || recoveryActionId == null) throw new AuraHandledException('Failure group and recovery action are required.');
        Recovery_Action__c action = [SELECT Id,Action_Key__c,Label__c,Active__c,Max_Batch_Size__c FROM Recovery_Action__c WHERE Id=:recoveryActionId WITH USER_MODE LIMIT 1];
        if (!action.Active__c) throw new AuraHandledException('Recovery action is inactive.');
        Integer cap = action.Max_Batch_Size__c == null ? 50 : Integer.valueOf(action.Max_Batch_Size__c);
        cap = Math.min(Math.max(cap, 1), HARD_LIMIT);
        Integer requested = requestedLimit == null ? cap : Math.min(Math.max(requestedLimit, 1), HARD_LIMIT);
        requested = Math.min(requested, cap);

        List<Flow_Error__c> samples;
        if (errorIds == null || errorIds.isEmpty()) {
            samples = [SELECT Id,Record_Id__c,Status__c,Failure_Group__c FROM Flow_Error__c WHERE Failure_Group__c=:failureGroupId WITH USER_MODE ORDER BY CreatedDate ASC LIMIT :requested];
        } else {
            Set<Id> selected = new Set<Id>(errorIds);
            samples = [SELECT Id,Record_Id__c,Status__c,Failure_Group__c FROM Flow_Error__c WHERE Id IN :selected AND Failure_Group__c=:failureGroupId WITH USER_MODE LIMIT :requested];
        }

        String key = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(UserInfo.getUserId() + ':' + String.valueOf(DateTime.now().getTime()) + ':' + failureGroupId)));
        Recovery_Job__c job = new Recovery_Job__c(Failure_Group__c=failureGroupId,Recovery_Action__c=action.Id,Status__c='Previewed',Dry_Run__c=true,Requested_Count__c=samples.size(),Eligible_Count__c=0,Skipped_Count__c=0,Idempotency_Key__c=key,Previewed_At__c=System.now());
        Database.insert(job, AccessLevel.USER_MODE);

        List<Recovery_Result__c> results = new List<Recovery_Result__c>();
        Integer eligible = 0; Integer skipped = 0;
        for (Flow_Error__c sample : samples) {
            Boolean validRecord = FFM_FailureCaptureService.safeId(sample.Record_Id__c) != null;
            String outcome = validRecord ? 'Eligible' : 'Skipped';
            if (validRecord) eligible++; else skipped++;
            results.add(new Recovery_Result__c(Recovery_Job__c=job.Id,Flow_Error__c=sample.Id,Record_Id__c=validRecord ? sample.Record_Id__c : null,Outcome__c=outcome,Reason__c=validRecord ? 'Dry-run eligible; no recovery action executed.' : 'Skipped because the captured record id is missing or invalid.',Idempotency_Key__c=key));
        }
        if (!results.isEmpty()) Database.insert(results, AccessLevel.USER_MODE);
        job.Eligible_Count__c = eligible; job.Skipped_Count__c = skipped;
        Database.update(job, AccessLevel.USER_MODE);
        return new PreviewResponse(job, results);
    }

    @AuraEnabled
    public static PreviewResponse simulate(Id recoveryJobId) {
        if (recoveryJobId == null) throw new AuraHandledException('Recovery job is required.');
        Recovery_Job__c job = [SELECT Id,Name,Dry_Run__c,Status__c,Requested_Count__c,Eligible_Count__c,Skipped_Count__c FROM Recovery_Job__c WHERE Id=:recoveryJobId WITH USER_MODE LIMIT 1];
        if (!job.Dry_Run__c || job.Status__c != 'Previewed') throw new AuraHandledException('Only a Previewed dry-run job can be simulated.');
        List<Recovery_Result__c> results = [SELECT Id,Outcome__c,Reason__c FROM Recovery_Result__c WHERE Recovery_Job__c=:job.Id WITH USER_MODE ORDER BY CreatedDate ASC];
        for (Recovery_Result__c result : results) {
            if (result.Outcome__c == 'Eligible') {
                result.Outcome__c = 'Success';
                result.Reason__c = 'Simulated recovery completed; no record or Flow was changed.';
            }
        }
        if (!results.isEmpty()) update results;
        job.Status__c = 'Completed';
        update job;
        return new PreviewResponse(job, results);
    }

    @AuraEnabled
    public static PreviewResponse executeApprovedDemo(Id recoveryJobId) {
        if (recoveryJobId == null) throw new AuraHandledException('Recovery job is required.');
        Recovery_Job__c job = [SELECT Id,Name,Dry_Run__c,Status__c,Recovery_Action__c,Requested_Count__c,Eligible_Count__c,Skipped_Count__c FROM Recovery_Job__c WHERE Id=:recoveryJobId WITH USER_MODE LIMIT 1];
        if (!job.Dry_Run__c || job.Status__c != 'Previewed') throw new AuraHandledException('Only a Previewed dry-run job can be executed.');
        Recovery_Action__c action = [SELECT Id,Action_Key__c,Flow_Name__c,Active__c FROM Recovery_Action__c WHERE Id=:job.Recovery_Action__c WITH USER_MODE LIMIT 1];
        if (!action.Active__c || action.Action_Key__c != 'E2E_DEMO_ORDER_REPAIR' || action.Flow_Name__c != 'FFM_DemoOrderRecovery') {
            throw new AuraHandledException('This recovery action is not an allowlisted demo executor.');
        }
        List<Recovery_Result__c> results = [SELECT Id,Outcome__c,Reason__c,Record_Id__c FROM Recovery_Result__c WHERE Recovery_Job__c=:job.Id WITH USER_MODE ORDER BY CreatedDate ASC];
        Integer failures = 0;
        for (Recovery_Result__c result : results) {
            if (result.Outcome__c != 'Eligible') continue;
            try {
                List<Account> targets = [SELECT Id FROM Account WHERE Id=:result.Record_Id__c LIMIT 1];
                if (targets.isEmpty()) {
                    failures++;
                    result.Outcome__c = 'Failed';
                    result.Reason__c = 'No matching Account exists; the recovery Flow was not executed.';
                    continue;
                }
                Map<String,Object> inputs = new Map<String,Object>{'recordId' => result.Record_Id__c};
                Flow.Interview interview = Flow.Interview.createInterview('FFM_DemoOrderRecovery', inputs);
                interview.start();
                result.Outcome__c = 'Success';
                result.Reason__c = 'Allowlisted recovery Flow executed successfully.';
            } catch (Exception ex) {
                failures++;
                result.Outcome__c = 'Failed';
                result.Reason__c = 'Recovery Flow failed: ' + ex.getMessage().left(240);
            }
        }
        if (!results.isEmpty()) update results;
        job.Status__c = failures == 0 ? 'Completed' : 'Failed';
        update job;
        return new PreviewResponse(job, results);
    }
}
