#requires -Version 5.1
<#
Pure diagnostic regression: parses the production PowerShell and compiles its
complete C# source, but never executes the probe, starts a fixture/reader,
enumerates a device, sends input, reads clipboard, or captures audio.
Run: powershell -NoProfile -STA -File .github/scripts/test_probe_real_at_windows.ps1
#>
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1' }
$probe = Join-Path $PSScriptRoot 'probe_real_at_windows.ps1'
$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($probe, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw ($parseErrors | Out-String) }
$text = [IO.File]::ReadAllText($probe)
$match = [regex]::Match($text, '(?ms)^\$source = @''\r?\n(.*?)\r?\n''@')
if (-not $match.Success) { throw 'Production C# source was not found' }
$checks = @'

public static class NarratorDiagnosticRegression {
    static int checks;
    static void Require(bool passed, string reason) {
        if(!passed) throw new Exception(reason);
        checks++;
    }
    static AtOwnedWindowState Window() {
        return new AtOwnedWindowState { owner_pid=42, native_owner_pid=42,
            owner_alive=true, pattern_available=true, can_minimize=true, ready=true };
    }
    static AtFixtureFocus Focus() {
        return new AtFixtureFocus { process_id=17, fixture_alive=true,
            fixture_foreground=true, has_keyboard_focus=true, control_name="beta" };
    }
    static bool Rejects(Action action) {
        try { action(); return false; }
        catch(InvalidOperationException) { return true; }
    }
    static void GuardChecks() {
        AtOwnedWindowState wrongOwner=Window(); wrongOwner.owner_pid=99;
        AtOwnedWindowState unknownNativeOwner=Window(); unknownNativeOwner.native_owner_pid=0;
        AtOwnedWindowState deadOwner=Window(); deadOwner.owner_alive=false;
        foreach(AtOwnedWindowState state in new AtOwnedWindowState[] { null, wrongOwner, unknownNativeOwner, deadOwner }) {
            int actions=0, afterReads=0; AtWindowPreparation result=new AtWindowPreparation();
            bool rejected=Rejects(delegate { AtWindowGuard.Prepare(42,delegate { return state; },
                delegate { actions++; },delegate { afterReads++; return Window(); },result); });
            Require(rejected && actions==0 && afterReads==0 && !result.minimize_started,
                "Unknown, changed or exited ownership must not invoke a window action");
        }
        AtOwnedWindowState noPattern=Window(); noPattern.pattern_available=false;
        AtOwnedWindowState noMinimize=Window(); noMinimize.can_minimize=false;
        AtOwnedWindowState modal=Window(); modal.is_modal=true;
        AtOwnedWindowState busy=Window(); busy.ready=false;
        foreach(AtOwnedWindowState state in new AtOwnedWindowState[] { noPattern, noMinimize, modal, busy }) {
            int actions=0;
            Require(Rejects(delegate { AtWindowGuard.Prepare(42,delegate { return state; },
                delegate { actions++; },delegate { return Window(); },new AtWindowPreparation()); }) && actions==0,
                "Unsupported, modal or noninteractive windows must not be minimized");
        }
        int minimized=0, rereads=0;
        AtWindowPreparation completed=new AtWindowPreparation();
        AtWindowGuard.Prepare(42,delegate { return Window(); },delegate { minimized++; },delegate {
            rereads++; AtOwnedWindowState state=Window(); state.minimized=true; return state;
        },completed);
        Require(minimized==1 && rereads==1 && completed.after.minimized,
            "Preparation must minimize once and verify actual resulting state");
        minimized=0;
        Require(Rejects(delegate { AtWindowGuard.Prepare(42,delegate { return Window(); },
            delegate { minimized++; },delegate { return Window(); },new AtWindowPreparation()); }) && minimized==1,
            "An unchanged visible window must fail after a single action, without retry");
        minimized=0;
        Require(Rejects(delegate { AtWindowGuard.Prepare(42,delegate { return Window(); },
            delegate { minimized++; },delegate { return wrongOwner; },new AtWindowPreparation()); }) && minimized==1,
            "Ownership must be checked again after minimization");
        AtOwnedWindowState hidden=Window(); hidden.hidden=true;
        minimized=0;
        AtWindowGuard.Prepare(42,delegate { return hidden; },delegate { minimized++; },
            delegate { return hidden; },new AtWindowPreparation());
        Require(minimized==0,"An already hidden owned window needs no repeat minimize action");

        Exception original=new COMException("minimize API failed",unchecked((int)0x80004005));
        Exception observed=null; minimized=0; rereads=0;
        try { AtWindowGuard.Prepare(42,delegate { return Window(); },delegate { minimized++; throw original; },
            delegate { rereads++; return Window(); },new AtWindowPreparation()); }
        catch(Exception error) { observed=error; }
        Require(Object.ReferenceEquals(original,observed) && minimized==1 && rereads==0,
            "A minimize exception must be preserved and must not trigger recovery/retry");
        original=new InvalidOperationException("state observation failed"); observed=null; minimized=0;
        try { AtWindowGuard.Prepare(42,delegate { return Window(); },delegate { minimized++; },
            delegate { throw original; },new AtWindowPreparation()); }
        catch(Exception error) { observed=error; }
        Require(Object.ReferenceEquals(original,observed) && minimized==1,
            "An observation failure after the action must retain its original exception");

        AtFixtureFocus wrongPid=Focus(); wrongPid.process_id=99;
        AtFixtureFocus noForeground=Focus(); noForeground.fixture_foreground=false;
        AtFixtureFocus noKeyboardFocus=Focus(); noKeyboardFocus.has_keyboard_focus=false;
        AtFixtureFocus wrongControl=Focus(); wrongControl.control_name="alpha";
        AtFixtureFocus deadFixture=Focus(); deadFixture.fixture_alive=false;
        foreach(AtFixtureFocus state in new AtFixtureFocus[] { null, wrongPid, noForeground, noKeyboardFocus, wrongControl, deadFixture }) {
            int sends=0; AtInputAttempt attempt=new AtInputAttempt();
            bool rejected=Rejects(delegate { AtInputGuard.Send(17,"beta",delegate { return state; },
                delegate { sends++; return 4; },attempt); });
            Require(rejected && sends==0 && !attempt.send_started,
                "Every invalid actual-focus condition must prevent SendInput entirely");
        }
        int sent=0, focusReads=0; AtInputAttempt accepted=new AtInputAttempt();
        uint count=AtInputGuard.Send(17,"beta",delegate { focusReads++; return Focus(); },
            delegate { sent++; return 4; },accepted);
        Require(count==4 && sent==1 && focusReads==1 && accepted.send_started,
            "A valid focus observation allows exactly one input action and preserves its result");
        AtInputAttempt failed=new AtInputAttempt(); original=new COMException("focus query failed"); observed=null; sent=0;
        try { AtInputGuard.Send(17,"beta",delegate { throw original; },delegate { sent++; return 4; },failed); }
        catch(Exception error) { observed=error; }
        Require(Object.ReferenceEquals(original,observed) && sent==0 && !failed.send_started,
            "A focus observation error must be preserved without sending input");
        failed=new AtInputAttempt(); original=new COMException("send failed"); observed=null; sent=0;
        try { AtInputGuard.Send(17,"beta",delegate { return Focus(); },delegate { sent++; throw original; },failed); }
        catch(Exception error) { observed=error; }
        Require(Object.ReferenceEquals(original,observed) && sent==1 && failed.send_started,
            "A send error must not be misreported as input_not_sent or be retried");
    }
    public static int Run() {
        int missing=unchecked((int)0x80070490);
        AtAudioDiagnostics.Calls.Clear();
        AtAudioDiagnostics.Call("test.success",delegate { return 0; });
        Require(AtAudioDiagnostics.Calls.Count==1 &&
            AtAudioDiagnostics.Calls[0].stage=="test.success" &&
            AtAudioDiagnostics.Calls[0].hresult_hex=="0x00000000",
            "Successful initialization must retain its stage and actual HRESULT");

        COMException observed=null;
        try { AtAudioDiagnostics.Call("test.default.console",delegate { return missing; }); }
        catch(COMException error) { observed=error; }
        Require(observed!=null && observed.ErrorCode==missing &&
            observed.Message.Contains("test.default.console"),
            "A failing COM result must still throw with its original HRESULT and exact stage");
        Require(AtAudioDiagnostics.Calls.Count==2 &&
            AtAudioDiagnostics.Calls[1].hresult_hex=="0x80070490",
            "The failed call must be recorded exactly once");

        COMException original=new COMException("marshalling or activation failure",missing);
        observed=null;
        try { AtAudioDiagnostics.Call("test.activation",delegate { throw original; }); }
        catch(COMException error) { observed=error; }
        Require(Object.ReferenceEquals(original,observed) &&
            AtAudioDiagnostics.Calls[2].stage=="test.activation" &&
            AtAudioDiagnostics.Calls[2].hresult==missing &&
            AtAudioDiagnostics.Calls[2].exception_type==typeof(COMException).FullName,
            "Thrown COM exceptions must retain identity, stage, type and HRESULT");

        AtAudioDiagnostics.Call("test.cleanup",delegate { return 0; });
        Require(AtAudioDiagnostics.Calls[1].hresult==missing &&
            AtAudioDiagnostics.Calls[3].stage=="test.cleanup",
            "Later cleanup must not overwrite the original failed-call evidence");

        AtAudioDiagnostics.Call("test.packet.success",delegate { return 0; },false);
        Require(AtAudioDiagnostics.Calls.Count==4,
            "Successful packet polling must not accumulate per-frame diagnostic noise");
        observed=null;
        try { AtAudioDiagnostics.Call("test.packet.failure",delegate { return missing; },false); }
        catch(COMException error) { observed=error; }
        Require(observed!=null && AtAudioDiagnostics.Calls.Count==5 &&
            AtAudioDiagnostics.Calls[4].stage=="test.packet.failure" &&
            AtAudioDiagnostics.Calls[4].hresult==missing,
            "Packet failures must retain stage/HRESULT even when successes are suppressed");
        GuardChecks();
        return checks;
    }
}
'@
Add-Type -TypeDefinition ($match.Groups[1].Value + $checks) -ReferencedAssemblies System.Windows.Forms, System.Drawing
$passed = [NarratorDiagnosticRegression]::Run()
$serialized = [AtAudioDiagnostics]::Calls.ToArray() | ConvertTo-Json -Depth 10
$decoded = $serialized | ConvertFrom-Json
if ($decoded.Count -ne 5 -or $decoded[1].hresult_hex -ne '0x80070490' -or $decoded[2].stage -ne 'test.activation') {
    throw 'PowerShell JSON serialization lost original stage/HRESULT evidence'
}
Write-Output "Passed $passed C# diagnostic checks, PowerShell parse and JSON round-trip; no native capability was exercised."
