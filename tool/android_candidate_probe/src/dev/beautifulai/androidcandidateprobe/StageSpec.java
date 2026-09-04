package dev.beautifulai.androidcandidateprobe;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

/** Fixed diagnostic stages; callers cannot supply drafts, candidates, or ranges. */
final class StageSpec {
    final String id;
    final String expectedText;
    final String candidateText;
    final int composingBase;
    final int composingExtent;
    final int selectionOffset;

    private StageSpec(String id, String text, String candidate, int base, int extent, int selection) {
        if (base < 0 || base >= extent || extent > text.length()
                || selection != text.length() || !text.substring(base, extent).equals(candidate)) {
            throw new IllegalArgumentException("Invalid compiled stage specification");
        }
        this.id = id;
        this.expectedText = text;
        this.candidateText = candidate;
        this.composingBase = base;
        this.composingExtent = extent;
        this.selectionOffset = selection;
    }

    static StageSpec require(String id) {
        if ("chat_send".equals(id)) return new StageSpec(id, "Check cone inventory", "inventory", 11, 20, 20);
        if ("prompt_command".equals(id)) return new StageSpec(id, "/rest", "rest", 1, 5, 5);
        if ("prompt_send".equals(id)) return new StageSpec(id, "Prepare the seasonal restock", "restock", 21, 28, 28);
        throw new IllegalArgumentException("Unknown fixed candidate stage");
    }

    static boolean validIdentity(String runNonce, String stageNonce, String sourceSha) {
        return runNonce != null && runNonce.matches("[a-f0-9]{32,64}")
                && stageNonce != null && stageNonce.matches("[a-f0-9]{32,64}")
                && !runNonce.equals(stageNonce)
                && sourceSha != null && sourceSha.matches("[a-f0-9]{40}");
    }

    boolean matchesIdentity(Map<String, String> request, String runNonce, String stageNonce, String sourceSha) {
        String run = request.get("nonce"), stage = request.get("stage_nonce"), sha = request.get("source_sha");
        return validIdentity(run, stage, sha) && id.equals(request.get("stage_id"))
                && sourceSha.equals(sha)
                && MessageDigest.isEqual(runNonce.getBytes(StandardCharsets.US_ASCII), run.getBytes(StandardCharsets.US_ASCII))
                && MessageDigest.isEqual(stageNonce.getBytes(StandardCharsets.US_ASCII), stage.getBytes(StandardCharsets.US_ASCII));
    }
}
