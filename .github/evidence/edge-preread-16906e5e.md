# Edge executable preread: completed observation, unresolved original failure

On 2026-09-04, one explicitly authorized preread run completed all three independent
Edge startup sessions and verified cleanup. The original 300-second navigation-wait
failure was not reproduced. This does **not** close that failure or establish a
production repair. The intended one-variable comparison is confounded by an
actual runner-image and browser/driver distribution change.

| Evidence | Retained baseline | Explicit preread trial |
| --- | --- | --- |
| GitHub run | [33838225726](https://github.com/pawaovo/shadcn_flutter/actions/runs/33838225726) | [33840112894](https://github.com/pawaovo/shadcn_flutter/actions/runs/33840112894) |
| Source | `d1c44cce0bede4355bb4456a1280af34dce00ec5` | `16906e5ea8f8a2fdc280b1e4504d81d0ac0a290a` |
| Ubuntu image version | `20260823.283.1` | `20260831.293.1` |
| Edge and driver version | `151.0.4129.101` | `152.0.4191.53` |
| Actual browser ELF SHA-256 | `c50c266b5dbae21b5ae7b1ff3a0b6c352441520b114ff9e98d49910e3b450162` | `6a612f822ea7f30de05d5b36566d3e306cdf8fc7b35577c03efaaddcc2a4923a` |
| Actual driver SHA-256 | `c8bf9cd5531e0efd7710cc3d6001f4737fdd2b44ced897604ed8c4c11aca271c` | `a26d989f6c81d1b3a03f036af29670f47662aeeeb3631fd27c4c59b192c5ce2b` |
| Startup / cleanup outcomes | 3 passed / 3 verified | 3 passed / 3 verified |

All six cases retained the original five startup requests, the same normalized
session capability objects, and the same actual launch arguments apart from their
independent profile paths. Each returned `normal` page-load strategy and a
`300000` ms page-load deadline. All original startup requests and subsequent quits
returned HTTP 200. No original action was retried. The preread trial used three
different browser PIDs and profiles, and all three actual PID-to-executable
bindings were verified. These checks do not remove the distribution/host confound.

## Timing and cost

| Case | Baseline session creation | Preread session creation | Trial position / size |
| --- | ---: | ---: | ---: |
| 1 | 32.634035 s | 3.989137 s | 15.756 / 18.721 ms |
| 2 | 0.261657 s | 0.366723 s | 18.341 / 23.172 ms |
| 3 | 0.277729 s | 0.367614 s | 22.366 / 22.807 ms |

The trial read **398,466,384 bytes once in 11.031384 seconds** before any startup
session. The preread hash matched the actual browser file's later hash. The read
plus the first session-creation request cost 15.020521 seconds; that subtotal
excludes other setup and commands. The measured case loop, including preread,
three sessions and cleanup, took **17.453838 seconds**. That loop timer excludes
the initial installed-version/source checks and final post-session executable
hashing. The baseline did not record the equivalent loop-total field, so this
report does not manufacture an end-to-end speedup ratio.

The first baseline browser had 26 `D` / `folio_wait_bit_common` observations in
32 periodic process samples. The first trial browser had one in four samples.
Host-wide I/O PSI `some` increased 25.142363 seconds during the baseline's first
session observation interval, versus 2.398146 seconds in the trial's interval.
Those intervals start with the first resource sample and end at the post-startup
snapshot. They are raw observations across different runner distributions, not
proof that prereading caused the difference.

The 1 Hz observer begins after preread: **there is no resource time series during
the 11.031384-second read itself**. Some work may simply move before session
creation. Subsecond cases had no periodic sample of the main browser; their
post-startup `/proc` identity snapshots were captured. No sampled zero is treated
as proof that no waiting occurred. Neither run contained the earlier child
15-second no-connection termination or Network service crash signal.

## Earlier fixed-152 context

The earlier [run 33761035001](https://github.com/pawaovo/shadcn_flutter/actions/runs/33761035001)
started at 2026-09-03 13:25:04 UTC from
`d97a2e1277b8ba2d1a89625d9982edd668fd0632`. It installed the exact official Edge
152 distribution on three separate runners and completed the original Catalog
journey in each. Raw adapter session-creation durations were 0.497, 1.068 and
0.398 seconds; the position requests were 14, 17 and 16 ms. The journey logs
contain `All tests passed.` and every adapter response was HTTP 200.

All three old samples recorded the **same driver executable SHA-256 as this
preread trial** (`a26d989f…c5ce2b`). They recorded browser version 152.0.4191.53
and the browser `.deb` distribution digest, but **not the installed browser ELF
digest**. A package digest cannot establish ELF byte equality. The old sample-1
job setup log reports Ubuntu image `20260823.283.1`; sample-2/3 image metadata was
not retrieved in this comparison. Thus these successful journeys provide useful
same-version and same-driver context, not a matched control for the preread run.

## Retained evidence and limits

[The accompanying JSON](edge-preread-16906e5e.json) records per-case identities,
timings, protocol comparisons, image/hash differences, old fixed-152 context, and
SHA-256/byte counts for 42 source artifact files. Original artifact directories:

- Baseline: `/tmp/edge-cold-start-d1c44cce-33838225726/`
- Preread: `/tmp/edge-preread-16906e5e-33840112894/`
- Fixed 152: `/tmp/edge-152-run-33761035001/`
- Old sample-1 job log: `/tmp/edge-152-context-33761035001-job100667110655.log`

This follow-up performed one preread dispatch and no new baseline dispatch. It
does not modify old evidence, relax any startup/acceptance condition, claim that
initial Flutter compilation runs concurrently with Edge creation, or interpret
three passing sessions as resolution of the earlier failure. No further run was
triggered from these results. If the original full CI path fails again, its actual
failed request and process evidence remain the basis for a subsequent diagnosis.
