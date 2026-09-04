# Android three-stage wire failure — 9e14317c

The [single manual run 33868182731](https://github.com/pawaovo/shadcn_flutter/actions/runs/33868182731)
at exact source `9e14317c18167b9beb49ed7219fb3a418c52189e` naturally failed.
The first real Chat candidate inspection and VM claim succeeded, but a
host-driver field mismatch prevented any native touch. The later Prompt
command and Prompt Send stages were not reached.

The real Android build ran **46 ProtocolTest checks** and **27 StageSpecTest
checks**, then compiled and signed the v2 helper APK and built the Catalog
debug APK. The host bound actual Catalog PID **2390**, start ticks **26166**,
and helper PID **2328**. These build results are separate from native input
acceptance.

The actual LatinIME window exposed the unique enabled, visible, clickable
`inventory` candidate, and the stage-bound VM claim was valid. The driver then
sent the agreed v2 flat fields `candidate_id` and `lease_id` to
`/native/click`. Python's handler still read the previous nested
`candidate.candidate_id` and `claim.lease_id` structure and returned:

```text
HTTP 409: Driver changed the native candidate identity
```

This is a host-driver wire integration defect. The native event log contains
only `inspect`, `stop` and `finish`; all succeeded. Native click count is **0**,
there is no tap event, and neither original Chat Send nor either later native
stage was accepted. The complete original integration Response was received
with `all_tests_passed=false` and the original abort failure.

The first helper's actual serial stop/drain, process exit, unique log
preservation, forward retirement and reader cleanup completed. Supervisor
cleanup is verified and both driver and supervisor cleanup error lists are
empty. This failure is retained while a minimal field-shape correction and
real Dart-to-Python loopback contract regression are prepared; no gate,
deadline or original input needs to change.

The [JSON companion](android-candidate-9e14317c.json) preserves original run,
artifact, APK, candidate/claim, response and cleanup evidence with core file
hashes. All **123** runner-manifest files were independently verified after
one artifact download. The ZIP digest is GitHub-reported, separately from the
verified extracted-file hashes. Raw evidence remains under
`/tmp/beautiful-android-candidate-9e14317c-33868182731`.

The initial read-only watcher encountered a GitHub API EOF and was resumed;
the CI workflow itself was neither retried nor dispatched again. Earlier
source-specific successes and failures remain unchanged.
