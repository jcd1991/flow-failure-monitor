public inherited sharing class FFM_LogFlowErrorAction {
    public class Request {
        @InvocableVariable(required=true) public String flowName;
        @InvocableVariable public String elementName;
        @InvocableVariable public String faultMessage;
        @InvocableVariable public String recordId;
        @InvocableVariable public String objectType;
        @InvocableVariable public String errorType;
        @InvocableVariable public String correlationId;
        @InvocableVariable public String interviewId;
        @InvocableVariable public String source;
        @InvocableVariable public String contextJson;
    }

    @InvocableMethod(label='Log Flow Failure' description='Publishes a redacted Flow fault to Flow Failure Monitor')
    public static void log(List<Request> requests) {
        if (requests == null || requests.isEmpty()) return;
        List<FFM_Failure_Capture__e> events = new List<FFM_Failure_Capture__e>();
        for (Request request : requests) {
            if (request == null || String.isBlank(request.flowName)) continue;
            events.add(new FFM_Failure_Capture__e(
                Flow_Name__c = FFM_FailureCaptureService.clip(request.flowName, 255),
                Element_Name__c = FFM_FailureCaptureService.clip(request.elementName, 255),
                Fault_Message__c = FFM_FailureCaptureService.clip(FFM_FailureCaptureService.redact(request.faultMessage), 255),
                Record_Id__c = FFM_FailureCaptureService.safeId(request.recordId),
                Object_Type__c = FFM_FailureCaptureService.clip(request.objectType, 80),
                Error_Type__c = FFM_FailureCaptureService.clip(request.errorType, 100),
                Correlation_Id__c = FFM_FailureCaptureService.clip(request.correlationId, 100),
                Source__c = FFM_FailureCaptureService.clip(String.isBlank(request.source) ? 'fault-path' : request.source, 50),
                Context_Json__c = FFM_FailureCaptureService.clip(FFM_FailureCaptureService.safeContext(request.contextJson), 255)
            ));
        }
        if (!events.isEmpty()) EventBus.publish(events);
    }
}
