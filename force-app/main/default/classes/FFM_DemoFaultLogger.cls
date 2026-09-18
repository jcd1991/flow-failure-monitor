public with sharing class FFM_DemoFaultLogger {
    @InvocableMethod(label='FFM Demo: capture fault' description='Captures the controlled demo Flow fault through the normal Flow Failure Monitor action.')
    public static void capture(List<String> messages) {
        List<FFM_LogFlowErrorAction.Request> requests = new List<FFM_LogFlowErrorAction.Request>();
        List<String> supplied = (messages == null || messages.isEmpty()) ? new List<String>{'Demo order validation failed: missing fulfillment address.'} : messages;
        for (String message : supplied) {
            FFM_LogFlowErrorAction.Request request = new FFM_LogFlowErrorAction.Request();
            request.flowName = 'FFM_DemoOrderFlow';
            request.elementName = 'ValidateOrder';
            request.faultMessage = String.isBlank(message) ? 'Demo order validation failed.' : message;
            request.recordId = '001000000000001AAA';
            request.objectType = 'Account';
            request.errorType = 'FlowActionException';
            request.source = 'demo-fault-connector';
            request.contextJson = '{"demo":true,"recovery":"approved-action-only"}';
            requests.add(request);
        }
        FFM_LogFlowErrorAction.log(requests);
    }
}
