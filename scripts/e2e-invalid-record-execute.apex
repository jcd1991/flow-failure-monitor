Failure_Group__c groupRecord=[SELECT Id FROM Failure_Group__c WHERE Fingerprint__c='e2e-invalid-recovery' LIMIT 1];
Recovery_Action__c action=[SELECT Id FROM Recovery_Action__c WHERE Action_Key__c='E2E_DEMO_ORDER_REPAIR' LIMIT 1];
FFM_RecoveryPreviewService.PreviewResponse preview=FFM_RecoveryPreviewService.preview(groupRecord.Id,action.Id,null,10);
FFM_RecoveryPreviewService.PreviewResponse result=FFM_RecoveryPreviewService.executeApprovedDemo(preview.job.Id);
System.debug(LoggingLevel.ERROR,'FFM_INVALID_RECOVERY_RESULT='+JSON.serialize(result.results));
