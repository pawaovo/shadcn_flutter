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
