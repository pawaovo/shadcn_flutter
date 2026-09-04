package dev.beautifulai.androidcandidateprobe;

import java.util.HashMap;
import java.util.Map;

/** Tests the compiled allowlist and run/stage identity rules without Android. */
public final class StageSpecTest {
    private static int checks;

    public static void main(String[] args) {
        checkStage("chat_send", "Check cone inventory", "inventory", 11, 20, 20);
        checkStage("prompt_command", "/rest", "rest", 1, 5, 5);
        checkStage("prompt_send", "Prepare the seasonal restock", "restock", 21, 28, 28);
        for (String invalid : new String[] {null, "", "inventory", "prompt_send ", "PROMPT_SEND", "arbitrary_text"}) {
            try { StageSpec.require(invalid); throw new AssertionError("Unknown stage accepted"); }
            catch (IllegalArgumentException expected) { checks++; }
        }
        String run = repeat('a', 32), stage = repeat('b', 32), sha = repeat('c', 40);
        expect(StageSpec.validIdentity(run, stage, sha), true);
        expect(StageSpec.validIdentity(repeat('a', 64), repeat('b', 64), sha), true);
        expect(StageSpec.validIdentity(run, run, sha), false);
        expect(StageSpec.validIdentity(run, null, sha), false);
        expect(StageSpec.validIdentity(null, stage, sha), false);
        expect(StageSpec.validIdentity(run, stage, null), false);
        expect(StageSpec.validIdentity(repeat('A', 32), stage, sha), false);
        expect(StageSpec.validIdentity(run, repeat('b', 31), sha), false);
        expect(StageSpec.validIdentity(run, repeat('b', 65), sha), false);
        expect(StageSpec.validIdentity(run, stage, repeat('c', 39)), false);
        expect(StageSpec.validIdentity(run, stage, repeat('c', 41)), false);
        expect(StageSpec.validIdentity(run, stage, repeat('G', 40)), false);
        StageSpec selected = StageSpec.require("prompt_send");
        Map<String, String> request = new HashMap<>();
        request.put("nonce", run);
        request.put("stage_nonce", stage);
        request.put("source_sha", sha);
        request.put("stage_id", "prompt_send");
        expect(selected.matchesIdentity(request, run, stage, sha), true);
        request.put("stage_id", "chat_send");
        expect(selected.matchesIdentity(request, run, stage, sha), false);
        request.put("stage_id", "prompt_send");
        request.put("stage_nonce", repeat('d', 32));
        expect(selected.matchesIdentity(request, run, stage, sha), false);
        request.put("stage_nonce", stage);
        request.put("nonce", repeat('e', 32));
        expect(selected.matchesIdentity(request, run, stage, sha), false);
        request.put("nonce", run);
        request.put("source_sha", repeat('f', 40));
        expect(selected.matchesIdentity(request, run, stage, sha), false);
        request.put("source_sha", sha);
        request.remove("stage_id");
        expect(selected.matchesIdentity(request, run, stage, sha), false);
        System.out.println("StageSpecTest passed " + checks + " checks");
    }

    private static void checkStage(String id, String text, String candidate, int base, int extent, int selection) {
        StageSpec spec = StageSpec.require(id);
        expect(spec.id.equals(id) && spec.expectedText.equals(text) && spec.candidateText.equals(candidate)
                && spec.composingBase == base && spec.composingExtent == extent
                && spec.selectionOffset == selection && text.substring(base, extent).equals(candidate), true);
    }
    private static String repeat(char value, int count) { return new String(new char[count]).replace('\0', value); }
    private static void expect(boolean actual, boolean expected) {
        if (actual != expected) throw new AssertionError("Unexpected stage/identity result");
        checks++;
    }
}
