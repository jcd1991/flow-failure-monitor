import { LightningElement, wire } from 'lwc';
import failureGroups from '@salesforce/apex/FFM_FlowErrorService.failureGroups';
import groupHistory from '@salesforce/apex/FFM_FlowErrorService.groupHistory';
import groupSamples from '@salesforce/apex/FFM_FlowErrorService.groupSamples';
import updateStatus from '@salesforce/apex/FFM_FlowErrorService.updateStatus';
import activeActions from '@salesforce/apex/FFM_RecoveryPreviewService.activeActions';
import previewRecovery from '@salesforce/apex/FFM_RecoveryPreviewService.preview';
import simulateRecovery from '@salesforce/apex/FFM_RecoveryPreviewService.simulate';
import executeApprovedDemo from '@salesforce/apex/FFM_RecoveryPreviewService.executeApprovedDemo';
import { refreshApex } from '@salesforce/apex';

export default class FlowFailureMonitor extends LightningElement {
    groups = []; status = ''; loading = true; wiredGroups; actions = []; actionLoadError;
    history = []; samples = []; showPreview = false; selectedGroup; selectedAction = '';
    preview; previewRunning = false; previewError; simulateRunning = false; statusMessage;
    statusOptions = [{label:'All',value:''},{label:'New',value:'New'},{label:'Acknowledged',value:'Acknowledged'},{label:'Investigating',value:'Investigating'},{label:'Resolved',value:'Resolved'},{label:'Ignored',value:'Ignored'}];

    @wire(failureGroups, { limitSize: 50, status: '$status' }) wired(result) { this.wiredGroups = result; this.loading = false; if (result.data) this.groups = result.data; }
    @wire(groupHistory, { groupId: '$selectedGroup' }) wiredHistory({data}) { if (data) this.history = data; }
    @wire(groupSamples, { groupId: '$selectedGroup' }) wiredSamples({data}) { if (data) this.samples = data; }
    @wire(activeActions) wiredActions({data,error}) { if (data) { this.actions = data; this.actionLoadError = undefined; } if (error) this.actionLoadError = this.message(error); }

    get actionOptions() { return this.actions.map(a => ({label:a.Label__c || a.Action_Key__c, value:a.Id})); }
    get previewDisabled() { return !this.selectedAction || this.previewRunning || !!this.actionLoadError; }
    get simulateDisabled() { return !this.preview || this.simulateRunning || this.preview.job.Status__c !== 'Previewed'; }
    get selectedActionRecord() { return this.actions.find(a => a.Id === this.selectedAction); }
    get executeDisabled() { return !this.preview || this.simulateRunning || this.preview.job.Status__c !== 'Previewed' || this.selectedActionRecord?.Action_Key__c !== 'E2E_DEMO_ORDER_REPAIR'; }
    get totalOccurrences() { return this.groups.reduce((total, group) => total + (Number(group.Occurrence_Count__c) || 0), 0); }
    get newGroups() { return this.groups.filter(group => group.Status__c === 'New').length; }
    get investigatingGroups() { return this.groups.filter(group => group.Status__c === 'Investigating').length; }
    get hasSamples() { return this.samples.length > 0; }
    get hasHistory() { return this.history.length > 0; }
    message(error) { return error?.body?.message || error?.message || 'Unexpected Salesforce error.'; }
    changeStatus(event) { this.loading = true; this.status = event.detail.value; }
    refresh() { this.loading = true; refreshApex(this.wiredGroups).finally(() => { this.loading = false; }); }

    openPreview(event) { this.selectedGroup = event.currentTarget.dataset.id; this.showPreview = true; this.selectedAction = ''; this.preview = null; this.previewError = undefined; this.statusMessage = undefined; }
    closePreview() { this.showPreview = false; }
    selectAction(event) { this.selectedAction = event.detail.value; this.previewError = undefined; }

    async runPreview() {
        if (this.previewDisabled) return;
        this.previewRunning = true; this.previewError = undefined; this.preview = null;
        try { this.preview = await previewRecovery({failureGroupId:this.selectedGroup,recoveryActionId:this.selectedAction,errorIds:null,requestedLimit:50}); this.statusMessage = 'Preview created. No recovery action was executed.'; }
        catch (error) { this.previewError = this.message(error); }
        finally { this.previewRunning = false; }
    }

    async simulate() {
        if (this.simulateDisabled) return;
        this.simulateRunning = true; this.previewError = undefined;
        try { this.preview = await simulateRecovery({recoveryJobId:this.preview.job.Id}); this.statusMessage = 'Simulation completed. No record or Flow was changed.'; }
        catch (error) { this.previewError = this.message(error); }
        finally { this.simulateRunning = false; }
    }

    async executeDemo() {
        if (this.executeDisabled) return;
        this.simulateRunning = true; this.previewError = undefined;
        try { this.preview = await executeApprovedDemo({recoveryJobId:this.preview.job.Id}); this.statusMessage = 'Approved recovery Flow executed. Only the selected demo record was changed.'; }
        catch (error) { this.previewError = this.message(error); }
        finally { this.simulateRunning = false; }
    }

    async setGroupStatus(event) {
        const nextStatus = event.currentTarget.dataset.status; const sample = this.samples[0]; if (!sample) return;
        try { await updateStatus({errorId:sample.Id,status:nextStatus,notes:'Updated from Flow Failure Monitor demo workspace.'}); this.statusMessage = `Group marked ${nextStatus}.`; await refreshApex(this.wiredGroups); }
        catch (error) { this.previewError = this.message(error); }
    }
}
