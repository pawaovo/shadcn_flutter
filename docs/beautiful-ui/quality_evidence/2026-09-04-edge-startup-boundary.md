# Edge startup boundary at f5484b9f

This is a read-only diagnosis of the retained failed and successful sessions,
not a configuration repair or a retried test. The [CI record](../../../.github/evidence/f5484b9f-ci.md)
retains the failed main/framework startup results and the independent W3C pass.

Within the same input job, the failed framework session and successful browser
suite have identical actual InitSession capabilities and launch arguments,
apart from their temporary profile paths. Both report browser/driver
`151.0.4129.101` with the same driver revision. Executable file hashes were not
captured, so this is not a byte-for-byte binary claim. The separate main job
uses a matching `152.0.4191.53` pair and is not a same-binary comparison.

| Observation | Failed input framework session | Successful input browser suite |
| --- | --- | --- |
| Session creation | 54.490 seconds | 0.982 seconds |
| Initial window position request | 300.067 seconds, HTTP 500 | 0.012 seconds, success |
| Following window size request | Not reached | 0.016 seconds, success |
| Catalog navigation and assertions | Not reached | Complete W3C suite passed |

Both paths use the same Flutter SDK startup sequence: obtain the window, set
its position, set its size, then start the repository's driver. The successful
suite did not bypass the operation whose request failed in the other session.

The failed request waits for pending navigation. About 600 simple
`Runtime.evaluate("1")` requests continue to receive responses; the trace never
reaches `Browser.getWindowForTarget` or `Browser.setWindowBounds`. Therefore
the error text does not establish that the renderer stopped responding or that
the position-setting operation itself is defective.

Both failed sessions have earlier child-process connection timeout/termination
and network-service crash/restart events. Their initial `data:,` navigation
lacks the completion events present in the successful session. This supports
two still-unresolved possibilities: the initial navigation did not complete
after the startup failure, or EdgeDriver did not clear its navigation tracking
state. There is no captured resource/exit-cause evidence establishing CPU,
memory, shared-memory exhaustion, or a specific incorrect browser flag.

The actual request logs and driver event logs remain under
`/tmp/beautiful-ci-f5484b9f/input/input-edge/{framework,browser}/`; the separate
main trace is under `apple-watch/edge-journey/`. The exact initialization,
navigation wait and startup-event comparisons were reviewed independently.

Recomputed raw-log hashes, with paths relative to `/tmp/beautiful-ci-f5484b9f`:

| File | SHA256 |
| --- | --- |
| `input/input-edge/framework/webdriver.log` | `055c062fc495e31ace5cdd7624d88b38de10178af59060d54d21b6130c53b2fc` |
| `input/input-edge/browser/webdriver.log` | `7212603d5157601186b8da2af50282a505c375158d20b60d9dae00762572c110` |
| `input/input-edge/framework/msedgedriver.log` | `90c19a101a6084c632a106141b24fc4e888cd8f917a3fbed3e4da9cc3f6f36a0` |
| `input/input-edge/browser/msedgedriver.log` | `377f82334f2f0a8162c887e6bebff1b3727d7256e8bf726a72eb856d418c9705` |
| `apple-watch/edge-journey/msedgedriver.log` | `f746c708309eddc59983253f82e9452b361b299de46146a5a0365ffa494522fe` |

No positioning request, browser argument, timeout, page-load behavior or
assertion was changed. No additional retry was used to replace the failure.
Further diagnosis needs a newly observed startup with executable hashes,
process exit information and resource samples aligned to the existing event
timeline. The successful independent suite does not accept the unexecuted
Edge shared journey.
