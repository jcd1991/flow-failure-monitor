Failure_Group__c groupRecord;
List<Failure_Group__c> groups=[SELECT Id FROM Failure_Group__c WHERE Fingerprint__c='e2e-invalid-recovery' LIMIT 1];
if(groups.isEmpty()){
    groupRecord=new Failure_Group__c(Fingerprint__c='e2e-invalid-recovery',Flow_Name__c='FFM_DemoOrderFlow',Element_Name__c='ValidateOrder',Error_Type__c='DML',Occurrence_Count__c=1,Status__c='New',Representative_Message__c='Demo failure with a stale record reference');
    insert groupRecord;
} else { groupRecord=groups[0]; }
if([SELECT COUNT() FROM Flow_Error__c WHERE Failure_Group__c=:groupRecord.Id]==0){
    insert new Flow_Error__c(Failure_Group__c=groupRecord.Id,Flow_Name__c='FFM_DemoOrderFlow',Element_Name__c='ValidateOrder',Fault_Message__c='Demo stale record reference',Record_Id__c='001000000000001AAA',Status__c='New',Occurred_At__c=System.now(),Redaction_Applied__c=true);
} else {
    List<Flow_Error__c> existingErrors = [SELECT Id,Occurred_At__c FROM Flow_Error__c WHERE Failure_Group__c=:groupRecord.Id];
    for (Flow_Error__c error : existingErrors) if (error.Occurred_At__c == null) error.Occurred_At__c = System.now();
    if (!existingErrors.isEmpty()) update existingErrors;
}
List<Recovery_Action__c> actions=[SELECT Id FROM Recovery_Action__c WHERE Action_Key__c='E2E_DEMO_ORDER_REPAIR' LIMIT 1];
System.debug(LoggingLevel.ERROR,'FFM_INVALID_RECOVERY_GROUP='+groupRecord.Id+' ACTION='+actions[0].Id);
