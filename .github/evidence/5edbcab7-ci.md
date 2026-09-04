# Completed CI for `5edbcab7`

Both automatic push workflows completed naturally on attempt 1 at `5edbcab7edc5c058cf9354c6109df917846fb4e8`. Main finished **11/12 jobs passed**; input and AT capability finished **4/9 jobs passed**. The original main Edge journey passed under the new once-only ELF preread condition. Android retained an actual Chat sent-message assertion failure; input retained the web framework composing failures and Narrator preparation failure.

| Workflow | Final result | Run |
|---|---|---|
| Beautiful AI UI | failure; 11 success, 1 failure | [33850098717](https://github.com/pawaovo/shadcn_flutter/actions/runs/33850098717) |
| Beautiful AI UI input and AT capability evidence | failure; 4 success, 5 failure | [33850098744](https://github.com/pawaovo/shadcn_flutter/actions/runs/33850098744) |

The [JSON companion](5edbcab7-ci.json) records all 21 job identities, source and attempt metadata, uploaded artifact IDs/digests, scoped results, and original-file size/SHA-256 references. All artifacts were downloaded once per completed run to `/tmp/beautiful-ci-5edbcab7/main` and `/tmp/beautiful-ci-5edbcab7/input`. Those directories retain run/job metadata, full logs, downloaded originals and derived audit/hash inventories. Local polling, downloads, hashing and writing paused during the root native performance capture; remote CI continued naturally. Neither workflow was dispatched or retried during collection. The [completed `153412b3` record](../../docs/beautiful-ui/quality_evidence/2026-09-04-153412b3-ci.md) remains unchanged.

## Main results and Android failure

Formatting checked **164 files, zero changes**. Strict analysis passed for three packages. The disjoint library groups passed **537 behavior + 109 semantics + 12 strict Linux golden tests = 658 tests**; Catalog passed **110 tests**, and upstream core passed **571 tests**. These are the completed `5edbcab7` log counts, including the increase from 109 to 110 Catalog tests.

All configured platform build jobs and the original Chrome, Edge, Firefox, Linux, macOS, Windows and iOS journeys passed. The separate [Android journey job](https://github.com/pawaovo/shadcn_flutter/actions/runs/33850098717/job/100950747250) failed after successful APK compilation and installation. Its single framework touch send expected one host user message containing `Check cone inventory`; it found zero at `integration_test/support/chat_send_diagnostics.dart:140`.

The original diagnostic snapshots repeat the earlier observed pattern:

| Snapshot | Composing range | Send semantics | Host state |
|---|---|---|---|
| Before tap | `[-1,-1]` | enabled | idle, two initial messages |
| Pointer down | `[11,20]` | disabled | idle, two initial messages |
| Pointer up | `[11,20]` | disabled | idle, two initial messages |
| After tap | `[11,20]` | disabled | idle, two initial messages |

This is an application-journey assertion failure, separate from the web framework checks below. The observations do not by themselves establish its complete cause. The full job log remains at `/tmp/beautiful-ci-5edbcab7/main/job-100950747250-android.log` and is hashed in the JSON record. Later local fixes do not alter this result.

## Edge preparation and original upstream results

The new preparation ran once before each original upstream runner. Both setup reports bind their `source_sha` to this commit, report `ready` / `read_complete`, and retain the 60-second preread limit. Both post-run verification reports are `verified` and bind the actual browser session to the executable that was read.

| Recorded field | Main Edge | Input Edge |
|---|---|---|
| Ubuntu image | `20260823.283.1` | `20260831.293.1` |
| Actual browser / driver | `151.0.4129.101` / `151.0.4129.101` | `152.0.4191.53` / `152.0.4191.53` |
| Actual ELF bytes read once | 398,196,048 | 398,466,384 |
| Preread duration | 13.285643 seconds | 16.604548 seconds |
| Upstream result retained by verification | passed | failed |
| Actual upstream suites | Original full journey passed | Framework failed; real W3C browser suite passed |

In each report, the preread SHA-256 matches the post-run browser executable SHA-256. The JSON companion retains the full browser and driver hashes, actual session versions, and original setup/preread/verification file hashes. The installed driver's initial version banner is not substituted for the actual session identity.

Main verification observed **13 recorded process identities absent** and uses the explicit scope `observed_identity_no_live_processes`. Input verification uses `owned_group_cleanup_verified` and separately records 13 framework identities and 12 browser-suite identities absent. Both reports explicitly set `unobserved_descendant_absence_claimed: false`; these results do not prove absence of every unobserved descendant.

The main original full journey includes two trusted browser clipboard clicks (`journey-code-copy` and `journey-stream-copy`); its remaining interactions retain the original Flutter-injected scope. The original upstream adapter and journey completed successfully. Input verification deliberately preserves the failed framework result, so successful preparation has not converted a failed test into a pass.

This is one successful main run under the new preparation condition. Main and input used different images and different executable versions; the earlier [paired diagnostic](../../docs/beautiful-ui/diagnostics/edge-startup/2026-09-04-153412b3-pair.md) also used different runner regions. These records do not establish a general repair, causal performance improvement or reproducibility rate.

## iOS result

The [Apple job](https://github.com/pawaovo/shadcn_flutter/actions/runs/33850098717/job/100950747281) and its original `ios-journey.json` passed:

| Stage | Result | Seconds |
|---|---|---:|
| Install | exit 0 | 11.931 |
| Launch | exit 0 | 1.538 |
| VM service discovery | passed; one history query | 5.088, including launch |
| Native Flutter driver | exit 0; `All tests passed.` | 32.738 |
| Terminate | exit 0 | 0.905 |

The single scoped history query took **3.485 seconds** within its recorded 15-second limit, with `timed_out: false`, `stdout_eof: true`, `host_group_clean: true`, `final_drain_complete: true`, `host_returncode: 0`, and 227 bytes read. The original journey JSON, history report and driver log are hashed in the JSON companion. This run had no iOS failure.

## Input and AT capability boundaries

The four real browser suites each passed **26 W3C stages**, including real browser clipboard operations and the terminal `complete` stage; this is not a count of 26 independent input actions. Safari's original full Catalog journey also passed. Linux, macOS and Windows each passed **6/6 native framework scenarios** within one integration test, including the real native clipboard bridge with its documented Flutter-injected event boundary.

Chrome, Edge and Firefox framework suites failed at `prompt_composing_and_submission`: the expected composing range `[0,2]` for `中文` was observed as `[-1,-1]`. Safari passed that earlier scenario but failed at `synthetic_resize_preserves_prompt_draft`, losing the same composing range for `中文 inventory draft`. The reported text and selection matched; composing did not. These failures are preserved independently of the passing trusted browser suites. Neither Unicode W3C insertion nor Flutter-injected editing values establish real OS IME acceptance.

Orca's native fixture capability passed accessibility, navigation, utterance and synthesized-audio observations. The retained audio contains **53,788 PCM frames at 16 kHz**, RMS **3940.0003670265382**. Its `application_acceptance` and human review remain `not_accepted`: the GTK fixture does not accept the Flutter Catalog.

Narrator failed during preparation with **`Owned Narrator window does not support safe minimization`**. Native accessibility was observed, while AT navigation, utterance output and synthesized audio were not accepted. Separately, its read-only inventory recorded zero render endpoints and `0x80070490` for all three default audio roles. The direct preparation error and the audio inventory are both retained; the record does not reduce the failure to an audio-only diagnosis.

## Publication and remaining acceptance

The publish dry-run passed with a **3 MB archive and zero warnings**. The isolated consumer gate passed at this exact source against public `shadcn_flutter 0.0.54`, verifying **209 unmodified hosted runtime files**, **12 theme observations** and **13 required license labels**. The consumer used a temporary publication-surface path dependency for `beautiful_ai_ui`; no actual package publication occurred.

These completed source-specific CI records do not accept the full platform, visual, real OS IME, human assistive-technology or performance scope. In particular, the separately collected native performance data has its own source, environment and budget evidence. No historical failure was rewritten and no later local result is attributed to this commit without its own evidence.
