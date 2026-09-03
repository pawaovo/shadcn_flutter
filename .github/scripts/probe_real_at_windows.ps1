#requires -Version 5.1
<#
Run with Windows PowerShell 5.1 -STA in a disposable GitHub-hosted job.
Exit 0: all four automated native-fixture capability layers observed.
Exit 2: missing/unobserved capability. This never accepts the Flutter application.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = 'artifacts/real-at-windows',
    [ValidateRange(30, 55)][int]$Seconds = 50,
    [switch]$AllowLocal
)
$ErrorActionPreference = 'Stop'
$started = [Diagnostics.Stopwatch]::StartNew()
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('narrator-probe-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporary) | Out-Null
$owned = New-Object 'System.Collections.Generic.List[System.Diagnostics.Process]'
$report = [ordered]@{
    schema_version = 1; platform = 'windows'; scope = 'native_fixture_capability'
    status = 'not_accepted'; application_acceptance = 'not_accepted'
    explanation = 'A native WinForms fixture cannot accept the Flutter catalog or replace human review.'
    runtime = [ordered]@{
        os = [Environment]::OSVersion.VersionString; powershell = "$($PSVersionTable.PSVersion)"
        image = $env:ImageVersion; session_id = [Diagnostics.Process]::GetCurrentProcess().SessionId
        user_interactive = [Environment]::UserInteractive
    }
    layers = [ordered]@{}; evidence = [ordered]@{}; errors = @()
}
foreach ($layer in @('native_accessibility', 'at_navigation', 'utterance_output', 'synthesized_audio', 'human_review')) {
    $report.layers[$layer] = @{ status = 'not_accepted'; reason = 'Not observed' }
}

function Wait-Probe([scriptblock]$Condition, [double]$Timeout = 4) {
    $end = [Math]::Min($Seconds, $started.Elapsed.TotalSeconds + $Timeout)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 120
    } while ($started.Elapsed.TotalSeconds -lt $end)
    throw 'Timed out waiting for a capability response'
}
function Assert-Time {
    if ($started.Elapsed.TotalSeconds -ge $Seconds) { throw 'Probe deadline exceeded' }
}
function Observe([string]$Name, [hashtable]$Evidence) {
    $Evidence.status = 'observed'
    $report.layers[$Name] = $Evidence
}

# The same source is loaded for P/Invoke/COM and compiled as an owned fixture exe.
# No SAPI Speak call or supplied expected string is used to create audio.
$source = @'
using System;
using System.IO;
using System.Threading;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;

public static class AtCapability {
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public InputUnion data; }
    [StructLayout(LayoutKind.Explicit)] public struct InputUnion {
        [FieldOffset(0)] public KEYBDINPUT keyboard;
        [FieldOffset(0)] public MOUSEINPUT mouse;
    }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT {
        public ushort vk, scan; public uint flags, time; public UIntPtr extra;
    }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT {
        public int x,y; public uint data,flags,time; public UIntPtr extra;
    }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr desktop);
    public static bool InputDesktopAvailable() {
        IntPtr desktop = OpenInputDesktop(0, false, 0x0100); // DESKTOP_SWITCHDESKTOP access; no switch performed.
        if (desktop == IntPtr.Zero) return false;
        CloseDesktop(desktop); return true;
    }
    public static uint Chord(ushort[] keys) {
        INPUT[] input = new INPUT[keys.Length * 2];
        for (int i=0; i<keys.Length; i++) {
            input[i].type=1; input[i].data.keyboard.vk=keys[i];
            int up=keys.Length+i; input[up].type=1;
            input[up].data.keyboard.vk=keys[keys.Length-1-i]; input[up].data.keyboard.flags=2;
        }
        return SendInput((uint)input.Length, input, Marshal.SizeOf(typeof(INPUT)));
    }

    [STAThread] public static void Main(string[] args) {
        string log=args[0];
        Action<string> emit = delegate(string s) { File.AppendAllText(log,s+Environment.NewLine); };
        Application.EnableVisualStyles();
        Form form=new Form(); form.Text="Real Narrator capability fixture"; form.Size=new Size(500,240);
        Button alpha=new Button(); alpha.Text="Narrator capability alpha";
        alpha.AccessibleName=alpha.Text; alpha.Location=new Point(20,20); alpha.Size=new Size(410,45); alpha.TabIndex=0;
        CheckBox beta=new CheckBox(); beta.Text="Narrator capability beta";
        beta.AccessibleName=beta.Text; beta.Location=new Point(20,85); beta.Size=new Size(410,45); beta.TabIndex=1;
        alpha.GotFocus += delegate { emit("focus=alpha"); };
        beta.GotFocus += delegate { emit("focus=beta"); };
        alpha.Click += delegate { emit("clicked=alpha"); };
        beta.CheckedChanged += delegate { emit("checked="+beta.Checked.ToString().ToLowerInvariant()); };
        form.Controls.Add(alpha); form.Controls.Add(beta);
        form.Shown += delegate { alpha.Focus(); emit("ready"); };
        System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer(); timer.Interval=55000;
        timer.Tick += delegate { form.Close(); }; timer.Start();
        Application.Run(form);
    }
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class DeviceEnumerator {}
[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int flow, uint mask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice device);
}
[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, uint context, IntPtr activation, [MarshalAs(UnmanagedType.IUnknown)] out object value);
    [PreserveSig] int OpenPropertyStore(uint access, out IntPtr properties);
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    [PreserveSig] int GetState(out uint state);
}
[ComImport, Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioClient {
    [PreserveSig] int Initialize(int shareMode, uint flags, long duration, long periodicity, IntPtr format, IntPtr session);
    [PreserveSig] int GetBufferSize(out uint frames);
    [PreserveSig] int GetStreamLatency(out long latency);
    [PreserveSig] int GetCurrentPadding(out uint frames);
    [PreserveSig] int IsFormatSupported(int mode, IntPtr format, out IntPtr closest);
    [PreserveSig] int GetMixFormat(out IntPtr format);
    [PreserveSig] int GetDevicePeriod(out long normal, out long minimum);
    [PreserveSig] int Start();
    [PreserveSig] int Stop();
    [PreserveSig] int Reset();
    [PreserveSig] int SetEventHandle(IntPtr handle);
    [PreserveSig] int GetService(ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object service);
}
[ComImport, Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioCaptureClient {
    [PreserveSig] int GetBuffer(out IntPtr data, out uint frames, out uint flags, out ulong device, out ulong counter);
    [PreserveSig] int ReleaseBuffer(uint frames);
    [PreserveSig] int GetNextPacketSize(out uint frames);
}

public sealed class AtLoopback : IDisposable {
    IAudioClient client; IAudioCaptureClient capture; IMMDevice endpoint; IMMDeviceEnumerator enumerator;
    FileStream file; BinaryWriter writer; int blockAlign; int formatTag; int bits; int channels;
    uint rate; long bytes; double sumSquares; long samples; public string EndpointId;
    public long Frames { get { return blockAlign==0 ? 0 : bytes/blockAlign; } }
    public double Rms { get { return samples==0 ? 0 : Math.Sqrt(sumSquares/samples); } }
    static void Check(int code) { if(code<0) Marshal.ThrowExceptionForHR(code); }
    public AtLoopback(string path) {
        IntPtr format=IntPtr.Zero;
        try {
            enumerator=(IMMDeviceEnumerator)new DeviceEnumerator();
            Check(enumerator.GetDefaultAudioEndpoint(0,0,out endpoint));
            Check(endpoint.GetId(out EndpointId));
            Guid id=typeof(IAudioClient).GUID; object value;
            Check(endpoint.Activate(ref id,23,IntPtr.Zero,out value)); client=(IAudioClient)value;
            Check(client.GetMixFormat(out format));
            formatTag=(ushort)Marshal.ReadInt16(format,0); channels=(ushort)Marshal.ReadInt16(format,2);
            rate=(uint)Marshal.ReadInt32(format,4); blockAlign=(ushort)Marshal.ReadInt16(format,12);
            bits=(ushort)Marshal.ReadInt16(format,14);
            int extra=(ushort)Marshal.ReadInt16(format,16); int formatLength=18+extra;
            byte[] formatBytes=new byte[formatLength]; Marshal.Copy(format,formatBytes,0,formatLength);
            if(formatTag==0xfffe && extra>=22) formatTag=Marshal.ReadInt32(format,24);
            if(!((formatTag==3 && bits==32) || (formatTag==1 && bits==16)))
                throw new NotSupportedException("Probe supports PCM16 or float32 endpoint mix formats only");
            Check(client.Initialize(0,0x20000,1000000,0,format,IntPtr.Zero)); // shared WASAPI loopback
            id=typeof(IAudioCaptureClient).GUID; Check(client.GetService(ref id,out value));
            capture=(IAudioCaptureClient)value;
            file=new FileStream(path,FileMode.Create,FileAccess.Write,FileShare.Read);
            writer=new BinaryWriter(file);
            writer.Write(System.Text.Encoding.ASCII.GetBytes("RIFF")); writer.Write(0);
            writer.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt ")); writer.Write(formatLength);
            writer.Write(formatBytes); writer.Write(System.Text.Encoding.ASCII.GetBytes("data")); writer.Write(0);
            Check(client.Start());
        } catch { Dispose(); throw; }
        finally { if(format!=IntPtr.Zero) Marshal.FreeCoTaskMem(format); }
    }
    public void Drain() {
        uint count; Check(capture.GetNextPacketSize(out count));
        // Cap a single drain so malformed/device-busy behavior cannot spin forever.
        for(int packet=0; count>0 && packet<100; packet++) {
            IntPtr data; uint frames, flags; ulong device,counter;
            Check(capture.GetBuffer(out data,out frames,out flags,out device,out counter));
            try {
                byte[] buffer=new byte[checked((int)frames*blockAlign)];
                if((flags&2)==0) Marshal.Copy(data,buffer,0,buffer.Length);
                writer.Write(buffer); bytes+=buffer.Length;
                for(int i=0;i<buffer.Length;i+=bits/8) {
                    double value = formatTag==3 ? BitConverter.ToSingle(buffer,i) : BitConverter.ToInt16(buffer,i)/32768.0;
                    if(!Double.IsNaN(value) && !Double.IsInfinity(value)) { sumSquares+=value*value; samples++; }
                }
            } finally { Check(capture.ReleaseBuffer(frames)); }
            Check(capture.GetNextPacketSize(out count));
        }
    }
    public void Dispose() {
        if(client!=null) { try { client.Stop(); } catch {} }
        if(writer!=null) {
            long length=file.Length; writer.Seek(4,SeekOrigin.Begin); writer.Write((uint)(length-8));
            writer.Seek((int)(length-bytes-4),SeekOrigin.Begin); writer.Write((uint)bytes);
            writer.Dispose(); writer=null;
        }
        if(capture!=null) { Marshal.ReleaseComObject(capture); capture=null; }
        if(client!=null) { Marshal.ReleaseComObject(client); client=null; }
        if(endpoint!=null) { Marshal.ReleaseComObject(endpoint); endpoint=null; }
        if(enumerator!=null) { Marshal.ReleaseComObject(enumerator); enumerator=null; }
    }
}
'@

$recording = $null
try {
    if ($env:GITHUB_ACTIONS -ne 'true' -and -not $AllowLocal) { throw 'CI-only probe: GITHUB_ACTIONS=true or explicit -AllowLocal is required' }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 (powershell.exe -STA), not pwsh' }
    if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'The clipboard probe requires powershell.exe -STA' }
    if (Get-Process -Name Narrator -ErrorAction SilentlyContinue) { throw 'An existing Narrator process is present; refusing to replace or terminate it' }
    Add-Type -AssemblyName System.Windows.Forms, UIAutomationClient, UIAutomationTypes
    Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms, System.Drawing
    $report.evidence.input_desktop_available = [AtCapability]::InputDesktopAvailable()
    if (-not $report.evidence.input_desktop_available) { throw 'Cannot open the interactive input desktop' }
    $narratorPath = Join-Path $env:WINDIR 'System32\Narrator.exe'
    if (-not (Test-Path $narratorPath)) { throw 'Narrator.exe is unavailable' }
    $report.runtime.narrator_path = $narratorPath
    $report.runtime.narrator_version = (Get-Item $narratorPath).VersionInfo.FileVersion
    $report.evidence.audio_services = @(Get-Service Audiosrv, AudioEndpointBuilder -ErrorAction SilentlyContinue | Select-Object Name, Status)

    $sourcePath = Join-Path $temporary 'fixture.cs'
    $fixturePath = Join-Path $temporary 'fixture.exe'
    [IO.File]::WriteAllText($sourcePath, $source)
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $compiler)) { throw 'The .NET Framework C# compiler is unavailable' }
    $compile = Start-Process $compiler -ArgumentList @('/nologo', '/target:winexe', ('/out:"' + $fixturePath + '"'), '/r:System.Windows.Forms.dll', '/r:System.Drawing.dll', ('"' + $sourcePath + '"')) -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $output 'compile.log') -RedirectStandardError (Join-Path $output 'compile-error.log')
    $owned.Add($compile)
    Wait-Probe { $compile.Refresh(); $compile.HasExited } 8
    if ($compile.ExitCode -ne 0) { throw 'Fixture compilation failed; see compile logs' }
    $events = Join-Path $output 'fixture-events.log'
    [IO.File]::WriteAllText($events, '')
    $fixture = Start-Process $fixturePath -ArgumentList ('"' + $events + '"') -PassThru
    $owned.Add($fixture)
    Wait-Probe { (Test-Path $events) -and ([IO.File]::ReadAllText($events).Contains('ready')) }
    $fixture.Refresh()
    $window = $fixture.MainWindowHandle
    [AtCapability]::SetForegroundWindow($window) | Out-Null
    Wait-Probe { [AtCapability]::GetForegroundWindow() -eq $window }
    $report.evidence.fixture_session_id = $fixture.SessionId
    $root = [Windows.Automation.AutomationElement]::FromHandle($window)
    $controls = @()
    foreach ($name in @('Narrator capability alpha', 'Narrator capability beta')) {
        $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, $name)
        $element = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
        if ($null -ne $element) { $controls += @{ name = $element.Current.Name; type = $element.Current.ControlType.ProgrammaticName } }
    }
    if ($controls.Count -eq 2) { Observe 'native_accessibility' @{ controls = $controls; source = 'UI Automation' } }
    $count = [AtCapability]::Chord([ushort[]]@(0x09))
    $report.evidence.keyboard_events_inserted = $count
    Wait-Probe { [IO.File]::ReadAllText($events).Contains('focus=beta') }
    [AtCapability]::Chord([ushort[]]@(0x20)) | Out-Null
    Wait-Probe { [IO.File]::ReadAllText($events).Contains('checked=true') }
    $report.evidence.interactive_keyboard_response = 'Tab focused beta and Space toggled the native checkbox'

    Assert-Time
    $narrator = Start-Process $narratorPath -PassThru
    $owned.Add($narrator)
    Start-Sleep -Milliseconds 2200
    $narrator.Refresh()
    if ($narrator.HasExited) { throw 'The owned Narrator process exited; no arbitrary replacement process will be adopted' }
    $report.evidence.narrator_pid = $narrator.Id
    $report.evidence.narrator_session_id = $narrator.SessionId
    [AtCapability]::SetForegroundWindow($window) | Out-Null
    Wait-Probe { [AtCapability]::GetForegroundWindow() -eq $window }
    try {
        $recording = New-Object AtLoopback((Join-Path $output 'narrator-task.wav'))
        $report.evidence.audio_endpoint = $recording.EndpointId
    } catch {
        $report.layers.synthesized_audio.reason = 'No usable loopback audio endpoint: ' + $_.Exception.Message
        $report.errors += $report.layers.synthesized_audio.reason
    }

    # Narrator+Tab reads the current item. Then Narrator+Ctrl+X copies its own
    # most recent utterance; unsupported builds leave our sentinel unchanged.
    [Windows.Forms.Clipboard]::SetText('probe-no-narrator-output')
    [AtCapability]::Chord([ushort[]]@(0x2D, 0x09)) | Out-Null
    $until = [Math]::Min($Seconds, $started.Elapsed.TotalSeconds + 4)
    do {
        if ($null -ne $recording) { $recording.Drain() }
        Start-Sleep -Milliseconds 100
    } while ($started.Elapsed.TotalSeconds -lt $until)
    [AtCapability]::Chord([ushort[]]@(0x2D, 0x11, 0x58)) | Out-Null
    Start-Sleep -Milliseconds 350
    $utterance = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText((Join-Path $output 'narrator-utterance.txt'), $utterance)
    $spoken = $utterance -match 'Narrator capability beta'
    if ($spoken) {
        Observe 'utterance_output' @{ source = 'Narrator copy-last-phrase command'; utterance = $utterance; limitation = 'Transcript alone does not establish audio playback' }
    } else {
        $report.layers.utterance_output.reason = 'Narrator copy-last-phrase did not return the fixture control; the installed build may not support this command'
    }
    $beforeInvoke = [IO.File]::ReadAllText($events)
    [AtCapability]::Chord([ushort[]]@(0x2D, 0x0D)) | Out-Null # Narrator invoke, not UIA InvokePattern.
    $until = [Math]::Min($Seconds, $started.Elapsed.TotalSeconds + 3)
    do {
        if ($null -ne $recording) { $recording.Drain() }
        Start-Sleep -Milliseconds 100
    } while ($started.Elapsed.TotalSeconds -lt $until)
    $afterInvoke = [IO.File]::ReadAllText($events)
    if ($spoken -and $afterInvoke.Substring($beforeInvoke.Length).Contains('checked=false')) {
        Observe 'at_navigation' @{ commands = @('Narrator+Tab', 'Narrator+Enter'); response = 'Narrator read beta and invoked its checkbox action'; limitation = 'Native fixture only; no Flutter task acceptance' }
    }
    if ($null -ne $recording) {
        $recording.Drain()
        $audio = @{ frames = $recording.Frames; rms = $recording.Rms; source = 'WASAPI render endpoint loopback during Narrator fixture commands' }
        $report.evidence.audio = $audio
        if ($spoken -and $recording.Frames -gt 1600 -and $recording.Rms -gt 0.0005) {
            Observe 'synthesized_audio' @{ frames = $recording.Frames; rms = $recording.Rms; capture = 'narrator-task.wav'; limitation = 'Endpoint-wide PCM during Narrator commands; human review must verify attribution, words and intelligibility' }
        }
    }
    $machineLayers = @('native_accessibility', 'at_navigation', 'utterance_output', 'synthesized_audio')
    if (@($machineLayers | Where-Object { $report.layers[$_].status -ne 'observed' }).Count -eq 0) {
        $report.status = 'capability_observed'
    }
} catch {
    $report.errors += $_.Exception.Message
    $report.status = 'not_accepted'
} finally {
    if ($null -ne $recording) {
        try { $recording.Dispose() }
        catch {
            $report.errors += ('Audio cleanup: ' + $_.Exception.Message)
            $report.status = 'not_accepted'
        }
    }
    for ($i = $owned.Count - 1; $i -ge 0; $i--) {
        try {
            $process = $owned[$i]
            $process.Refresh()
            if (-not $process.HasExited) {
                $process.Kill()
                if (-not $process.WaitForExit(1000)) { throw 'Owned process did not exit within the cleanup deadline' }
            }
        } catch {
            $report.errors += ('Owned process cleanup: ' + $_.Exception.Message)
            $report.status = 'not_accepted'
        }
    }
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
    $report.layers.human_review = @{ status = 'not_accepted'; reason = 'No human listened or completed a Flutter task' }
    $report.elapsed_seconds = [Math]::Round($started.Elapsed.TotalSeconds, 3)
    $json = $report | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText((Join-Path $output 'report.json'), $json)
    Write-Output $json
}
if ($report.status -eq 'capability_observed') { exit 0 }
exit 2
