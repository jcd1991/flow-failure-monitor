trigger FFM_FailureCapture on FFM_Failure_Capture__e (after insert) {
    FFM_FailureCaptureHandler.handle(Trigger.New);
}
