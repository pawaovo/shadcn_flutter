package dev.beautifulai.androidcandidateprobe;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/** Bounded, single-request HTTP framing; deliberately independent of Android. */
final class Protocol {
    static final int MAX_HEADER_BYTES = 8192;
    static final int MAX_BODY_BYTES = 4096;
    static final int MAX_LINE_BYTES = 2048;
    static final int MAX_HEADERS = 32;

    static final class Error extends IOException {
        final int status;
        final String code;

        Error(int status, String code, String message) {
            super(message);
            this.status = status;
            this.code = code;
        }
    }

    static final class Request {
        final String path;
        final String body;

        Request(String path, String body) {
            this.path = path;
            this.body = body;
        }
    }

    /** Production gesture decisions use caller-supplied monotonic times for deterministic tests. */
    static final class GestureGate {
        enum Decision { DOWN, UP, CANCEL, REJECT }
        final long expiresAt;
        private boolean downAttempted;
        private boolean consumed;
        private boolean upAttempted;

        GestureGate(long expiresAt) { this.expiresAt = expiresAt; }

        Decision beforeDown(long now, long lifetimeDeadline, boolean running, boolean candidateMatches) {
            if (downAttempted) return Decision.REJECT;
            downAttempted = true;
            if (!running || !candidateMatches || Math.min(expiresAt, lifetimeDeadline) - now < 150) {
                return Decision.REJECT;
            }
            consumed = true;
            return Decision.DOWN;
        }

        Decision beforeUp(long now, long lifetimeDeadline, boolean running) {
            if (!consumed || upAttempted) return Decision.REJECT;
            upAttempted = true;
            if (!running || now >= Math.min(expiresAt, lifetimeDeadline)) return Decision.CANCEL;
            return Decision.UP;
        }

        boolean consumed() { return consumed; }
    }

    static Request read(InputStream input) throws IOException {
        int[] consumed = {0};
        String first = line(input, consumed);
        String[] parts = first.split(" ", -1);
        if (parts.length != 3 || !parts[0].equals("POST") || !parts[2].equals("HTTP/1.1")) {
            throw new Error(400, "invalid_request_line", "Expected POST path HTTP/1.1");
        }
        if (!parts[1].equals("/inspect") && !parts[1].equals("/tap")
                && !parts[1].equals("/stop")) {
            throw new Error(404, "unknown_path", "Unknown endpoint");
        }
        Map<String, String> headers = new HashMap<>();
        for (int count = 0; ; count++) {
            String header = line(input, consumed);
            if (header.isEmpty()) break;
            if (count >= MAX_HEADERS) {
                throw new Error(431, "too_many_headers", "Too many headers");
            }
            int colon = header.indexOf(':');
            if (colon <= 0 || !header.substring(0, colon).matches("[A-Za-z0-9-]+")) {
                throw new Error(400, "invalid_header", "Invalid header name");
            }
            String name = header.substring(0, colon).toLowerCase(Locale.ROOT);
            String value = header.substring(colon + 1).trim();
            if (headers.put(name, value) != null) {
                throw new Error(400, "duplicate_header", "Duplicate header");
            }
        }
        if (headers.containsKey("transfer-encoding") || headers.containsKey("content-encoding")) {
            throw new Error(400, "unsupported_encoding", "Encoded request bodies are unsupported");
        }
        if (!"application/json".equals(headers.get("content-type"))) {
            throw new Error(415, "invalid_content_type", "Expected application/json");
        }
        String lengthValue = headers.get("content-length");
        if (lengthValue == null || !lengthValue.matches("[1-9][0-9]{0,4}")) {
            throw new Error(400, "invalid_content_length", "Expected a bounded Content-Length");
        }
        int length = Integer.parseInt(lengthValue);
        if (length > MAX_BODY_BYTES) {
            throw new Error(413, "body_too_large", "Request body exceeds limit");
        }
        byte[] bytes = new byte[length];
        int offset = 0;
        while (offset < length) {
            int read = input.read(bytes, offset, length - offset);
            if (read < 0) throw new Error(400, "truncated_body", "Body ended before Content-Length");
            if (read == 0) continue;
            offset += read;
        }
        String body = new String(bytes, StandardCharsets.UTF_8);
        if (!java.util.Arrays.equals(bytes, body.getBytes(StandardCharsets.UTF_8))) {
            throw new Error(400, "invalid_utf8", "Body must be valid UTF-8");
        }
        return new Request(parts[1], body);
    }

    /** This protocol accepts only a flat JSON object with unescaped ASCII string fields. */
    static Map<String, String> fields(String body) throws Error {
        int[] cursor = {0};
        Map<String, String> result = new HashMap<>();
        whitespace(body, cursor);
        expect(body, cursor, '{');
        whitespace(body, cursor);
        if (peek(body, cursor) != '}') {
            while (true) {
                String key = jsonString(body, cursor);
                whitespace(body, cursor);
                expect(body, cursor, ':');
                whitespace(body, cursor);
                String value = jsonString(body, cursor);
                if (result.put(key, value) != null) throw new Error(400, "duplicate_json_key", "Duplicate JSON field");
                if (result.size() > 2) throw new Error(400, "too_many_json_fields", "At most two fields are accepted");
                whitespace(body, cursor);
                if (peek(body, cursor) != ',') break;
                cursor[0]++;
                whitespace(body, cursor);
            }
        }
        expect(body, cursor, '}');
        whitespace(body, cursor);
        if (cursor[0] != body.length()) throw new Error(400, "invalid_json", "Trailing JSON data");
        return result;
    }

    private static String jsonString(String body, int[] cursor) throws Error {
        expect(body, cursor, '"');
        int start = cursor[0];
        while (cursor[0] < body.length()) {
            char value = body.charAt(cursor[0]++);
            if (value == '"') return body.substring(start, cursor[0] - 1);
            if (value < 32 || value > 126 || value == '\\') {
                throw new Error(400, "invalid_json", "Fields must contain unescaped printable ASCII");
            }
        }
        throw new Error(400, "invalid_json", "Unterminated JSON string");
    }

    private static char peek(String body, int[] cursor) { return cursor[0] < body.length() ? body.charAt(cursor[0]) : 0; }
    private static void expect(String body, int[] cursor, char expected) throws Error {
        if (cursor[0] >= body.length() || body.charAt(cursor[0]++) != expected) {
            throw new Error(400, "invalid_json", "Expected strict JSON object with string fields");
        }
    }
    private static void whitespace(String body, int[] cursor) {
        while (cursor[0] < body.length()) {
            char value = body.charAt(cursor[0]);
            if (value != ' ' && value != '\t' && value != '\r' && value != '\n') break;
            cursor[0]++;
        }
    }

    private static String line(InputStream input, int[] consumed) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        while (true) {
            int value = input.read();
            if (value < 0) throw new Error(400, "truncated_headers", "Headers ended early");
            if (++consumed[0] > MAX_HEADER_BYTES) {
                throw new Error(431, "headers_too_large", "Headers exceed limit");
            }
            if (value == '\r') {
                int next = input.read();
                if (++consumed[0] > MAX_HEADER_BYTES || next != '\n') {
                    throw new Error(400, "invalid_line_ending", "Expected CRLF");
                }
                return new String(bytes.toByteArray(), StandardCharsets.US_ASCII);
            }
            if (value < 32 || value > 126) {
                throw new Error(400, "invalid_header_character", "Headers must use printable ASCII");
            }
            if (bytes.size() >= MAX_LINE_BYTES) {
                throw new Error(431, "line_too_large", "Header line exceeds limit");
            }
            bytes.write(value);
        }
    }
}
