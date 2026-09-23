@IsTest
private class FFM_FlowFailureMonitorTest {
    @IsTest static void redactionAndFingerprintAreDeterministic() {
        String redacted = FFM_FailureCaptureService.redact('password=secret user@example.com +1 404 555 1212');
        System.assert(!redacted.contains('secret'));
        System.assert(redacted.contains('[EMAIL]'));
        System.assertEquals(FFM_FailureCaptureService.fingerprint('OrderFlow','Create','DML','Order__c','bad 123'), FFM_FailureCaptureService.fingerprint('OrderFlow','Create','DML','Order__c','bad 456'));
        System.assertEquals(null, FFM_FailureCaptureService.safeId('not-an-id'));
        System.assert(FFM_FailureCaptureService.safeContext('{"email":"user@example.com","safe":"ok","password":"x"}').contains('[EMAIL]'));
    }

    @IsTest static void capturePublishesAndGroups() {
        FFM_LogFlowErrorAction.Request request = new FFM_LogFlowErrorAction.Request();
        request.flowName='OrderFlow'; request.elementName='CreateOrder'; request.faultMessage='password=secret order failed'; request.objectType='Order__c'; request.errorType='DML'; request.recordId='001000000000001AAA'; request.contextJson='{"safe":"yes","token":"hidden"}';
        Test.startTest();
        FFM_LogFlowErrorAction.log(new List<FFM_LogFlowErrorAction.Request>{request});
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Failure_Group__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Flow_Error__c]);
        Flow_Error__c sample=[SELECT Fault_Message__c,Context_Json__c,Redaction_Applied__c FROM Flow_Error__c LIMIT 1];
        System.assert(sample.Redaction_Applied__c);
        System.assert(!sample.Fault_Message__c.contains('secret'));
        System.assert(!sample.Context_Json__c.contains('hidden'));
    }

    @IsTest static void demoFaultLoggerUsesNormalCapturePath() {
        Test.startTest();
        FFM_DemoFaultLogger.capture(null);
        Test.getEventBus().deliver();
        Test.stopTest();
        Flow_Error__c sample=[SELECT Flow_Name__c,Element_Name__c,Source__c,Redaction_Applied__c FROM Flow_Error__c LIMIT 1];
        System.assertEquals('FFM_DemoOrderFlow',sample.Flow_Name__c);
        System.assertEquals('ValidateOrder',sample.Element_Name__c);
        System.assertEquals('demo-fault-connector',sample.Source__c);
        System.assert(sample.Redaction_Applied__c);
    }

    @IsTest static void serviceUpdatesStatusAndHistory() {
        Failure_Group__c failureGroup=new Failure_Group__c(Fingerprint__c='abc123',Flow_Name__c='Flow',Element_Name__c='Element',Occurrence_Count__c=1,Status__c='New');
        insert failureGroup;
        Flow_Error__c sample=new Flow_Error__c(Failure_Group__c=failureGroup.Id,Flow_Name__c='Flow',Element_Name__c='Element',Fault_Message__c='message',Status__c='New',Retry_Count__c=0);
        insert sample;
        Test.startTest();
        FFM_FlowErrorService.updateStatus(sample.Id,'Resolved','fixed');
        Test.stopTest();
        System.assertEquals('Resolved',[SELECT Status__c FROM Flow_Error__c WHERE Id=:sample.Id].Status__c);
        System.assertEquals('Resolved',[SELECT Status__c FROM Failure_Group__c WHERE Id=:failureGroup.Id].Status__c);
        System.assertEquals(1,[SELECT COUNT() FROM Failure_Activity__c WHERE Failure_Group__c=:failureGroup.Id]);
        System.assertEquals(1, FFM_FlowErrorService.groupHistory(failureGroup.Id).size());
    }

    @IsTest static void recoveryPreviewIsSafeAndIdempotent() {
        Failure_Group__c failureGroup=new Failure_Group__c(Fingerprint__c='preview-'+String.valueOf(DateTime.now().getTime()),Flow_Name__c='OrderFlow',Element_Name__c='Repair',Occurrence_Count__c=2,Status__c='New');
        insert failureGroup;
        Flow_Error__c valid=new Flow_Error__c(Failure_Group__c=failureGroup.Id,Flow_Name__c='OrderFlow',Element_Name__c='Repair',Fault_Message__c='needs repair',Record_Id__c='001000000000001AAA',Status__c='New');
        Flow_Error__c invalid=new Flow_Error__c(Failure_Group__c=failureGroup.Id,Flow_Name__c='OrderFlow',Element_Name__c='Repair',Fault_Message__c='missing record',Record_Id__c='bad-id',Status__c='New');
        insert new List<Flow_Error__c>{valid,invalid};
        Recovery_Action__c action=new Recovery_Action__c(Action_Key__c='ORDER_REPAIR_'+String.valueOf(DateTime.now().getTime()),Label__c='Order repair preview',Flow_Name__c='FFM_OrderRecovery',Active__c=true,Max_Batch_Size__c=10);
        insert action;
        Test.startTest();
        FFM_RecoveryPreviewService.PreviewResponse response=FFM_RecoveryPreviewService.preview(failureGroup.Id,action.Id,null,10);
        Test.stopTest();
        System.assertEquals(2,response.results.size());
        System.assertEquals(1,response.job.Eligible_Count__c);
        System.assertEquals(1,response.job.Skipped_Count__c);
        System.assertEquals('Previewed',response.job.Status__c);
        System.assertEquals(1,[SELECT COUNT() FROM Recovery_Result__c WHERE Recovery_Job__c=:response.job.Id AND Outcome__c='Eligible']);
        System.assertEquals(1,[SELECT COUNT() FROM Recovery_Result__c WHERE Recovery_Job__c=:response.job.Id AND Outcome__c='Skipped']);
        System.assertEquals(2, FFM_FlowErrorService.groupSamples(failureGroup.Id).size());
        FFM_RecoveryPreviewService.PreviewResponse simulated=FFM_RecoveryPreviewService.simulate(response.job.Id);
        System.assertEquals('Completed', simulated.job.Status__c);
        System.assertEquals(1,[SELECT COUNT() FROM Recovery_Result__c WHERE Recovery_Job__c=:response.job.Id AND Outcome__c='Success']);
    }

    @IsTest static void dashboardSnapshotAggregatesCountsTrendsAndImpact() {
        Datetime now = System.now();
        Failure_Group__c orderGroup = new Failure_Group__c(Fingerprint__c='dashboard-order-'+String.valueOf(now.getTime()), Flow_Name__c='OrderFlow', Element_Name__c='UpdateOrder', Occurrence_Count__c=3, Status__c='New', Representative_Message__c='Order validation failed');
        Failure_Group__c caseGroup = new Failure_Group__c(Fingerprint__c='dashboard-case-'+String.valueOf(now.getTime()), Flow_Name__c='CaseFlow', Element_Name__c='CreateCase', Occurrence_Count__c=1, Status__c='Resolved', Representative_Message__c='Case could not be created');
        Failure_Group__c oldGroup = new Failure_Group__c(Fingerprint__c='dashboard-old-'+String.valueOf(now.getTime()), Flow_Name__c='OldFlow', Element_Name__c='OldElement', Occurrence_Count__c=1, Status__c='Investigating', Representative_Message__c='Outside window');
        insert new List<Failure_Group__c>{orderGroup,caseGroup,oldGroup};
        insert new List<Flow_Error__c>{
            new Flow_Error__c(Failure_Group__c=orderGroup.Id, Flow_Name__c='OrderFlow', Element_Name__c='UpdateOrder', Fault_Message__c='order 101 failed', Record_Id__c='001000000000001AAA', Status__c='New', Occurred_At__c=now.addDays(-1)),
            new Flow_Error__c(Failure_Group__c=orderGroup.Id, Flow_Name__c='OrderFlow', Element_Name__c='UpdateOrder', Fault_Message__c='order 102 failed', Record_Id__c='001000000000002AAA', Status__c='New', Occurred_At__c=now.addDays(-2)),
            new Flow_Error__c(Failure_Group__c=orderGroup.Id, Flow_Name__c='OrderFlow', Element_Name__c='UpdateOrder', Fault_Message__c='order 101 failed again', Record_Id__c='001000000000001AAA', Status__c='New', Occurred_At__c=now.addDays(-3)),
            new Flow_Error__c(Failure_Group__c=caseGroup.Id, Flow_Name__c='CaseFlow', Element_Name__c='CreateCase', Fault_Message__c='case failed', Record_Id__c='001000000000003AAA', Status__c='Resolved', Occurred_At__c=now.addDays(-4)),
            new Flow_Error__c(Failure_Group__c=oldGroup.Id, Flow_Name__c='OldFlow', Element_Name__c='OldElement', Fault_Message__c='old failure', Record_Id__c='001000000000004AAA', Status__c='Investigating', Occurred_At__c=now.addDays(-100))
        };

        Test.startTest();
        FFM_FlowErrorService.DashboardSnapshot snapshot = FFM_FlowErrorService.dashboardSnapshot(30);
        Test.stopTest();

        System.assertEquals(4, snapshot.failureEvents);
        System.assertEquals(2, snapshot.failureGroups);
        System.assertEquals(3, snapshot.affectedRecords);
        System.assertEquals(1, snapshot.openGroups);
        System.assertEquals(2, snapshot.topFlows.size());
        System.assertEquals('OrderFlow', snapshot.topFlows[0].flowName);
        System.assertEquals(3, snapshot.topFlows[0].eventCount);
        System.assertEquals('Open', snapshot.topFlows[0].status);
        System.assertEquals(2, snapshot.topElements.size());
        System.assertEquals(3, snapshot.topElements[0].eventCount);
        System.assertEquals(2, snapshot.impact.size());
        System.assertEquals(2, snapshot.impact[0].affectedRecords);
        System.assertEquals(4, snapshot.trends.size());
        System.assertEquals('Receiving captured events', snapshot.captureSource.status);
        System.assertNotEquals(null, snapshot.captureSource.latestCapturedAt);

        FFM_FlowErrorService.DashboardSnapshot ninetyDaySnapshot = FFM_FlowErrorService.dashboardSnapshot(90);
        System.assertEquals(4, ninetyDaySnapshot.failureEvents);

        Boolean rejected = false;
        try { FFM_FlowErrorService.dashboardSnapshot(91); } catch (AuraHandledException ex) { rejected = true; }
        System.assert(rejected, 'Dashboard windows above 90 days must be rejected');
    }

    @IsTest static void apiV2ContractIsDtoAndBounded() {
        RestRequest request=new RestRequest(); request.httpMethod='GET'; request.requestURI='/services/apexrest/ffm/v2/groups'; request.addParameter('limit','201'); RestContext.request=request; RestContext.response=new RestResponse();
        FFM_FlowFailureApiV2.get();
        System.assertEquals(400,RestContext.response.statusCode);
        request=new RestRequest(); request.httpMethod='GET'; request.requestURI='/services/apexrest/ffm/v2/capabilities'; RestContext.request=request; RestContext.response=new RestResponse(); FFM_FlowFailureApiV2.get();
        System.assertEquals(200,RestContext.response.statusCode); System.assert(RestContext.response.responseBody.toString().contains('v2'));
        request=new RestRequest(); request.httpMethod='POST'; request.requestURI='/services/apexrest/ffm/v2/recovery/preview'; request.requestBody=Blob.valueOf('{}'); RestContext.request=request; RestContext.response=new RestResponse(); FFM_FlowFailureApiV2.post();
        System.assertEquals(400,RestContext.response.statusCode);
    }

}
