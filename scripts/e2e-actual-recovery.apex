Account demoAccount;
List<Account> accounts = [SELECT Id,Name,Description FROM Account WHERE Name='FFM Actual Recovery Demo' LIMIT 1];
if (accounts.isEmpty()) { demoAccount = new Account(Name='FFM Actual Recovery Demo'); insert demoAccount; } else { demoAccount = accounts[0]; demoAccount.Description=null; update demoAccount; }

Failure_Group__c groupRecord;
List<Failure_Group__c> groups = [SELECT Id FROM Failure_Group__c WHERE Fingerprint__c='e2e-actual-recovery' LIMIT 1];
if (groups.isEmpty()) {
    groupRecord = new Failure_Group__c(Fingerprint__c='e2e-actual-recovery',Flow_Name__c='FFM_DemoOrderFlow',Element_Name__c='ValidateOrder',Error_Type__c='DML',Occurrence_Count__c=1,Status__c='New',Representative_Message__c='Demo failure before approved recovery');
    insert groupRecord;
} else { groupRecord=groups[0]; }
if ([SELECT COUNT() FROM Flow_Error__c WHERE Failure_Group__c=:groupRecord.Id] == 0) {
    insert new Flow_Error__c(Failure_Group__c=groupRecord.Id,Flow_Name__c='FFM_DemoOrderFlow',Element_Name__c='ValidateOrder',Fault_Message__c='Demo failure before approved recovery',Record_Id__c=demoAccount.Id,Status__c='New',Redaction_Applied__c=true);
}
Recovery_Action__c action;
List<Recovery_Action__c> actions=[SELECT Id FROM Recovery_Action__c WHERE Action_Key__c='E2E_DEMO_ORDER_REPAIR' LIMIT 1];
if(actions.isEmpty()){ action=new Recovery_Action__c(Action_Key__c='E2E_DEMO_ORDER_REPAIR',Label__c='Demo order repair (approved Flow)',Flow_Name__c='FFM_DemoOrderRecovery',Active__c=true,Max_Batch_Size__c=10,Description__c='Allowlisted demo recovery Flow. Updates only the selected demo Account.'); insert action; }
else { action=actions[0]; action.Label__c='Demo order repair (approved Flow)'; action.Flow_Name__c='FFM_DemoOrderRecovery'; action.Active__c=true; update action; }
System.debug(LoggingLevel.ERROR,'FFM_ACTUAL_RECOVERY_GROUP='+groupRecord.Id+' ACCOUNT='+demoAccount.Id+' ACTION='+action.Id);
