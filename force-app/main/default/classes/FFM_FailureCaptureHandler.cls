public inherited sharing class FFM_FailureCaptureHandler {
    public static void handle(List<FFM_Failure_Capture__e> events) {
        if (events == null || events.isEmpty()) return;
        Map<String, FFM_Failure_Capture__e> byFingerprint = new Map<String, FFM_Failure_Capture__e>();
        Map<String, Integer> counts = new Map<String, Integer>();
        for (FFM_Failure_Capture__e event : events) {
            if (event == null || String.isBlank(event.Flow_Name__c)) continue;
            String fp = FFM_FailureCaptureService.fingerprint(event.Flow_Name__c, event.Element_Name__c, event.Error_Type__c, event.Object_Type__c, event.Fault_Message__c);
            if (!byFingerprint.containsKey(fp)) byFingerprint.put(fp, event);
            counts.put(fp, (counts.containsKey(fp) ? counts.get(fp) : 0) + 1);
        }
        if (byFingerprint.isEmpty()) return;
        Map<String, Failure_Group__c> groups = new Map<String, Failure_Group__c>();
        for (Failure_Group__c failureGroup : [SELECT Id,Fingerprint__c,Occurrence_Count__c,First_Seen__c,Last_Seen__c,Representative_Message__c FROM Failure_Group__c WHERE Fingerprint__c IN :byFingerprint.keySet() FOR UPDATE]) groups.put(failureGroup.Fingerprint__c, failureGroup);
        Datetime now = System.now();
        List<Failure_Group__c> toInsert = new List<Failure_Group__c>();
        for (String fp : byFingerprint.keySet()) if (!groups.containsKey(fp)) {
            FFM_Failure_Capture__e event = byFingerprint.get(fp);
            toInsert.add(new Failure_Group__c(Fingerprint__c=fp, Flow_Name__c=FFM_FailureCaptureService.clip(event.Flow_Name__c,255), Element_Name__c=FFM_FailureCaptureService.clip(event.Element_Name__c,255), Error_Type__c=FFM_FailureCaptureService.clip(event.Error_Type__c,100), Occurrence_Count__c=0, First_Seen__c=now, Last_Seen__c=now, Representative_Message__c=FFM_FailureCaptureService.clip(event.Fault_Message__c,4000), Status__c='New'));
        }
        if (!toInsert.isEmpty()) Database.insert(toInsert, false);
        for (Failure_Group__c failureGroup : [SELECT Id,Fingerprint__c,Occurrence_Count__c,First_Seen__c,Last_Seen__c,Representative_Message__c FROM Failure_Group__c WHERE Fingerprint__c IN :byFingerprint.keySet() FOR UPDATE]) groups.put(failureGroup.Fingerprint__c, failureGroup);
        List<Failure_Group__c> updates = new List<Failure_Group__c>();
        List<Flow_Error__c> samples = new List<Flow_Error__c>();
        for (String fp : byFingerprint.keySet()) {
            FFM_Failure_Capture__e event = byFingerprint.get(fp);
            Failure_Group__c failureGroup = groups.get(fp);
            failureGroup.Occurrence_Count__c = (failureGroup.Occurrence_Count__c == null ? 0 : failureGroup.Occurrence_Count__c) + counts.get(fp);
            failureGroup.Last_Seen__c = now;
            if (failureGroup.First_Seen__c == null) failureGroup.First_Seen__c = now;
            if (String.isBlank(failureGroup.Representative_Message__c)) failureGroup.Representative_Message__c = FFM_FailureCaptureService.clip(event.Fault_Message__c,4000);
            updates.add(failureGroup);
            samples.add(new Flow_Error__c(Failure_Group__c=failureGroup.Id, Fingerprint__c=fp, Flow_Name__c=FFM_FailureCaptureService.clip(event.Flow_Name__c,255), Element_Name__c=FFM_FailureCaptureService.clip(event.Element_Name__c,255), Fault_Message__c=FFM_FailureCaptureService.clip(event.Fault_Message__c,131072), Record_Id__c=FFM_FailureCaptureService.safeId(event.Record_Id__c), Object_Type__c=FFM_FailureCaptureService.clip(event.Object_Type__c,80), Error_Type__c=FFM_FailureCaptureService.clip(event.Error_Type__c,100), Correlation_Id__c=FFM_FailureCaptureService.clip(event.Correlation_Id__c,100), Source__c=FFM_FailureCaptureService.clip(event.Source__c,50), Context_Json__c=FFM_FailureCaptureService.clip(event.Context_Json__c,131072), Running_User_Id__c=UserInfo.getUserId(), Occurred_At__c=now, Redaction_Applied__c=true, Sampled__c=true, Status__c='New', Retry_Count__c=0));
        }
        Database.update(updates, false);
        Database.insert(samples, false);
    }
}
