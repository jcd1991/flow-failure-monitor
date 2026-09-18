// Sanitized fixtures based on recurring public Salesforce Flow failure patterns.
// The production capture path is used; no business records are mutated.
List<FFM_LogFlowErrorAction.Request> cases = new List<FFM_LogFlowErrorAction.Request>();

for (String recordId : new List<String>{'001000000000001AAA','001000000000002AAA'}) {
    FFM_LogFlowErrorAction.Request duplicateDml = new FFM_LogFlowErrorAction.Request();
    duplicateDml.flowName='FFM_RealWorld_DuplicateDmlFlow'; duplicateDml.elementName='CreateAccount';
    duplicateDml.faultMessage='DUPLICATES_DETECTED: duplicate value found on record'; duplicateDml.recordId=recordId;
    duplicateDml.objectType='Account'; duplicateDml.errorType='DML'; duplicateDml.source='real-world-case'; duplicateDml.contextJson='{"case":"duplicate-rule-dml","redact":"email@example.com"}'; cases.add(duplicateDml);

    FFM_LogFlowErrorAction.Request callout = new FFM_LogFlowErrorAction.Request();
    callout.flowName='FFM_RealWorld_CalloutFlow'; callout.elementName='SendToERP';
    callout.faultMessage='System.CalloutException: You have uncommitted work pending. Please commit or rollback before calling out'; callout.recordId=recordId;
    callout.objectType='Order__c'; callout.errorType='CalloutException'; callout.source='real-world-case'; cases.add(callout);

    FFM_LogFlowErrorAction.Request bulkCase = new FFM_LogFlowErrorAction.Request();
    bulkCase.flowName='FFM_RealWorld_BulkUpdateFlow'; bulkCase.elementName='UpdateTasks';
    bulkCase.faultMessage='System.ListException: Duplicate id in list'; bulkCase.recordId=recordId;
    bulkCase.objectType='Task'; bulkCase.errorType='ListException'; bulkCase.source='real-world-case'; cases.add(bulkCase);

    FFM_LogFlowErrorAction.Request validation = new FFM_LogFlowErrorAction.Request();
    validation.flowName='FFM_RealWorld_ValidationFlow'; validation.elementName='UpdateOrder';
    validation.faultMessage='FIELD_CUSTOM_VALIDATION_EXCEPTION: Fulfillment address is required'; validation.recordId=recordId;
    validation.objectType='Order__c'; validation.errorType='ValidationException'; validation.source='real-world-case'; cases.add(validation);
}

FFM_LogFlowErrorAction.log(cases);
System.debug(LoggingLevel.ERROR, 'FFM_REAL_WORLD_CASES_PUBLISHED=' + cases.size());
