public with sharing class FFM_DemoFailureAction {
    @InvocableMethod(label='FFM Demo: intentionally fail' description='Portfolio-only action that throws a controlled failure so the fault connector can be demonstrated.')
    public static void fail(List<String> inputs) {
        throw new DemoFailureException('Demo order validation failed: missing fulfillment address.');
    }

    public class DemoFailureException extends Exception {}
}
