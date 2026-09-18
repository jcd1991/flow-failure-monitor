public inherited sharing class FFM_FailureCaptureService {
    public static String clip(String value, Integer maxLength) {
        if (value == null) return null;
        Integer max = maxLength == null || maxLength < 1 ? 1 : maxLength;
        return value.length() > max ? value.substring(0, max) : value;
    }

    public static String redact(String value) {
        if (String.isBlank(value)) return value;
        String result = value;
        result = result.replaceAll('(?i)(authorization|session(?:id)?|password|client_secret|access_token)\\s*[:=]\\s*[^\\s,|]+', '$1=[REDACTED]');
        result = result.replaceAll('(?i)[\\w.+-]+@[\\w.-]+\\.[a-z]{2,}', '[EMAIL]');
        result = result.replaceAll('\\+?\\d[\\d ()-]{7,}\\d', '[PHONE]');
        return clip(result, 16000);
    }

    public static String safeContext(String value) {
        if (String.isBlank(value)) return null;
        String redacted = redact(value);
        try {
            Object parsed = JSON.deserializeUntyped(clip(redacted, 8000));
            if (!(parsed instanceof Map<String, Object>)) return '{"redacted":"context-must-be-an-object"}';
            Map<String, Object> source = (Map<String, Object>)parsed;
            Map<String, Object> safe = new Map<String, Object>();
            for (String key : source.keySet()) if (safeKey(key)) safe.put(key, clip(String.valueOf(source.get(key)), 500));
            return clip(JSON.serialize(safe), 8000);
        } catch (Exception ex) {
            return '{"redacted":"invalid-context"}';
        }
    }

    private static Boolean safeKey(String key) {
        if (String.isBlank(key) || key.length() > 60) return false;
        return !Pattern.matches('(?i).*(password|secret|token|authorization|session|cookie|ssn|credit).*', key);
    }

    public static String safeId(String value) {
        if (String.isBlank(value)) return null;
        String candidate = value.trim();
        return Pattern.matches('^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$', candidate) ? candidate : null;
    }

    public static String fingerprint(String flowName, String elementName, String errorType, String objectType, String message) {
        String normalized = String.join(new List<String>{
            String.valueOf(flowName).trim().toLowerCase(),
            String.valueOf(elementName).trim().toLowerCase(),
            String.valueOf(errorType).trim().toLowerCase(),
            String.valueOf(objectType).trim().toLowerCase(),
            redact(message).replaceAll('\\d+', '#').replaceAll('\\s+', ' ').trim().toLowerCase()
        }, '|');
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(normalized)));
    }
}
