Failure_Group__c groupRecord;
List<Failure_Group__c> existingGroups = [SELECT Id,Occurrence_Count__c FROM Failure_Group__c WHERE Fingerprint__c='e2e-preview-demo' LIMIT 1];
if (existingGroups.isEmpty()) {
    groupRecord = new Failure_Group__c(Fingerprint__c='e2e-preview-demo', Flow_Name__c='FFM_DemoOrderFlow', Element_Name__c='RepairOrder', Error_Type__c='DML', Occurrence_Count__c=2, Status__c='New', Representative_Message__c='Demo record for dashboard and dry-run validation');
    insert groupRecord;
} else {
    groupRecord = existingGroups[0];
}
if ([SELECT COUNT() FROM Flow_Error__c WHERE Failure_Group__c=:groupRecord.Id] == 0) {
    insert new List<Flow_Error__c>{
        new Flow_Error__c(Failure_Group__c=groupRecord.Id, Flow_Name__c='FFM_DemoOrderFlow', Element_Name__c='RepairOrder', Fault_Message__c='Demo eligible record', Record_Id__c='001000000000001AAA', Status__c='New', Occurred_At__c=System.now(), Redaction_Applied__c=true),
        new Flow_Error__c(Failure_Group__c=groupRecord.Id, Flow_Name__c='FFM_DemoOrderFlow', Element_Name__c='RepairOrder', Fault_Message__c='Demo skipped record', Record_Id__c='invalid', Status__c='New', Occurred_At__c=System.now(), Redaction_Applied__c=true)
    };
} else {
    List<Flow_Error__c> existingErrors = [SELECT Id,Occurred_At__c FROM Flow_Error__c WHERE Failure_Group__c=:groupRecord.Id];
    for (Flow_Error__c error : existingErrors) if (error.Occurred_At__c == null) error.Occurred_At__c = System.now();
    if (!existingErrors.isEmpty()) update existingErrors;
}
Recovery_Action__c action;
List<Recovery_Action__c> existingActions = [SELECT Id FROM Recovery_Action__c WHERE Action_Key__c='E2E_DEMO_ORDER_REPAIR' LIMIT 1];
if (existingActions.isEmpty()) {
    action = new Recovery_Action__c(Action_Key__c='E2E_DEMO_ORDER_REPAIR', Label__c='Demo order repair (approved Flow)', Flow_Name__c='FFM_DemoOrderRecovery', Active__c=true, Max_Batch_Size__c=10, Description__c='Allowlisted demo recovery Flow. Updates only the selected demo Account.');
    insert action;
} else {
    action = existingActions[0];
    action.Label__c='Demo order repair (approved Flow)'; action.Active__c=true; action.Description__c='Allowlisted demo recovery Flow. Updates only the selected demo Account.'; update action;
}
FFM_RecoveryPreviewService.PreviewResponse preview = FFM_RecoveryPreviewService.preview(groupRecord.Id, action.Id, null, 10);
System.debug(LoggingLevel.ERROR, 'FFM_E2E_PREVIEW=' + JSON.serialize(preview));
