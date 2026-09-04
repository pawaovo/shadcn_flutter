# Exact-source Narrator diagnostic: 70e3d149

**The diagnostic code compiled and its seven pure checks passed. The actual
Windows session had zero render endpoints, and real Narrator fixture capability
remained unaccepted.** This is one manual run for
`70e3d14970d2cb383f63c7c480a26ca295a23c2b`, with no retry or acceptance relaxation.

[Run 33841314675](https://github.com/pawaovo/shadcn_flutter/actions/runs/33841314675)
and [job 100924033015](https://github.com/pawaovo/shadcn_flutter/actions/runs/33841314675/job/100924033015)
ended naturally with failure. The [JSON record](./narrator-70e3d149.json) preserves
the actual run/job and artifact metadata, runtime provenance, original probe
report, all 13 downloaded file hashes and four verified runtime source hashes.
Requested source, checkout HEAD, workflow SHA and GitHub run head all match.
The Windows runtime hashes match the exact Git blobs with CRLF checkout endings.

| Layer | Actual result | Evidence boundary |
| --- | --- | --- |
| Runtime | GitHub-hosted X64 Windows Server 2025 build 26100; image `win25-vs2026`, `20260824.214.3`; Windows PowerShell Desktop `5.1.26100.33296` | Recorded from this session, not assumed from `windows-latest` |
| Pure regression | Production PowerShell parse, complete embedded C# compilation, **7 diagnostic checks and JSON round-trip passed**, exit `0`, **2.532 seconds** | No reader, device or input was exercised by these checks |
| Actual native fixture compilation | `.NET Framework64/v4.0.30319/csc.exe`, exit `0`; executable exists and is **19,456 bytes** | Confirms compilation, not spoken interaction |
| Actual capability probe | **14.205 seconds**, exit **`2`**, `not_accepted` | UIA and ordinary Tab/Space observed; fixture AT navigation, utterance, synthesized audio and human review remain unaccepted |

The read-only audio inventory successfully called
`EnumAudioEndpoints(eRender, DEVICE_STATEMASK_ALL=0xF)` and `GetCount`, both with
HRESULT `0x00000000`. The returned count was **0**, covering active, disabled,
not-present and unplugged render endpoints. Inventory itself reported no error.
Both audio services reported running status (`4`). This establishes endpoint
absence in the observed available GitHub Windows session, rather than merely
failure to find one selected default role.

| Actual call | HRESULT |
| --- | --- |
| Default render endpoint, `eConsole` | `0x80070490` |
| Default render endpoint, `eMultimedia` | `0x80070490` |
| Default render endpoint, `eCommunications` | `0x80070490` |
| Original capture `GetDefaultAudioEndpoint(eRender,eConsole)` | `0x80070490` |

Capture failed at that exact default-endpoint call, before audio-client
activation. No virtual endpoint was created, no alternate role was chosen and
no WAV was produced. The original 50-second probe budget, 65-second supervised
wait, Job Object cleanup, audio threshold and AT assertions remained intact.

The new command boundaries also narrow the navigation failure. Before
Narrator+Tab at `05:40:30.1910239Z`, beta had keyboard focus and the fixture was
foreground. Its immediate after-send observation still showed both true, with
**4** input events inserted. By the observation-window end at
`05:40:34.7409722Z`, both fixture foreground and fixture focus were false. The
later copy and invoke commands were sent with task focus still absent, reporting
**6** and **4** inserted events respectively. These counts are SendInput results,
not proof that Narrator completed the intended task actions.

The actual copied text was:

```text
Narrator window heading level 1,
Welcome to Narrator
```

That is different from the fixture's required beta label and from the older
sentinel. It shows that a Narrator heading was copied; it does not accept the
fixture utterance or justify attributing failure solely to an unsupported copy
command. The external focused window was not inspected, so its identity and the
cause of the focus transition are not asserted. The fixture event log ended
after ordinary Tab focused beta and ordinary Space recorded `checked=true`;
there was no subsequent `checked=false` reader invocation.

Original artifacts remain at
`/tmp/beautiful-narrator-70e3d149-33841314675/narrator-diagnostic-33841314675-1/`.
The raw `probe/report.json` has SHA-256
`d3e40f45ec1b67714160abdea7e6d001b441f5c3fbf87883996657312b52fa19`;
`probe/narrator-utterance.txt` has SHA-256
`9c9db461330f76b72d93e2f9ca3db3d2c25f8062bb5b4ef5feeb447406fdfd81`.
Artifact **9925017084** is 8,642 bytes; its ZIP digest in the JSON is GitHub API
metadata, while the 13 individual downloaded file hashes were independently
recomputed. The complete GitHub job log and fetched metadata remain alongside
the artifact directory with their own recorded hashes.

Real speech capability, human listening review and Flutter application AT task
acceptance remain incomplete. Passing seven pure diagnostic checks does not
change those statuses or the failure conclusion of this run.
