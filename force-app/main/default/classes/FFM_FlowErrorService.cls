public with sharing class FFM_FlowErrorService {
    private static final Set<String> STATUSES = new Set<String>{'New','Acknowledged','Investigating','Resolved','Ignored'};
    @AuraEnabled(cacheable=true)
    public static List<Failure_Group__c> failureGroups(Integer limitSize, String status) {
        Integer n = limitSize == null ? 50 : Math.min(Math.max(limitSize, 1), 200);
        if (String.isBlank(status)) return [SELECT Id,Name,Fingerprint__c,Flow_Name__c,Element_Name__c,Error_Type__c,Occurrence_Count__c,First_Seen__c,Last_Seen__c,Status__c,Representative_Message__c FROM Failure_Group__c WITH USER_MODE ORDER BY Last_Seen__c DESC NULLS LAST LIMIT :n];
        if (!STATUSES.contains(status)) throw new AuraHandledException('Unsupported status');
        return [SELECT Id,Name,Fingerprint__c,Flow_Name__c,Element_Name__c,Error_Type__c,Occurrence_Count__c,First_Seen__c,Last_Seen__c,Status__c,Representative_Message__c FROM Failure_Group__c WHERE Status__c=:status WITH USER_MODE ORDER BY Last_Seen__c DESC NULLS LAST LIMIT :n];
    }

    @AuraEnabled(cacheable=true)
    public static List<Failure_Activity__c> groupHistory(Id groupId) {
        if (groupId == null) return new List<Failure_Activity__c>();
        return [SELECT Id,Activity_Type__c,From_Status__c,To_Status__c,Notes__c,CreatedDate,CreatedBy.Name FROM Failure_Activity__c WHERE Failure_Group__c=:groupId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50];
    }

    @AuraEnabled(cacheable=true)
    public static List<Flow_Error__c> groupSamples(Id groupId) {
        if (groupId == null) return new List<Flow_Error__c>();
        return [SELECT Id,Name,Flow_Name__c,Element_Name__c,Fault_Message__c,Record_Id__c,Object_Type__c,Status__c,Retry_Count__c,Occurred_At__c,Redaction_Applied__c FROM Flow_Error__c WHERE Failure_Group__c=:groupId WITH USER_MODE ORDER BY CreatedDate ASC LIMIT 50];
    }

    @AuraEnabled(cacheable=true)
    public static List<Flow_Error__c> recentErrors(Integer limitSize, String status) {
        Integer n = limitSize == null ? 50 : Math.min(Math.max(limitSize, 1), 200);
        if (String.isBlank(status)) return [SELECT Id,Name,Flow_Name__c,Element_Name__c,Fault_Message__c,Record_Id__c,Object_Type__c,Status__c,Retry_Count__c,Occurred_At__c,CreatedDate,CreatedBy.Name FROM Flow_Error__c WITH USER_MODE ORDER BY CreatedDate DESC LIMIT :n];
        if (!STATUSES.contains(status)) throw new AuraHandledException('Unsupported status');
        return [SELECT Id,Name,Flow_Name__c,Element_Name__c,Fault_Message__c,Record_Id__c,Object_Type__c,Status__c,Retry_Count__c,Occurred_At__c,CreatedDate,CreatedBy.Name FROM Flow_Error__c WHERE Status__c=:status WITH USER_MODE ORDER BY CreatedDate DESC LIMIT :n];
    }
    @AuraEnabled
    public static Flow_Error__c updateStatus(Id errorId, String status, String notes) {
        if (!STATUSES.contains(status) || errorId == null) throw new AuraHandledException('Invalid status or failure');
        Flow_Error__c error = [SELECT Id,Failure_Group__c,Status__c FROM Flow_Error__c WHERE Id=:errorId WITH USER_MODE LIMIT 1];
        error.Status__c = status;
        Database.update(error, AccessLevel.USER_MODE);
        if (error.Failure_Group__c != null) {
            Failure_Group__c failureGroup = [SELECT Id,Status__c FROM Failure_Group__c WHERE Id=:error.Failure_Group__c WITH USER_MODE LIMIT 1];
            String oldStatus = failureGroup.Status__c;
            failureGroup.Status__c = status;
            Database.update(failureGroup, AccessLevel.USER_MODE);
            Database.insert(new Failure_Activity__c(Failure_Group__c=failureGroup.Id,Activity_Type__c='Status',From_Status__c=oldStatus,To_Status__c=status,Notes__c=FFM_FailureCaptureService.clip(notes,4000)), AccessLevel.USER_MODE);
        }
        return error;
    }
}
