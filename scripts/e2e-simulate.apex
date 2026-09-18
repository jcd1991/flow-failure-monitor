Recovery_Job__c job = [SELECT Id FROM Recovery_Job__c WHERE Failure_Group__r.Fingerprint__c='e2e-preview-demo' AND Status__c='Previewed' ORDER BY CreatedDate DESC LIMIT 1];
FFM_RecoveryPreviewService.PreviewResponse output = FFM_RecoveryPreviewService.simulate(job.Id);
System.debug(LoggingLevel.ERROR, 'FFM_E2E_SIMULATED=' + JSON.serialize(output));
