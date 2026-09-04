package dev.beautifulai.androidcandidateprobe;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;

/** Runs against the actual request parser without an emulator or Android classes. */
public final class ProtocolTest {
    private static int checks;

    public static void main(String[] args) throws Exception {
        String valid = "POST /inspect HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}";
        Protocol.Request request = parse(valid);
        if (!request.path.equals("/inspect") || !request.body.equals("{}")) {
            throw new AssertionError("Valid request did not round-trip");
        }
        checks++;
        if (!"aabb".equals(Protocol.fields(" { \"nonce\" : \"aabb\", \"candidate_id\":\"ccdd\" } ").get("nonce"))) {
            throw new AssertionError("Strict JSON fields did not round-trip");
        }
        checks++;
        rejectJson("{\"nonce\":\"a\",\"nonce\":\"b\"}", "duplicate_json_key");
        rejectJson("{nonce:'a'}", "invalid_json");
        rejectJson("{\"nonce\":\"a\"}" + '\0' + "garbage", "invalid_json");
        rejectJson("{\"nonce\":\"a\",}", "invalid_json");
        rejectJson("{\"nonce\":123}", "invalid_json");
        rejectJson("{/*comment*/\"nonce\":\"a\"}", "invalid_json");
        rejectJson("{\"nonce\":\"a\",\"candidate_id\":\"b\",\"extra\":\"c\"}", "too_many_json_fields");
        gestureDecisions();
        reject(valid.replace("Content-Length: 2", "Content-Length: 2\r\ncontent-length: 2"), "duplicate_header");
        reject(valid.replace("Content-Length: 2", "Transfer-Encoding: chunked\r\nContent-Length: 2"), "unsupported_encoding");
        reject(valid.replace("Content-Length: 2", "Content-Length: 4097"), "body_too_large");
        reject(valid.replace("Content-Length: 2", "Content-Length: 0002"), "invalid_content_length");
        reject(valid.substring(0, valid.length() - 1), "truncated_body");
        reject(valid.replace("POST /inspect", "GET /inspect"), "invalid_request_line");
        reject(valid.replace("/inspect", "/inspect?nonce=x"), "unknown_path");
        reject(valid.replace("\r\n", "\n"), "invalid_header_character");
        reject(valid.replace("Content-Type: application/json", "Content-Type: text/plain"), "invalid_content_type");
        reject(valid.replace("Content-Type:", " Content-Type:"), "invalid_header");
        String huge = new String(new char[2049]).replace('\0', 'a');
        reject(valid.replace("Content-Type:", "X-Long: " + huge + "\r\nContent-Type:"), "line_too_large");
        byte[] badUtf8 = valid.getBytes(StandardCharsets.UTF_8);
        badUtf8[badUtf8.length - 1] = (byte) 0xff;
        try {
            Protocol.read(new ByteArrayInputStream(badUtf8));
            throw new AssertionError("Invalid UTF-8 accepted");
        } catch (Protocol.Error expected) {
            if (!expected.code.equals("invalid_utf8")) throw expected;
            checks++;
        }
        System.out.println("ProtocolTest passed " + checks + " checks");
    }

    private static Protocol.Request parse(String raw) throws Exception {
        return Protocol.read(new ByteArrayInputStream(raw.getBytes(StandardCharsets.UTF_8)));
    }

    private static void reject(String raw, String code) throws Exception {
        try {
            parse(raw);
            throw new AssertionError("Expected rejection: " + code);
        } catch (Protocol.Error error) {
            if (!error.code.equals(code)) {
                throw new AssertionError("Expected " + code + " but got " + error.code);
            }
            checks++;
        }
    }

    private static void rejectJson(String raw, String code) throws Exception {
        try {
            Protocol.fields(raw);
            throw new AssertionError("Expected JSON rejection: " + code);
        } catch (Protocol.Error error) {
            if (!error.code.equals(code)) throw new AssertionError("Expected " + code + " but got " + error.code);
            checks++;
        }
    }

    private static void gestureDecisions() {
        Protocol.GestureGate expired = new Protocol.GestureGate(2000);
        decision(expired.beforeDown(2000, 600000, true, true), "REJECT");
        if (expired.consumed()) throw new AssertionError("Expired ticket was consumed");
        decision(expired.beforeUp(2001, 600000, true), "REJECT");

        Protocol.GestureGate insufficient = new Protocol.GestureGate(2000);
        decision(insufficient.beforeDown(1851, 600000, true, true), "REJECT");
        Protocol.GestureGate mismatch = new Protocol.GestureGate(2000);
        decision(mismatch.beforeDown(100, 600000, true, false), "REJECT");
        decision(mismatch.beforeDown(101, 600000, true, true), "REJECT");

        Protocol.GestureGate normal = new Protocol.GestureGate(2000);
        decision(normal.beforeDown(100, 600000, true, true), "DOWN");
        if (!normal.consumed()) throw new AssertionError("DOWN did not consume ticket");
        decision(normal.beforeDown(101, 600000, true, true), "REJECT");
        decision(normal.beforeUp(150, 600000, true), "UP");
        decision(normal.beforeUp(151, 600000, true), "REJECT");

        Protocol.GestureGate lateUp = new Protocol.GestureGate(2000);
        decision(lateUp.beforeDown(1850, 600000, true, true), "DOWN");
        decision(lateUp.beforeUp(2000, 600000, true), "CANCEL");
        decision(lateUp.beforeUp(2001, 600000, true), "REJECT");
        Protocol.GestureGate lifetime = new Protocol.GestureGate(2000);
        decision(lifetime.beforeDown(900, 1000, true, true), "REJECT");
        Protocol.GestureGate stopped = new Protocol.GestureGate(2000);
        decision(stopped.beforeDown(100, 600000, true, true), "DOWN");
        decision(stopped.beforeUp(150, 600000, false), "CANCEL");
    }

    private static void decision(Protocol.GestureGate.Decision actual, String expected) {
        if (!actual.toString().equals(expected)) throw new AssertionError("Expected " + expected + " but got " + actual);
        checks++;
    }
}
