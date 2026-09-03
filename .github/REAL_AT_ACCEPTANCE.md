# Real assistive technology capability probes

These probes exercise a small native fixture with a running screen reader. They
answer whether a runner can collect useful real AT evidence. They do **not**
accept the Flutter catalog, replace its native accessibility tests, or complete
human screen reader review. They are independent of the application journey.

The scripts refuse to launch outside `GITHUB_ACTIONS=true` unless a caller
explicitly supplies `--allow-local` (Linux) or `-AllowLocal` (Windows). Local
validation of changes should parse the source only; do not launch them as a
syntax check. All GUI, AT, and audio processes launched by the scripts are owned
by the probe and cleaned up. Existing Narrator is never replaced. Orca is started
without `--replace` in the workflow's private D-Bus/X11 session.
Linux cleanup checks the entire owned process group after its leader exits.
The Windows CI supervisor owns PowerShell and its descendants in a private Job
Object, including on timeout, and checks that the job is empty before accepting
the probe exit. Cleanup failures remain failing evidence on both platforms.

## Linux

Use Ubuntu 24.04 and system Python so the distribution's GI/AT-SPI modules are
available. Install in the disposable runner:

```sh
sudo apt-get update
sudo apt-get install -y orca speech-dispatcher speech-dispatcher-espeak-ng \
  espeak-ng pulseaudio pulseaudio-utils python3-gi python3-pyatspi \
  python3-speechd gir1.2-gtk-3.0 at-spi2-core dbus-x11 xvfb xauth xdotool
timeout 65s dbus-run-session -- xvfb-run -a /usr/bin/python3 \
  .github/scripts/probe_real_at_linux.py \
  --output artifacts/real-at-linux --seconds 50
```

The probe starts private PulseAudio and Speech Dispatcher instances, selects the
real `espeak-ng` module, starts Orca with private preferences, and navigates a GTK
button/checkbox fixture. It records Orca's output after its Where Am I command,
checks keyboard state changes, and captures PCM from the isolated audio monitor.
No test string is submitted to a speech API. The WAV, transcript, daemon logs,
native tree, fixture events, and report are artifacts for inspection.

## Windows

Use Windows PowerShell 5.1 with STA, available in the standard Windows runner:

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass `
  -File .github/scripts/probe_real_at_windows.ps1 `
  -OutputDirectory artifacts/real-at-windows -Seconds 50
```

The probe compiles an owned WinForms fixture using the .NET Framework compiler,
checks the input desktop, window activation, UIA controls, and actual keyboard
response, then launches Narrator. It requests Narrator's current-item reading,
copies Narrator's last utterance, and attempts Narrator's own invoke command. A
WASAPI loopback recorder captures the render endpoint during those commands.
The script does not install an audio driver or silently manufacture an endpoint.
An absent endpoint, unsupported copy command, missing voice/output, or failed
invocation remains unaccepted. Endpoint-wide audio is not independently
attributed to Narrator; a human must check the recording.

Use a job timeout as a final guard around platform APIs. Normal script work is
bounded to 50 seconds with short process cleanup. Upload the output directory
with `if: always()` so missing capability is reviewable when the job fails.

## Report and exit contract

`report.json` records `native_accessibility`, `at_navigation`, `utterance_output`,
`synthesized_audio`, and `human_review` separately. Machine layers use `observed`
only for evidence from the native fixture. Missing layers use `not_accepted`.
Top-level `application_acceptance` and `human_review` always remain
`not_accepted`. Exit `0` means all four machine-observable fixture layers were
observed (`status=capability_observed`); exit `2` means a capability was missing
or could not be observed (`status=not_accepted`). A timeout or runner termination
is also a failure, never a pass. Do not configure `continue-on-error` or treat a
capability probe as a release acceptance gate for the application.

To accept the Flutter application, repeat the actual catalog tasks with the
screen reader running, associate navigation and state changes with its real
utterances/audio, and explicitly record human review of understandable output
and successful task completion. A semantics flag, accessible tree, running AT
process, or transcript alone cannot establish that result.

## Evidence behind the boundary

- [Microsoft accessibility testing](https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessibility-testing)
  separates UIA inspection from Narrator navigation, action invocation, listening,
  and human review.
- [Narrator speech recap](https://support.microsoft.com/en-us/windows/complete-guide-to-narrator-e4397a0d-ef4f-b386-d8ae-c172f109bdb1)
  documents copying the last utterance. Its availability must be observed on the
  installed Server build; Windows 11 documentation does not promise Server parity.
- [WASAPI loopback](https://learn.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording)
  requires a rendering endpoint and captures its shared audio stream.
- [Orca 46 speech implementation](https://github.com/GNOME/orca/blob/gnome-46/src/orca/speech.py#L143)
  emits `SPEECH OUTPUT` even when there is no speech server. This is why a debug
  transcript is checked separately from actual PCM.
- [Orca's upstream integration sandbox](https://github.com/GNOME/orca/blob/main/tests/integration_tests/harness/sandbox.py#L64)
  deliberately uses a dummy speech backend; copying that setup would not verify
  synthesis. This probe retains the real backend.
- [PulseAudio modules](https://wiki.freedesktop.org/www/Software/PulseAudio/Documentation/User/Modules/)
  document a virtual sink's monitor source, which allows recording real PCM
  without requiring physical speakers.
- [GitHub runner images](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners)
  change regularly. Save each job's image version and its Included Software link
  alongside the reported screen reader/backend versions.
