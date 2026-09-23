import { LightningElement, wire } from 'lwc';
import dashboardSnapshot from '@salesforce/apex/FFM_FlowErrorService.dashboardSnapshot';
import groupHistory from '@salesforce/apex/FFM_FlowErrorService.groupHistory';
import groupSamples from '@salesforce/apex/FFM_FlowErrorService.groupSamples';
import updateStatus from '@salesforce/apex/FFM_FlowErrorService.updateStatus';
import activeActions from '@salesforce/apex/FFM_RecoveryPreviewService.activeActions';
import previewRecovery from '@salesforce/apex/FFM_RecoveryPreviewService.preview';
import simulateRecovery from '@salesforce/apex/FFM_RecoveryPreviewService.simulate';
import executeApprovedDemo from '@salesforce/apex/FFM_RecoveryPreviewService.executeApprovedDemo';
import { refreshApex } from '@salesforce/apex';

export default class FlowFailureMonitor extends LightningElement {
    selectedDays = '30';
    snapshot;
    wiredDashboard;
    loading = true;
    dashboardError;
    statusFilter = '';
    selectedGroup;
    showDetails = false;
    history = [];
    samples = [];
    actions = [];
    actionLoadError;
    selectedAction = '';
    showRecovery = false;
    preview;
    previewRunning = false;
    previewError;
    simulateRunning = false;
    statusMessage;

    dateOptions = [
        { label: 'Last 7 days', value: '7' },
        { label: 'Last 30 days', value: '30' },
        { label: 'Last 90 days', value: '90' }
    ];
    statusOptions = [
        { label: 'All statuses', value: '' },
        { label: 'New', value: 'New' },
        { label: 'Acknowledged', value: 'Acknowledged' },
        { label: 'Investigating', value: 'Investigating' },
        { label: 'Resolved', value: 'Resolved' },
        { label: 'Ignored', value: 'Ignored' }
    ];

    @wire(dashboardSnapshot, { days: '$selectedDays' })
    wiredSnapshot(result) {
        this.wiredDashboard = result;
        this.loading = false;
        if (result.data) {
            this.snapshot = result.data;
            this.dashboardError = undefined;
        } else if (result.error) {
            this.dashboardError = this.message(result.error);
        }
    }

    @wire(groupHistory, { groupId: '$selectedGroup' })
    wiredHistory({ data }) { if (data) this.history = data; }

    @wire(groupSamples, { groupId: '$selectedGroup' })
    wiredSamples({ data }) { if (data) this.samples = data; }

    @wire(activeActions)
    wiredActions({ data, error }) {
        if (data) {
            this.actions = data;
            this.actionLoadError = undefined;
        }
        if (error) this.actionLoadError = this.message(error);
    }

    get hasSnapshot() { return !!this.snapshot; }
    get hasData() { return this.hasSnapshot && this.snapshot.failureEvents > 0; }
    get hasImpact() { return this.filteredImpact.length > 0; }
    get hasTopFlows() { return this.snapshot?.topFlows?.length > 0; }
    get topFlowsView() {
        return (this.snapshot?.topFlows || []).map((flow, index) => ({
            ...flow,
            key: `${flow.flowName}-${index}`,
            statusClass: flow.status === 'Open' ? 'status-indicator status-indicator-open' : 'status-indicator status-indicator-resolved'
        }));
    }
    get topElementsView() {
        return (this.snapshot?.topElements || []).map((element, index) => ({ ...element, key: `${element.flowName}-${element.elementName}-${index}` }));
    }
    get hasTopElements() { return this.topElementsView.length > 0; }
    get hasTrends() { return this.snapshot?.trends?.length > 0; }
    get actionOptions() { return this.actions.map((action) => ({ label: action.Label__c || action.Action_Key__c, value: action.Id })); }
    get selectedActionRecord() { return this.actions.find((action) => action.Id === this.selectedAction); }
    get previewDisabled() { return !this.selectedAction || this.previewRunning || !!this.actionLoadError; }
    get simulateDisabled() { return !this.preview || this.simulateRunning || this.preview.job.Status__c !== 'Previewed'; }
    get executeDisabled() {
        return !this.preview || this.simulateRunning || this.preview.job.Status__c !== 'Previewed' || this.selectedActionRecord?.Action_Key__c !== 'E2E_DEMO_ORDER_REPAIR';
    }
    get filteredImpact() {
        const impact = this.snapshot?.impact || [];
        return this.statusFilter ? impact.filter((row) => row.status === this.statusFilter) : impact;
    }
    get trendBars() {
        const trends = this.snapshot?.trends || [];
        const max = Math.max(...trends.map((trend) => Number(trend.count) || 0), 1);
        return trends.map((trend) => ({
            ...trend,
            label: String(trend.day).slice(5),
            style: `height:${Math.max(8, Math.round((Number(trend.count) / max) * 100))}%`,
            title: `${trend.day}: ${trend.count} captured failure events`
        }));
    }
    get sourceStatusClass() {
        return this.snapshot?.captureSource?.latestCapturedAt ? 'source-status source-status-active' : 'source-status source-status-waiting';
    }
    get sourceStatusIcon() { return this.snapshot?.captureSource?.latestCapturedAt ? 'utility:check' : 'utility:info'; }
    get hasSamples() { return this.samples.length > 0; }
    get hasHistory() { return this.history.length > 0; }
    get detailsTitle() {
        const row = (this.snapshot?.impact || []).find((impact) => impact.id === this.selectedGroup);
        return row ? `${row.flowName} · ${row.elementName}` : 'Investigate failure group';
    }

    message(error) { return error?.body?.message || error?.message || 'Unexpected Salesforce error.'; }

    changeDays(event) {
        this.loading = true;
        this.selectedDays = event.detail.value;
    }

    changeStatus(event) { this.statusFilter = event.detail.value; }

    refresh() {
        this.loading = true;
        this.dashboardError = undefined;
        refreshApex(this.wiredDashboard).finally(() => { this.loading = false; });
    }

    openDetails(event) {
        this.selectedGroup = event.currentTarget.dataset.id;
        this.showDetails = true;
        this.showRecovery = false;
        this.selectedAction = '';
        this.preview = null;
        this.previewError = undefined;
        this.statusMessage = undefined;
    }

    closeDetails() { this.showDetails = false; }
    toggleRecovery() { this.showRecovery = !this.showRecovery; }
    selectAction(event) { this.selectedAction = event.detail.value; this.previewError = undefined; }

    async runPreview() {
        if (this.previewDisabled) return;
        this.previewRunning = true;
        this.previewError = undefined;
        this.preview = null;
        try {
            this.preview = await previewRecovery({ failureGroupId: this.selectedGroup, recoveryActionId: this.selectedAction, errorIds: null, requestedLimit: 50 });
            this.statusMessage = 'Preview created. No recovery action was executed.';
        } catch (error) {
            this.previewError = this.message(error);
        } finally {
            this.previewRunning = false;
        }
    }

    async simulate() {
        if (this.simulateDisabled) return;
        this.simulateRunning = true;
        this.previewError = undefined;
        try {
            this.preview = await simulateRecovery({ recoveryJobId: this.preview.job.Id });
            this.statusMessage = 'Simulation completed. No record or Flow was changed.';
        } catch (error) {
            this.previewError = this.message(error);
        } finally {
            this.simulateRunning = false;
        }
    }

    async executeDemo() {
        if (this.executeDisabled) return;
        this.simulateRunning = true;
        this.previewError = undefined;
        try {
            this.preview = await executeApprovedDemo({ recoveryJobId: this.preview.job.Id });
            this.statusMessage = 'Approved recovery Flow executed. Only the selected demo record was changed.';
        } catch (error) {
            this.previewError = this.message(error);
        } finally {
            this.simulateRunning = false;
        }
    }

    async setGroupStatus(event) {
        const nextStatus = event.currentTarget.dataset.status;
        const sample = this.samples[0];
        if (!sample) return;
        try {
            await updateStatus({ errorId: sample.Id, status: nextStatus, notes: 'Updated from Flow Reliability Dashboard.' });
            this.statusMessage = `Group marked ${nextStatus}.`;
            await refreshApex(this.wiredDashboard);
        } catch (error) {
            this.previewError = this.message(error);
        }
    }
}
