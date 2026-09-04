package dev.beautifulai.androidcandidateprobe;

import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.Instrumentation;
import android.app.UiAutomation;
import android.content.ComponentName;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;
import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/** Independent instrumentation: observes existing windows and permits one candidate touch. */
public final class ProbeInstrumentation extends Instrumentation {
    private static final String TAG = "AndroidCandidateProbe";
    private static final String APP = "dev.beautifulai.beautiful_ai_ui_catalog";
    private static final long LIFETIME_MS = 600000;
    private static final long TICKET_MS = 2000;
    private static final int MAX_NODES = 4096;
    private static final int MAX_DEPTH = 32;
    private static final int MAX_WINDOWS = 64;
    private static final int MAX_REQUESTS = 16;
    private final AtomicBoolean finished = new AtomicBoolean();
    private final SecureRandom random = new SecureRandom();
    private volatile boolean running = true;
    private volatile ServerSocket server;
    private volatile Socket activeSocket;
    private volatile JSONObject lastDiagnostics = new JSONObject();
    private volatile String nonce;
    private volatile String stageNonce;
    private StageSpec stageSpec;
    private UiAutomation automation;
    private FileOutputStream eventLog;
    private String eventLogName;
    private long lifetimeDeadline;
    private boolean inspected;
    private boolean tapAttempted;
    private Ticket ticket;

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        String requestedNonce = arguments == null ? null : arguments.getString("nonce");
        String requestedStageNonce = arguments == null ? null : arguments.getString("stage_nonce");
        String requestedStage = arguments == null ? null : arguments.getString("stage_id");
        String sha = arguments == null ? null : arguments.getString("source_sha");
        if (!StageSpec.validIdentity(requestedNonce, requestedStageNonce, sha)
                || !BuildIdentity.SOURCE_SHA.equals(sha)) {
            finishProbe(1, "invalid_arguments", "Expected distinct run/stage nonces and matching compiled source SHA");
            return;
        }
        try { stageSpec = StageSpec.require(requestedStage); }
        catch (IllegalArgumentException error) {
            finishProbe(1, "invalid_stage", "An exact compiled candidate stage is required");
            return;
        }
        nonce = requestedNonce;
        stageNonce = requestedStageNonce;
        eventLogName = "probe-events-" + stageSpec.id + "-" + stageNonce + ".jsonl";
        start();
    }

    @Override public void onStart() {
        lifetimeDeadline = now() + LIFETIME_MS;
        Thread watchdog = new Thread(new Runnable() {
            @Override public void run() {
                while (running && now() < lifetimeDeadline) {
                    SystemClock.sleep(Math.max(1, Math.min(1000, lifetimeDeadline - now())));
                }
                if (running) finishProbe(1, "lifetime_expired", "Probe exceeded its 600 second lifetime");
            }
        }, "candidate-probe-deadline");
        watchdog.setDaemon(true);
        watchdog.start();
        try {
            eventLog = getContext().openFileOutput(eventLogName, android.content.Context.MODE_PRIVATE);
            automation = getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES);
            AccessibilityServiceInfo info = automation.getServiceInfo();
            if (info == null) throw failure("accessibility_unavailable", "No automation service information");
            info.flags |= AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                    | AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS;
            automation.setServiceInfo(info);
            server = new ServerSocket(0, 4, InetAddress.getByName("127.0.0.1"));
            server.setSoTimeout(1000);
            Bundle ready = new Bundle();
            ready.putBoolean("ready", true);
            ready.putInt("port", server.getLocalPort());
            ready.putInt("pid", android.os.Process.myPid());
            ready.putString("nonce", nonce);
            ready.putString("run_nonce", nonce);
            ready.putString("stage_nonce", stageNonce);
            ready.putString("stage_id", stageSpec.id);
            ready.putString("expected_text", stageSpec.expectedText);
            ready.putString("candidate_text", stageSpec.candidateText);
            ready.putInt("composing_base", stageSpec.composingBase);
            ready.putInt("composing_extent", stageSpec.composingExtent);
            ready.putInt("selection_offset", stageSpec.selectionOffset);
            ready.putInt("protocol_version", 2);
            ready.putString("source_sha", BuildIdentity.SOURCE_SHA);
            ready.putLong("device_elapsed_ms", now());
            ready.putString("event_log", "files/" + eventLogName);
            sendStatus(100, ready);
            int requests = 0;
            while (running && now() < lifetimeDeadline) {
                try {
                    Socket socket = server.accept();
                    activeSocket = socket;
                    try {
                        socket.setSoTimeout(1000);
                        if (!socket.getInetAddress().isLoopbackAddress()) {
                            throw failure("non_loopback_peer", "Only loopback clients are accepted");
                        }
                        serve(socket);
                        if (++requests >= MAX_REQUESTS && running) {
                            finishProbe(1, "request_limit", "Probe request limit reached");
                        }
                    } finally {
                        try { socket.close(); } catch (IOException ignored) { }
                        activeSocket = null;
                    }
                } catch (SocketTimeoutException ignored) {
                    // Only the accept wait is repeated; actions are never retried.
                }
            }
            finishProbe(0, "stopped", "Probe stopped");
        } catch (Exception error) {
            finishProbe(1, "probe_failed", safeMessage(error));
        }
    }

    private void serve(Socket socket) throws IOException {
        String operation = "unknown";
        JSONObject response;
        int status = 200;
        boolean stop = false;
        try {
            Protocol.Request request = Protocol.read(socket.getInputStream());
            operation = request.path.substring(1);
            Map<String, String> body = Protocol.fields(request.body);
            authenticate(body);
            Protocol.validateRequestFields(body, operation.equals("tap"));
            if (now() >= lifetimeDeadline) throw failure("lifetime_expired", "Probe deadline reached");
            if (operation.equals("inspect")) {
                response = inspect();
            } else if (operation.equals("tap")) {
                Object id = body.get("candidate_id");
                if (!(id instanceof String) || !((String) id).matches("[a-f0-9]{32}")) {
                    throw failure("invalid_candidate_id", "Expected a candidate ticket identifier");
                }
                response = tap((String) id);
            } else {
                response = base("stop", true);
                stop = true;
            }
        } catch (Exception error) {
            status = error instanceof Protocol.Error ? ((Protocol.Error) error).status : 409;
            String code = error instanceof Protocol.Error ? ((Protocol.Error) error).code : "request_failed";
            response = base(operation, false);
            put(response, "error", object("code", code, "message", safeMessage(error)));
            put(response, "diagnostics", lastDiagnostics);
        }
        record(response);
        byte[] bytes = response.toString().getBytes(StandardCharsets.UTF_8);
        OutputStream output = socket.getOutputStream();
        String header = "HTTP/1.1 " + status + (status == 200 ? " OK" : " Error")
                + "\r\nContent-Type: application/json\r\nContent-Length: " + bytes.length
                + "\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n";
        output.write(header.getBytes(StandardCharsets.US_ASCII));
        output.write(bytes);
        output.flush();
        if (stop) running = false;
    }

    private void authenticate(Map<String, String> body) throws Protocol.Error {
        if (!stageSpec.matchesIdentity(body, nonce, stageNonce, BuildIdentity.SOURCE_SHA)) {
            throw new Protocol.Error(403, "stage_identity_mismatch", "Run, stage, or source identity does not match this helper");
        }
    }

    private JSONObject inspect() throws Exception {
        if (inspected) throw failure("inspect_already_used", "Only one inspection ticket is permitted");
        inspected = true;
        long started = now();
        Snapshot snapshot = scan();
        long expires = Math.min(started + TICKET_MS, lifetimeDeadline);
        if (expires - now() < 150) throw failure("inspection_expired", "Inspection exhausted its ticket deadline");
        ticket = new Ticket(randomId(), snapshot, expires, stageSpec, nonce, stageNonce);
        JSONObject response = base("inspect", true);
        copySnapshot(response, snapshot);
        put(response, "candidate_id", ticket.id);
        put(response, "inspect_started_device_ms", started);
        put(response, "expires_at_device_ms", expires);
        return response;
    }

    private JSONObject tap(String id) throws Exception {
        if (tapAttempted) throw failure("tap_already_attempted", "Only one tap attempt is permitted");
        tapAttempted = true;
        Ticket current = ticket;
        if (current == null || !current.id.equals(id)) throw failure("ticket_mismatch", "No matching inspection ticket");
        if (current.spec != stageSpec || !current.runNonce.equals(nonce)
                || !current.stageNonce.equals(stageNonce) || !current.sourceSha.equals(BuildIdentity.SOURCE_SHA)) {
            throw failure("ticket_identity_mismatch", "The ticket does not belong to this exact run, stage, and source");
        }
        JSONObject action = new JSONObject();
        putIdentity(action);
        put(action, "used_candidate_id", id);
        put(action, "expires_at_device_ms", current.expires);
        put(action, "injected_down", false);
        put(action, "injected_up", false);
        put(action, "cancelled", false);
        lastDiagnostics = object("action", action, "inspection", lastDiagnostics);
        if (current.expires - now() < 150) throw failure("ticket_expired", "Ticket has less than 150 ms remaining");
        Snapshot fresh = scan();
        lastDiagnostics = object("action", action, "fresh_inspection", fresh.details);
        boolean candidateMatches = current.snapshot.imeComponent.equals(fresh.imeComponent)
                && current.snapshot.imeWindowId == fresh.imeWindowId
                && current.snapshot.bounds.equals(fresh.bounds);
        if (current.expires - now() < 150) throw failure("ticket_expired", "Fresh inspection exhausted the ticket deadline");
        Rect rect = fresh.bounds;
        float x = rect.left + rect.width() / 2.0f;
        float y = rect.top + rect.height() / 2.0f;
        long downTime = SystemClock.uptimeMillis();
        boolean completed = false;
        try {
            boolean down = injectBeforeDeadline(MotionEvent.ACTION_DOWN, downTime, x, y,
                    current.guard, candidateMatches, action, "down_device_elapsed_ms");
            put(action, "injected_down", down);
            if (!down) throw failure("down_rejected", "Android rejected the DOWN event");
            long upNotBefore = action.optLong("down_device_elapsed_ms") + 50;
            while (running) {
                long remaining = Math.min(upNotBefore, current.expires) - now();
                if (remaining <= 0) break;
                SystemClock.sleep(remaining);
            }
            if (!running) throw failure("probe_stopped", "Probe stopped during touch; CANCEL required");
            boolean up = injectBeforeDeadline(MotionEvent.ACTION_UP, downTime, x, y,
                    current.guard, candidateMatches, action, "up_device_elapsed_ms");
            put(action, "injected_up", up);
            if (!up) throw failure("up_rejected", "Android rejected the UP event");
            completed = true;
        } finally {
            if (action.optBoolean("down_dispatch_attempted") && !completed) cancel(action, downTime, x, y);
        }
        JSONObject response = base("tap", true);
        copySnapshot(response, fresh);
        Iterator<String> keys = action.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            put(response, key, action.get(key));
        }
        return response;
    }

    private boolean inject(int action, long downTime, float x, float y) {
        MotionEvent event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, x, y, 0);
        event.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        try { return automation.injectInputEvent(event, true); }
        finally { event.recycle(); }
    }

    private boolean injectBeforeDeadline(int type, long downTime, float x, float y,
            Protocol.GestureGate gate, boolean candidateMatches, JSONObject action, String timestampKey) throws Protocol.Error {
        MotionEvent event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), type, x, y, 0);
        event.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        try {
            long timestamp = now();
            Protocol.GestureGate.Decision decision = type == MotionEvent.ACTION_DOWN
                    ? gate.beforeDown(timestamp, lifetimeDeadline, running, candidateMatches)
                    : gate.beforeUp(timestamp, lifetimeDeadline, running);
            if (decision != Protocol.GestureGate.Decision.DOWN && decision != Protocol.GestureGate.Decision.UP) {
                put(action, "gate_decision", decision.toString());
                throw failure(!candidateMatches ? "candidate_changed"
                        : type == MotionEvent.ACTION_UP ? "expired_before_up" : "expired_before_down",
                        "Gesture gate rejected the event before dispatch");
            }
            put(action, timestampKey, timestamp);
            if (type == MotionEvent.ACTION_DOWN) {
                ticket = null; // The shared production gate consumed it before this first event.
                put(action, "down_dispatch_attempted", true);
            }
            try { return automation.injectInputEvent(event, true); }
            finally { put(action, type == MotionEvent.ACTION_DOWN
                    ? "down_injection_returned_device_elapsed_ms" : "up_injection_returned_device_elapsed_ms", now()); }
        } finally { event.recycle(); }
    }

    private void cancel(JSONObject action, long downTime, float x, float y) {
        put(action, "cancel_device_elapsed_ms", now());
        try { put(action, "cancelled", inject(MotionEvent.ACTION_CANCEL, downTime, x, y)); }
        catch (Exception error) { put(action, "cancel_error", safeMessage(error)); }
        finally { put(action, "cancel_injection_returned_device_elapsed_ms", now()); }
    }

    private Snapshot scan() throws Exception {
        JSONObject details = object("scan_started_device_ms", now());
        JSONArray windowsJson = new JSONArray();
        JSONArray nodesJson = new JSONArray();
        put(details, "windows", windowsJson);
        put(details, "nodes", nodesJson);
        lastDiagnostics = details;
        if (!automation.clearCache()) throw failure("accessibility_cache_clear_failed", "Could not request a fresh accessibility window tree");
        String component = Settings.Secure.getString(getContext().getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
        ComponentName name = component == null ? null : ComponentName.unflattenFromString(component);
        if (name == null) throw failure("ime_unavailable", "Default input method is not a valid component");
        String imePackage = name.getPackageName();
        put(details, "ime_component", component);
        put(details, "ime_package", imePackage);
        List<AccessibilityWindowInfo> windows = automation.getWindows();
        if (windows == null || windows.size() > MAX_WINDOWS) throw failure("window_limit", "Invalid or excessive window count");
        AccessibilityNodeInfo imeRoot = null;
        Rect imeBounds = null;
        int imeWindowId = -1;
        int imeLayer = -1;
        int imeCount = 0;
        int focusedCount = 0;
        String focusedPackage = null;
        List<AccessibilityNodeInfo> owned = new ArrayList<>();
        try {
            for (AccessibilityWindowInfo window : windows) {
                AccessibilityNodeInfo root = window.getRoot();
                if (root != null) owned.add(root);
                Rect bounds = new Rect();
                window.getBoundsInScreen(bounds);
                String pkg = root == null ? null : string(root.getPackageName());
                windowsJson.put(object("id", window.getId(), "type", window.getType(), "layer", window.getLayer(),
                        "focused", window.isFocused(), "active", window.isActive(),
                        "package", pkg, "root_visible", root != null && root.isVisibleToUser(),
                        "bounds", boundsJson(bounds)));
                if (window.getType() == AccessibilityWindowInfo.TYPE_APPLICATION && window.isFocused()) {
                    focusedCount++;
                    focusedPackage = pkg;
                }
                if (window.getType() == AccessibilityWindowInfo.TYPE_INPUT_METHOD) {
                    imeCount++;
                    imeRoot = root;
                    imeBounds = bounds;
                    imeWindowId = window.getId();
                    imeLayer = window.getLayer();
                }
            }
            put(details, "focused_app_package", focusedPackage);
            if (focusedCount != 1 || !APP.equals(focusedPackage)) {
                throw failure("unexpected_focused_app", "Exactly one focused catalog application window is required");
            }
            if (imeCount != 1 || imeRoot == null || !imeRoot.isVisibleToUser()
                    || !imePackage.equals(string(imeRoot.getPackageName())) || imeBounds.isEmpty()) {
                throw failure("unexpected_ime_window", "Exactly one visible window for the selected IME is required");
            }
            if (!imeRoot.refresh()) throw failure("stale_ime_root", "IME root could not be refreshed");
            if (!imeRoot.isVisibleToUser() || !imePackage.equals(string(imeRoot.getPackageName()))) {
                throw failure("ime_root_changed", "IME root changed during refresh");
            }
            ArrayDeque<NodeAtDepth> queue = new ArrayDeque<>();
            queue.add(new NodeAtDepth(imeRoot, 0));
            int seen = 0;
            List<Rect> matches = new ArrayList<>();
            while (!queue.isEmpty()) {
                NodeAtDepth item = queue.removeFirst();
                AccessibilityNodeInfo node = item.node;
                if (++seen > MAX_NODES) throw failure("node_limit", "IME tree exceeds node limit");
                Rect bounds = new Rect();
                node.getBoundsInScreen(bounds);
                String text = string(node.getText());
                String description = string(node.getContentDescription());
                nodesJson.put(object("index", seen - 1, "depth", item.depth,
                        "package", clipped(string(node.getPackageName())),
                        "view_id", clipped(node.getViewIdResourceName()), "class", clipped(string(node.getClassName())),
                        "text", clipped(text), "description", clipped(description),
                        "visible", node.isVisibleToUser(), "enabled", node.isEnabled(),
                        "clickable", node.isClickable(), "bounds", boundsJson(bounds)));
                if ((stageSpec.candidateText.equals(text) || stageSpec.candidateText.equals(description))
                        && node.isVisibleToUser() && node.isEnabled()
                        && imePackage.equals(string(node.getPackageName()))) {
                    Rect target = clickableBounds(node, imePackage, imeWindowId, owned);
                    if (target != null && !target.isEmpty() && imeBounds.contains(target)) matches.add(target);
                }
                int children = node.getChildCount();
                if (children > 0 && item.depth >= MAX_DEPTH) throw failure("depth_limit", "IME tree exceeds depth limit");
                if (children > MAX_NODES - seen - queue.size()) throw failure("node_limit", "IME tree exceeds node limit");
                for (int i = 0; i < children; i++) {
                    AccessibilityNodeInfo child = node.getChild(i);
                    if (child != null) {
                        owned.add(child);
                        queue.addLast(new NodeAtDepth(child, item.depth + 1));
                    }
                }
            }
            put(details, "matching_candidates", matches.size());
            put(details, "scan_finished_device_ms", now());
            if (matches.size() != 1) throw failure("candidate_not_unique",
                    "Expected exactly one visible enabled " + stageSpec.candidateText + " candidate for " + stageSpec.id);
            String latest = Settings.Secure.getString(getContext().getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
            if (!component.equals(latest)) throw failure("ime_changed_during_scan", "Default input method changed during inspection");
            Rect bounds = matches.get(0);
            for (AccessibilityWindowInfo window : windows) {
                if (window.getId() != imeWindowId && window.getLayer() > imeLayer) {
                    Rect otherBounds = new Rect();
                    window.getBoundsInScreen(otherBounds);
                    if (Rect.intersects(bounds, otherBounds)) {
                        throw failure("candidate_obscured", "Another window overlaps the candidate above the IME");
                    }
                }
            }
            put(details, "bounds", boundsJson(bounds));
            return new Snapshot(component, imePackage, imeWindowId, bounds, details);
        } finally {
            for (AccessibilityNodeInfo node : owned) node.recycle();
            for (AccessibilityWindowInfo window : windows) window.recycle();
        }
    }

    private static Rect clickableBounds(AccessibilityNodeInfo match, String imePackage, int windowId,
            List<AccessibilityNodeInfo> owned) throws Protocol.Error {
        AccessibilityNodeInfo cursor = match;
        for (int depth = 0; depth <= MAX_DEPTH && cursor != null; depth++) {
            if (cursor.getWindowId() != windowId || !imePackage.equals(string(cursor.getPackageName()))) return null;
            if (cursor.isVisibleToUser() && cursor.isEnabled() && cursor.isClickable()) {
                Rect rect = new Rect();
                cursor.getBoundsInScreen(rect);
                return rect;
            }
            cursor = cursor.getParent();
            if (cursor != null) owned.add(cursor);
        }
        return null;
    }

    private static void copySnapshot(JSONObject result, Snapshot snapshot) {
        put(result, "ime_component", snapshot.imeComponent);
        put(result, "ime_package", snapshot.imePackage);
        put(result, "ime_window_id", snapshot.imeWindowId);
        put(result, "focused_app_package", APP);
        put(result, "bounds", boundsJson(snapshot.bounds));
        put(result, "nodes", snapshot.details.optJSONArray("nodes"));
        put(result, "windows", snapshot.details.optJSONArray("windows"));
    }

    private JSONObject base(String operation, boolean ok) {
        JSONObject result = object("ok", ok, "operation", operation, "protocol_version", 2,
                "device_elapsed_ms", now());
        putIdentity(result);
        return result;
    }

    private void putIdentity(JSONObject result) {
        put(result, "source_sha", BuildIdentity.SOURCE_SHA);
        put(result, "nonce", nonce);
        put(result, "run_nonce", nonce);
        put(result, "stage_nonce", stageNonce);
        put(result, "stage_id", stageSpec == null ? null : stageSpec.id);
        if (stageSpec != null) {
            put(result, "expected_text", stageSpec.expectedText);
            put(result, "candidate_text", stageSpec.candidateText);
            put(result, "composing_base", stageSpec.composingBase);
            put(result, "composing_extent", stageSpec.composingExtent);
            put(result, "selection_offset", stageSpec.selectionOffset);
        }
    }

    private void finishProbe(int code, String reason, String message) {
        if (!finished.compareAndSet(false, true)) return;
        running = false;
        try { if (server != null) server.close(); } catch (IOException ignored) { }
        try { if (activeSocket != null) activeSocket.close(); } catch (IOException ignored) { }
        JSONObject result = base("finish", code == 0);
        put(result, "reason", reason);
        put(result, "message", message);
        put(result, "diagnostics", lastDiagnostics);
        record(result);
        Bundle bundle = new Bundle();
        JSONObject summary = base("finish", code == 0);
        put(summary, "reason", reason);
        put(summary, "message", message);
        put(summary, "event_log", eventLogName == null ? null : "files/" + eventLogName);
        bundle.putString("result_json", summary.toString());
        synchronized (this) {
            try { if (eventLog != null) eventLog.close(); } catch (IOException ignored) { }
            eventLog = null;
        }
        finish(code, bundle);
    }

    private synchronized void record(JSONObject event) {
        Log.i(TAG, event.toString());
        if (eventLog != null) {
            try {
                eventLog.write((event.toString() + "\n").getBytes(StandardCharsets.UTF_8));
                eventLog.flush();
            } catch (IOException error) {
                Log.e(TAG, "Could not preserve event JSON: " + safeMessage(error));
            }
        }
    }

    private String randomId() {
        byte[] bytes = new byte[16];
        random.nextBytes(bytes);
        StringBuilder value = new StringBuilder(32);
        for (byte b : bytes) value.append(String.format(java.util.Locale.ROOT, "%02x", b & 0xff));
        return value.toString();
    }

    private static long now() { return SystemClock.elapsedRealtime(); }
    private static String string(CharSequence value) { return value == null ? null : value.toString(); }
    private static String clipped(String value) { return value == null || value.length() <= 256 ? value : value.substring(0, 256); }
    private static String safeMessage(Exception error) { return error.getClass().getSimpleName() + ": " + clipped(error.getMessage()); }
    private static Protocol.Error failure(String code, String message) { return new Protocol.Error(409, code, message); }
    private static JSONObject boundsJson(Rect rect) { return object("left", rect.left, "top", rect.top, "right", rect.right, "bottom", rect.bottom); }
    private static JSONObject object(Object... values) {
        JSONObject result = new JSONObject();
        for (int i = 0; i < values.length; i += 2) put(result, (String) values[i], values[i + 1]);
        return result;
    }
    private static void put(JSONObject object, String key, Object value) {
        try { object.put(key, value == null ? JSONObject.NULL : value); }
        catch (org.json.JSONException impossible) { throw new IllegalStateException(impossible); }
    }

    private static final class NodeAtDepth {
        final AccessibilityNodeInfo node;
        final int depth;
        NodeAtDepth(AccessibilityNodeInfo node, int depth) { this.node = node; this.depth = depth; }
    }
    private static final class Snapshot {
        final String imeComponent;
        final String imePackage;
        final int imeWindowId;
        final Rect bounds;
        final JSONObject details;
        Snapshot(String component, String pkg, int windowId, Rect bounds, JSONObject details) {
            this.imeComponent = component; this.imePackage = pkg; this.imeWindowId = windowId;
            this.bounds = new Rect(bounds); this.details = details;
        }
    }
    private static final class Ticket {
        final String id;
        final Snapshot snapshot;
        final long expires;
        final Protocol.GestureGate guard;
        final StageSpec spec;
        final String runNonce;
        final String stageNonce;
        final String sourceSha = BuildIdentity.SOURCE_SHA;
        Ticket(String id, Snapshot snapshot, long expires, StageSpec spec, String runNonce, String stageNonce) {
            this.id = id; this.snapshot = snapshot; this.expires = expires;
            this.guard = new Protocol.GestureGate(expires);
            this.spec = spec; this.runNonce = runNonce; this.stageNonce = stageNonce;
        }
    }
}
