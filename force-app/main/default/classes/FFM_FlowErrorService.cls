public with sharing class FFM_FlowErrorService {
    private static final Set<String> STATUSES = new Set<String>{'New','Acknowledged','Investigating','Resolved','Ignored'};
    private static final Set<String> OPEN_STATUSES = new Set<String>{'New','Acknowledged','Investigating'};

    public class DashboardTrend {
        @AuraEnabled public String day;
        @AuraEnabled public Integer count;
        public DashboardTrend(String dayValue, Integer countValue) { day = dayValue; count = countValue; }
    }

    public class DashboardFlow {
        @AuraEnabled public String flowName;
        @AuraEnabled public Integer eventCount;
        @AuraEnabled public Integer groupCount;
        @AuraEnabled public Datetime lastSeen;
        public DashboardFlow(String name, Integer events, Integer groups, Datetime seen) {
            flowName = name; eventCount = events; groupCount = groups; lastSeen = seen;
        }
    }

    public class DashboardElement {
        @AuraEnabled public String flowName;
        @AuraEnabled public String elementName;
        @AuraEnabled public Integer eventCount;
        @AuraEnabled public Integer groupCount;
        @AuraEnabled public Datetime lastSeen;
        public DashboardElement(String flow, String element, Integer events, Integer groups, Datetime seen) {
            flowName = flow; elementName = element; eventCount = events; groupCount = groups; lastSeen = seen;
        }
    }

    public class DashboardImpact {
        @AuraEnabled public String id;
        @AuraEnabled public String flowName;
        @AuraEnabled public String elementName;
        @AuraEnabled public String status;
        @AuraEnabled public Integer eventCount;
        @AuraEnabled public Integer affectedRecords;
        @AuraEnabled public Datetime lastSeen;
        @AuraEnabled public String message;
        public DashboardImpact(String groupId, String flow, String element, String groupStatus, Integer events, Integer records, Datetime seen, String representativeMessage) {
            id = groupId; flowName = flow; elementName = element; status = groupStatus; eventCount = events; affectedRecords = records; lastSeen = seen; message = representativeMessage;
        }
    }

    public class CaptureSource {
        @AuraEnabled public String status;
        @AuraEnabled public String detail;
        @AuraEnabled public Datetime latestCapturedAt;
        @AuraEnabled public List<String> supportedSources;
        public CaptureSource(String sourceStatus, String sourceDetail, Datetime latest, List<String> sources) {
            status = sourceStatus; detail = sourceDetail; latestCapturedAt = latest; supportedSources = sources;
        }
    }

    public class DashboardSnapshot {
        @AuraEnabled public Integer windowDays;
        @AuraEnabled public Integer failureEvents;
        @AuraEnabled public Integer failureGroups;
        @AuraEnabled public Integer affectedRecords;
        @AuraEnabled public Integer openGroups;
        @AuraEnabled public List<DashboardTrend> trends;
        @AuraEnabled public List<DashboardFlow> topFlows;
        @AuraEnabled public List<DashboardElement> topElements;
        @AuraEnabled public List<DashboardImpact> impact;
        @AuraEnabled public CaptureSource captureSource;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardSnapshot dashboardSnapshot(Integer days) {
        Integer windowDays = days == null ? 30 : days;
        if (windowDays < 1 || windowDays > 90) throw new AuraHandledException('days must be between 1 and 90');
        Datetime since = System.now().addDays(-windowDays);
        DashboardSnapshot snapshot = new DashboardSnapshot();
        snapshot.windowDays = windowDays;
        snapshot.trends = new List<DashboardTrend>();
        snapshot.topFlows = new List<DashboardFlow>();
        snapshot.topElements = new List<DashboardElement>();
        snapshot.impact = new List<DashboardImpact>();

        AggregateResult totals = [SELECT COUNT(Id) eventCount, COUNT_DISTINCT(Failure_Group__c) groupCount, COUNT_DISTINCT(Record_Id__c) recordCount
                                  FROM Flow_Error__c WHERE Occurred_At__c >= :since WITH USER_MODE];
        snapshot.failureEvents = aggregateInteger(totals, 'eventCount');
        snapshot.failureGroups = aggregateInteger(totals, 'groupCount');
        snapshot.affectedRecords = aggregateInteger(totals, 'recordCount');

        AggregateResult latest = [SELECT MAX(Occurred_At__c) latest FROM Flow_Error__c WITH USER_MODE];
        Datetime latestCaptured = (Datetime)latest.get('latest');
        snapshot.captureSource = new CaptureSource(
            latestCaptured == null ? 'Waiting for captured events' : 'Receiving captured events',
            'Counts include only failures published through an explicit fault connector or a supported FFM_Failure_Capture__e publisher.',
            latestCaptured,
            new List<String>{'Flow fault connector → FFM_LogFlowErrorAction', 'Supported FFM_Failure_Capture__e publisher'}
        );

        for (AggregateResult row : [SELECT DAY_ONLY(Occurred_At__c) day, COUNT(Id) total
                                    FROM Flow_Error__c WHERE Occurred_At__c >= :since WITH USER_MODE
                                    GROUP BY DAY_ONLY(Occurred_At__c) ORDER BY DAY_ONLY(Occurred_At__c) LIMIT 91]) {
            snapshot.trends.add(new DashboardTrend(String.valueOf(row.get('day')), aggregateInteger(row, 'total')));
        }

        for (AggregateResult row : [SELECT Flow_Name__c flowName, COUNT(Id) total, COUNT_DISTINCT(Failure_Group__c) groups, MAX(Occurred_At__c) lastSeen
                                    FROM Flow_Error__c WHERE Occurred_At__c >= :since WITH USER_MODE
                                    GROUP BY Flow_Name__c ORDER BY COUNT(Id) DESC LIMIT 10]) {
            snapshot.topFlows.add(new DashboardFlow(String.valueOf(row.get('flowName')), aggregateInteger(row, 'total'), aggregateInteger(row, 'groups'), (Datetime)row.get('lastSeen')));
        }

        for (AggregateResult row : [SELECT Flow_Name__c flowName, Element_Name__c elementName, COUNT(Id) total, COUNT_DISTINCT(Failure_Group__c) groups, MAX(Occurred_At__c) lastSeen
                                    FROM Flow_Error__c WHERE Occurred_At__c >= :since WITH USER_MODE
                                    GROUP BY Flow_Name__c, Element_Name__c ORDER BY COUNT(Id) DESC LIMIT 10]) {
            snapshot.topElements.add(new DashboardElement(String.valueOf(row.get('flowName')), String.valueOf(row.get('elementName')), aggregateInteger(row, 'total'), aggregateInteger(row, 'groups'), (Datetime)row.get('lastSeen')));
        }

        snapshot.openGroups = [SELECT COUNT() FROM Failure_Group__c
                               WHERE Status__c IN :OPEN_STATUSES
                               AND Id IN (SELECT Failure_Group__c FROM Flow_Error__c WHERE Occurred_At__c >= :since)
                               WITH USER_MODE];

        List<AggregateResult> impactRows = [SELECT Failure_Group__c groupId, COUNT(Id) total, COUNT_DISTINCT(Record_Id__c) records, MAX(Occurred_At__c) lastSeen
                                            FROM Flow_Error__c WHERE Occurred_At__c >= :since AND Failure_Group__c != null WITH USER_MODE
                                            GROUP BY Failure_Group__c ORDER BY COUNT(Id) DESC LIMIT 50];
        Set<Id> impactGroupIds = new Set<Id>();
        for (AggregateResult row : impactRows) impactGroupIds.add((Id)row.get('groupId'));
        Map<Id, Failure_Group__c> groupsById = new Map<Id, Failure_Group__c>();
        if (!impactGroupIds.isEmpty()) {
            groupsById = new Map<Id, Failure_Group__c>([SELECT Id,Flow_Name__c,Element_Name__c,Status__c,Representative_Message__c
                                                        FROM Failure_Group__c WHERE Id IN :impactGroupIds WITH USER_MODE LIMIT 50]);
        }
        for (AggregateResult row : impactRows) {
            Id groupId = (Id)row.get('groupId');
            Failure_Group__c groupRow = groupsById.get(groupId);
            if (groupRow == null) continue;
            snapshot.impact.add(new DashboardImpact(String.valueOf(groupId), groupRow.Flow_Name__c, groupRow.Element_Name__c, groupRow.Status__c,
                aggregateInteger(row, 'total'), aggregateInteger(row, 'records'), (Datetime)row.get('lastSeen'), FFM_FailureCaptureService.clip(groupRow.Representative_Message__c, 240)));
        }
        return snapshot;
    }

    private static Integer aggregateInteger(AggregateResult row, String alias) {
        Object value = row == null ? null : row.get(alias);
        return value == null ? 0 : Integer.valueOf(String.valueOf(value));
    }

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
