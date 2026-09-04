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
using System.Collections.Generic;
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
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
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
        System.Diagnostics.Stopwatch clock=System.Diagnostics.Stopwatch.StartNew();
        Action<string> emit = delegate(string s) {
            File.AppendAllText(log,DateTime.UtcNow.ToString("o")+" elapsed_ms="+
                clock.ElapsedMilliseconds+" "+s+Environment.NewLine);
        };
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

public sealed class AtOwnedWindowState {
    public int owner_pid, native_owner_pid;
    public long native_window_handle;
    public bool owner_alive, pattern_available, can_minimize, is_modal, ready;
    public bool minimized, hidden;
}
public sealed class AtWindowPreparation {
    public bool minimize_started;
    public AtOwnedWindowState before, after;
}
public static class AtWindowGuard {
    static void RequireOwner(int expectedPid, AtOwnedWindowState state) {
        if(state==null || expectedPid<=0 || !state.owner_alive ||
            state.owner_pid!=expectedPid || state.native_owner_pid!=expectedPid)
            throw new InvalidOperationException("Narrator window ownership was not verified");
    }
    public static void Prepare(int expectedPid, Func<AtOwnedWindowState> readBefore,
        Action minimize, Func<AtOwnedWindowState> readAfter, AtWindowPreparation result) {
        result.before=readBefore();
        RequireOwner(expectedPid,result.before);
        if(!result.before.pattern_available || !result.before.can_minimize ||
            result.before.is_modal || !result.before.ready)
            throw new InvalidOperationException("Owned Narrator window does not support safe minimization");
        if(!result.before.minimized && !result.before.hidden) {
            result.minimize_started=true;
            minimize(); // Once only. A failed action or observation is never retried.
        }
        result.after=readAfter();
        RequireOwner(expectedPid,result.after);
        if(!result.after.minimized && !result.after.hidden)
            throw new InvalidOperationException("Owned Narrator window remained visible after preparation");
    }
}
public sealed class AtFixtureFocus {
    public int process_id;
    public bool fixture_alive, fixture_foreground, has_keyboard_focus;
    public string control_name;
}
public sealed class AtInputAttempt {
    public bool send_started;
    public AtFixtureFocus focus;
}
public static class AtInputGuard {
    static void Validate(int expectedPid, string expectedName, AtFixtureFocus focus) {
        if(focus==null || expectedPid<=0 || String.IsNullOrEmpty(expectedName) ||
            !focus.fixture_alive || !focus.fixture_foreground || !focus.has_keyboard_focus ||
            focus.process_id!=expectedPid || focus.control_name!=expectedName)
            throw new InvalidOperationException("Actual fixture focus was not verified for "+expectedName);
    }
    public static AtFixtureFocus RequireFocus(int expectedPid, string expectedName,
        Func<AtFixtureFocus> observe) {
        AtFixtureFocus focus=observe();
        Validate(expectedPid,expectedName,focus);
        return focus;
    }
    public static uint Send(int expectedPid, string expectedName, Func<AtFixtureFocus> observe,
        Func<uint> send, AtInputAttempt attempt) {
        attempt.focus=observe();
        Validate(expectedPid,expectedName,attempt.focus);
        attempt.send_started=true;
        return send();
    }
    public static uint Chord(int expectedPid, string expectedName, Func<AtFixtureFocus> observe,
        ushort[] keys, AtInputAttempt attempt) {
        return Send(expectedPid,expectedName,observe,delegate { return AtCapability.Chord(keys); },attempt);
    }
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class DeviceEnumerator {}
[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int flow, uint mask, out IMMDeviceCollection devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice device);
}
// Windows SDK mmdeviceapi.h: GetCount then Item, following IUnknown.
[ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceCollection {
    [PreserveSig] int GetCount(out uint count);
    [PreserveSig] int Item(uint index, out IMMDevice device);
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

public sealed class AtAudioCall {
    public string stage, utc, hresult_hex, exception_type;
    public int hresult;
}
public sealed class AtAudioEndpoint {
    public string role, id, error;
    public uint? state;
}
public sealed class AtAudioInventory {
    public string flow="eRender", state_mask="DEVICE_STATEMASK_ALL (0xF)", error;
    public uint? endpoint_count;
    public List<AtAudioEndpoint> endpoints=new List<AtAudioEndpoint>();
    public List<AtAudioEndpoint> defaults=new List<AtAudioEndpoint>();
}
public static class AtAudioDiagnostics {
    public static readonly List<AtAudioCall> Calls=new List<AtAudioCall>();
    static void Record(string stage, int code, Exception error) {
        Calls.Add(new AtAudioCall { stage=stage, utc=DateTime.UtcNow.ToString("o"),
            hresult=code, hresult_hex="0x"+unchecked((uint)code).ToString("X8"),
            exception_type=error==null ? null : error.GetType().FullName });
    }
    public static void Call(string stage, Func<int> operation, bool recordSuccess=true) {
        int code;
        try { code=operation(); }
        catch(Exception error) { Record(stage,Marshal.GetHRForException(error),error); throw; }
        if(recordSuccess || code<0) Record(stage,code,null);
        if(code<0) throw new COMException(stage+" failed (0x"+
            unchecked((uint)code).ToString("X8")+")",code);
    }
    internal static IMMDeviceEnumerator CreateEnumerator(string scope) {
        IMMDeviceEnumerator result=null;
        Call(scope+".CoCreateInstance(MMDeviceEnumerator)",delegate {
            result=(IMMDeviceEnumerator)new DeviceEnumerator(); return 0;
        });
        return result;
    }
    static void ReadEndpoint(IMMDevice device, string scope, AtAudioEndpoint item) {
        string id=null; uint state=0;
        Call(scope+".IMMDevice.GetId",delegate { return device.GetId(out id); });
        item.id=id;
        Call(scope+".IMMDevice.GetState",delegate { return device.GetState(out state); });
        item.state=state;
    }
    // Read-only render metadata. Never opens a property store, changes a default,
    // activates an audio client, or captures microphone/audio samples.
    public static AtAudioInventory Inventory() {
        AtAudioInventory report=new AtAudioInventory();
        IMMDeviceEnumerator enumerator=null; IMMDeviceCollection devices=null;
        try {
            enumerator=CreateEnumerator("inventory");
            try {
                Call("inventory.EnumAudioEndpoints(eRender,0xF)",delegate {
                    return enumerator.EnumAudioEndpoints(0,0xF,out devices);
                });
                uint count=0;
                Call("inventory.IMMDeviceCollection.GetCount",delegate { return devices.GetCount(out count); });
                report.endpoint_count=count;
                for(uint index=0;index<count;index++) {
                    IMMDevice device=null; AtAudioEndpoint item=new AtAudioEndpoint();
                    report.endpoints.Add(item);
                    string scope="inventory.endpoint["+index+"]";
                    try {
                        Call(scope+".IMMDeviceCollection.Item",delegate { return devices.Item(index,out device); });
                        ReadEndpoint(device,scope,item);
                    } catch(Exception error) { item.error=error.Message; }
                    finally { if(device!=null) Marshal.ReleaseComObject(device); }
                }
            } catch(Exception error) { report.error=error.Message; }
            string[] roles={"eConsole","eMultimedia","eCommunications"};
            for(int role=0;role<roles.Length;role++) {
                IMMDevice device=null; AtAudioEndpoint item=new AtAudioEndpoint { role=roles[role] };
                report.defaults.Add(item);
                string scope="inventory.default["+item.role+"]";
                try {
                    Call(scope+".GetDefaultAudioEndpoint(eRender)",delegate {
                        return enumerator.GetDefaultAudioEndpoint(0,role,out device);
                    });
                    ReadEndpoint(device,scope,item);
                } catch(Exception error) { item.error=error.Message; }
                finally { if(device!=null) Marshal.ReleaseComObject(device); }
            }
        } catch(Exception error) { report.error=error.Message; }
        finally {
            if(devices!=null) Marshal.ReleaseComObject(devices);
            if(enumerator!=null) Marshal.ReleaseComObject(enumerator);
        }
        return report;
    }
}

public sealed class AtLoopback : IDisposable {
    IAudioClient client; IAudioCaptureClient capture; IMMDevice endpoint; IMMDeviceEnumerator enumerator;
    FileStream file; BinaryWriter writer; int blockAlign; int formatTag; int bits; int channels;
    uint rate; long bytes; double sumSquares; long samples; public string EndpointId;
    public long Frames { get { return blockAlign==0 ? 0 : bytes/blockAlign; } }
    public double Rms { get { return samples==0 ? 0 : Math.Sqrt(sumSquares/samples); } }
    public AtLoopback(string path) {
        IntPtr format=IntPtr.Zero;
        try {
            enumerator=AtAudioDiagnostics.CreateEnumerator("capture");
            AtAudioDiagnostics.Call("capture.GetDefaultAudioEndpoint(eRender,eConsole)",delegate {
                return enumerator.GetDefaultAudioEndpoint(0,0,out endpoint);
            });
            AtAudioDiagnostics.Call("capture.IMMDevice.GetId",delegate { return endpoint.GetId(out EndpointId); });
            Guid id=typeof(IAudioClient).GUID; object value;
            value=null;
            AtAudioDiagnostics.Call("capture.IMMDevice.Activate(IAudioClient)",delegate {
                return endpoint.Activate(ref id,23,IntPtr.Zero,out value);
            }); client=(IAudioClient)value;
            AtAudioDiagnostics.Call("capture.IAudioClient.GetMixFormat",delegate { return client.GetMixFormat(out format); });
            formatTag=(ushort)Marshal.ReadInt16(format,0); channels=(ushort)Marshal.ReadInt16(format,2);
            rate=(uint)Marshal.ReadInt32(format,4); blockAlign=(ushort)Marshal.ReadInt16(format,12);
            bits=(ushort)Marshal.ReadInt16(format,14);
            int extra=(ushort)Marshal.ReadInt16(format,16); int formatLength=18+extra;
            byte[] formatBytes=new byte[formatLength]; Marshal.Copy(format,formatBytes,0,formatLength);
            if(formatTag==0xfffe && extra>=22) formatTag=Marshal.ReadInt32(format,24);
            if(!((formatTag==3 && bits==32) || (formatTag==1 && bits==16)))
                throw new NotSupportedException("Probe supports PCM16 or float32 endpoint mix formats only");
            AtAudioDiagnostics.Call("capture.IAudioClient.Initialize(shared,loopback)",delegate {
                return client.Initialize(0,0x20000,1000000,0,format,IntPtr.Zero);
            }); // same original shared WASAPI loopback endpoint and configuration
            id=typeof(IAudioCaptureClient).GUID;
            AtAudioDiagnostics.Call("capture.IAudioClient.GetService(IAudioCaptureClient)",delegate {
                return client.GetService(ref id,out value);
            });
            capture=(IAudioCaptureClient)value;
            file=new FileStream(path,FileMode.Create,FileAccess.Write,FileShare.Read);
            writer=new BinaryWriter(file);
            writer.Write(System.Text.Encoding.ASCII.GetBytes("RIFF")); writer.Write(0);
            writer.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt ")); writer.Write(formatLength);
            writer.Write(formatBytes); writer.Write(System.Text.Encoding.ASCII.GetBytes("data")); writer.Write(0);
            AtAudioDiagnostics.Call("capture.IAudioClient.Start",delegate { return client.Start(); });
        } catch { Dispose(); throw; }
        finally { if(format!=IntPtr.Zero) Marshal.FreeCoTaskMem(format); }
    }
    public void Drain() {
        uint count=0;
        AtAudioDiagnostics.Call("capture.IAudioCaptureClient.GetNextPacketSize",delegate { return capture.GetNextPacketSize(out count); },false);
        // Cap a single drain so malformed/device-busy behavior cannot spin forever.
        for(int packet=0; count>0 && packet<100; packet++) {
            IntPtr data=IntPtr.Zero; uint frames=0,flags=0; ulong device=0,counter=0;
            AtAudioDiagnostics.Call("capture.IAudioCaptureClient.GetBuffer",delegate {
                return capture.GetBuffer(out data,out frames,out flags,out device,out counter);
            },false);
            try {
                byte[] buffer=new byte[checked((int)frames*blockAlign)];
                if((flags&2)==0) Marshal.Copy(data,buffer,0,buffer.Length);
                writer.Write(buffer); bytes+=buffer.Length;
                for(int i=0;i<buffer.Length;i+=bits/8) {
                    double value = formatTag==3 ? BitConverter.ToSingle(buffer,i) : BitConverter.ToInt16(buffer,i)/32768.0;
                    if(!Double.IsNaN(value) && !Double.IsInfinity(value)) { sumSquares+=value*value; samples++; }
                }
            } finally {
                AtAudioDiagnostics.Call("capture.IAudioCaptureClient.ReleaseBuffer",delegate { return capture.ReleaseBuffer(frames); },false);
            }
            AtAudioDiagnostics.Call("capture.IAudioCaptureClient.GetNextPacketSize",delegate { return capture.GetNextPacketSize(out count); },false);
        }
    }
    public void Dispose() {
        if(client!=null) { try { AtAudioDiagnostics.Call("capture.IAudioClient.Stop",delegate { return client.Stop(); }); } catch {} }
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

function Get-FixtureFocus {
    $focus = New-Object AtFixtureFocus
    $fixture.Refresh()
    $focus.fixture_alive = -not $fixture.HasExited
    $focus.fixture_foreground = [AtCapability]::GetForegroundWindow() -eq $window
    $focused = [Windows.Automation.AutomationElement]::FocusedElement
    if ($null -ne $focused) {
        $focus.process_id = $focused.Current.ProcessId
        if ($focus.process_id -eq $fixture.Id) {
            $focus.control_name = $focused.Current.Name
            $focus.has_keyboard_focus = $focused.Current.HasKeyboardFocus
        }
    }
    return $focus
}

function Get-OwnedNarratorWindowState($Element, $Pattern) {
    $state = New-Object AtOwnedWindowState
    $narrator.Refresh()
    $state.owner_alive = -not $narrator.HasExited
    $pidValue = $Element.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::ProcessIdProperty, $true)
    if ($pidValue -eq [Windows.Automation.AutomationElement]::NotSupported) {
        throw 'Owned Narrator window does not report its process ID'
    }
    $state.owner_pid = [int]$pidValue
    $handle = [IntPtr]$Element.Current.NativeWindowHandle
    $state.native_window_handle = $handle.ToInt64()
    [uint32]$windowOwner = 0
    $null = [AtCapability]::GetWindowThreadProcessId($handle, [ref]$windowOwner)
    $state.native_owner_pid = [int]$windowOwner
    $state.hidden = -not [AtCapability]::IsWindowVisible($handle)
    $state.pattern_available = $null -ne $Pattern
    if ($state.pattern_available) {
        $info = $Pattern.Current
        $state.can_minimize = $info.CanMinimize
        $state.is_modal = $info.IsModal
        $state.ready = $info.WindowInteractionState -eq [Windows.Automation.WindowInteractionState]::ReadyForUserInteraction
        $state.minimized = $info.WindowVisualState -eq [Windows.Automation.WindowVisualState]::Minimized
    }
    return $state
}

function Prepare-OwnedNarratorHome {
    $deadline = [Math]::Min($Seconds, $started.Elapsed.TotalSeconds + 8)
    $preparation = [ordered]@{
        status = 'started'; expected_owner_pid = $narrator.Id
        utc_started = [DateTime]::UtcNow.ToString('o')
        deadline_elapsed_seconds = $deadline; minimize_requests = 0; observations = @()
    }
    $report.evidence.narrator_preparation = $preparation
    $result = New-Object AtWindowPreparation
    try {
        $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty, $narrator.Id)
        $candidate = $null
        do {
            $narrator.Refresh()
            if ($narrator.HasExited) { throw 'The owned Narrator process exited during startup preparation' }
            $ownedElements = [Windows.Automation.AutomationElement]::RootElement.FindAll([Windows.Automation.TreeScope]::Children, $condition)
            $windows = @($ownedElements | Where-Object { $_.Current.ControlType -eq [Windows.Automation.ControlType]::Window })
            if ($windows.Count -gt 1) { throw 'Multiple owned Narrator windows were found; no window will be chosen implicitly' }
            if ($windows.Count -eq 1) { $candidate = $windows[0]; break }
            Start-Sleep -Milliseconds 120
        } while ($started.Elapsed.TotalSeconds -lt $deadline)
        if ($null -eq $candidate) { throw 'No top-level window belonging to the owned Narrator PID was observed before the startup deadline' }
        $patternObject = $null
        $hasPattern = $candidate.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern, [ref]$patternObject)
        $pattern = if ($hasPattern) { [Windows.Automation.WindowPattern]$patternObject } else { $null }
        $readBefore = [Func[AtOwnedWindowState]] {
            do {
                if ($started.Elapsed.TotalSeconds -ge $deadline) { throw 'Narrator preparation deadline exceeded before minimization' }
                $state = Get-OwnedNarratorWindowState $candidate $pattern
                $verifiedOwner = $state.owner_alive -and $state.owner_pid -eq $narrator.Id -and $state.native_owner_pid -eq $narrator.Id
                if ($verifiedOwner) { $preparation.owned_window_name = $candidate.Current.Name }
                $preparation.observations += @{ utc = [DateTime]::UtcNow.ToString('o'); state = $state }
                if (-not $verifiedOwner -or -not $state.pattern_available -or -not $state.can_minimize -or $state.is_modal -or $state.ready) {
                    return $state
                }
                # Wait only for a supported owned window to become interactive.
                # No action is retried while the provider finishes startup.
                Start-Sleep -Milliseconds 120
            } while ($true)
        }
        $minimize = [Action] {
            # The guard verified both UIA and native HWND ownership immediately
            # before this single action. It never selects a window by title.
            if ($started.Elapsed.TotalSeconds -ge $deadline) { throw 'Narrator preparation deadline exceeded before the window action' }
            $preparation.minimize_requests++
            $pattern.SetWindowVisualState([Windows.Automation.WindowVisualState]::Minimized)
        }
        $readAfter = [Func[AtOwnedWindowState]] {
            do {
                if ($started.Elapsed.TotalSeconds -ge $deadline) { throw 'Narrator preparation deadline exceeded while verifying the window state' }
                $state = Get-OwnedNarratorWindowState $candidate $pattern
                $preparation.observations += @{ utc = [DateTime]::UtcNow.ToString('o'); state = $state }
                if (-not $state.owner_alive -or $state.owner_pid -ne $narrator.Id -or $state.native_owner_pid -ne $narrator.Id) {
                    throw 'Narrator window ownership changed after minimization'
                }
                if ($state.minimized -or $state.hidden) { return $state }
                Start-Sleep -Milliseconds 120
            } while ($true)
        }
        [AtWindowGuard]::Prepare($narrator.Id, $readBefore, $minimize, $readAfter, $result)
        $preparation.status = 'owned_window_prepared'
    } catch {
        $preparation.status = 'failed'
        $preparation.error = $_.Exception.Message
        throw
    } finally {
        $preparation.result = $result
        $preparation.utc_finished = [DateTime]::UtcNow.ToString('o')
    }
}

function Record-CommandBoundary([string]$Phase, $Inserted = $null) {
    # Only name/type/value information belonging to the owned fixture is read.
    # For any other focused application retain only the fact that focus differs.
    $snapshot = [ordered]@{
        phase = $Phase; utc_started = [DateTime]::UtcNow.ToString('o')
        elapsed_ms_started = $started.ElapsedMilliseconds
        keyboard_events_inserted = $Inserted
    }
    try {
        $snapshot.fixture_foreground = [AtCapability]::GetForegroundWindow() -eq $window
        $focused = [Windows.Automation.AutomationElement]::FocusedElement
        $snapshot.focused_element_is_fixture = $null -ne $focused -and $focused.Current.ProcessId -eq $fixture.Id
        if ($snapshot.focused_element_is_fixture) {
            $snapshot.focused_control = @{
                name = $focused.Current.Name; type = $focused.Current.ControlType.ProgrammaticName
                has_keyboard_focus = $focused.Current.HasKeyboardFocus
            }
        }
        $lines = [IO.File]::ReadAllLines($events)
        $snapshot.fixture_event_count = $lines.Length
        $snapshot.fixture_last_event = if ($lines.Length -gt 0) { $lines[-1] } else { $null }
    } catch {
        $snapshot.observation_error = $_.Exception.GetType().FullName
    }
    $snapshot.utc_finished = [DateTime]::UtcNow.ToString('o')
    $snapshot.elapsed_ms_finished = $started.ElapsedMilliseconds
    $report.evidence.command_trace += $snapshot
}
function Invoke-ProbeChord([string]$Name, [System.UInt16[]]$Keys, [string]$ExpectedControl = 'Narrator capability beta') {
    Record-CommandBoundary ($Name + ':before')
    $attempt = New-Object AtInputAttempt
    $entry = [ordered]@{ command = $Name; expected_control = $ExpectedControl; status = 'started'; attempt = $attempt }
    $report.evidence.input_attempts += $entry
    try {
        Assert-Time
        $inserted = [AtInputGuard]::Chord($fixture.Id, $ExpectedControl, [Func[AtFixtureFocus]] { Get-FixtureFocus }, $Keys, $attempt)
        $entry.status = 'sent'
        $entry.keyboard_events_inserted = $inserted
    } catch {
        $entry.status = if ($attempt.send_started) { 'send_failed' } else { 'input_not_sent' }
        $entry.error = $_.Exception.Message
        Record-CommandBoundary ($Name + ':' + $entry.status)
        throw
    }
    Record-CommandBoundary ($Name + ':after_send') $inserted
    return $inserted
}

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
    $report.evidence.audio_inventory = [AtAudioDiagnostics]::Inventory()
    $report.evidence.audio_capture_policy = 'Original eRender/eConsole shared loopback only; inventory does not choose, activate or create an endpoint.'
    $report.evidence.command_trace = @()
    $report.evidence.input_attempts = @()

    $sourcePath = Join-Path $temporary 'fixture.cs'
    $fixturePath = Join-Path $temporary 'fixture.exe'
    [IO.File]::WriteAllText($sourcePath, $source)
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $compiler)) { throw 'The .NET Framework C# compiler is unavailable' }
    $compile = Start-Process $compiler -ArgumentList @('/nologo', '/target:winexe', ('/out:"' + $fixturePath + '"'), '/r:System.Windows.Forms.dll', '/r:System.Drawing.dll', ('"' + $sourcePath + '"')) -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $output 'compile.log') -RedirectStandardError (Join-Path $output 'compile-error.log')
    $owned.Add($compile)
    # Windows PowerShell 5.1 can lose ExitCode for a redirected Start-Process
    # unless its real process handle is retained before it exits. Waiting after
    # exit does not recover it: https://github.com/PowerShell/PowerShell/issues/5421
    $null = $compile.Handle
    Wait-Probe { $compile.Refresh(); $compile.HasExited } 8
    $compileExit = $compile.ExitCode
    $fixtureExists = Test-Path -LiteralPath $fixturePath -PathType Leaf
    $fixtureBytes = if ($fixtureExists) { (Get-Item -LiteralPath $fixturePath).Length } else { 0 }
    $report.evidence.fixture_compilation = @{
        compiler = $compiler; exit_code = $compileExit
        executable_exists = $fixtureExists; executable_bytes = $fixtureBytes
    }
    if ($null -eq $compileExit -or $compileExit -ne 0 -or $fixtureBytes -le 0) {
        throw 'Fixture compilation was not verified; see fixture_compilation evidence and compile logs'
    }
    $events = Join-Path $output 'fixture-events.log'
    [IO.File]::WriteAllText($events, '')
    $fixture = Start-Process $fixturePath -ArgumentList ('"' + $events + '"') -PassThru
    $owned.Add($fixture)
    $null = $fixture.Handle
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
    $count = Invoke-ProbeChord 'ordinary Tab' ([System.UInt16[]]@(0x09)) 'Narrator capability alpha'
    $report.evidence.keyboard_events_inserted = $count
    Wait-Probe { [IO.File]::ReadAllText($events).Contains('focus=beta') }
    Record-CommandBoundary 'ordinary Tab:response_observed'
    Invoke-ProbeChord 'ordinary Space' ([System.UInt16[]]@(0x20)) | Out-Null
    Wait-Probe { [IO.File]::ReadAllText($events).Contains('checked=true') }
    Record-CommandBoundary 'ordinary Space:response_observed'
    $report.evidence.interactive_keyboard_response = 'Tab focused beta and Space toggled the native checkbox'

    Assert-Time
    $narrator = Start-Process $narratorPath -PassThru
    $owned.Add($narrator)
    $null = $narrator.Handle
    $narrator.Refresh()
    if ($narrator.HasExited) { throw 'The owned Narrator process exited; no arbitrary replacement process will be adopted' }
    $report.evidence.narrator_pid = $narrator.Id
    $report.evidence.narrator_session_id = $narrator.SessionId
    Prepare-OwnedNarratorHome
    # One startup preparation. Commands below never refocus or retry after a
    # lost-focus guard fails, and they still use Narrator's own invocation.
    [AtCapability]::SetForegroundWindow($window) | Out-Null
    Wait-Probe { [AtCapability]::GetForegroundWindow() -eq $window }
    $betaCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, 'Narrator capability beta')
    $beta = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $betaCondition)
    if ($null -eq $beta -or $beta.Current.ProcessId -ne $fixture.Id) { throw 'The owned fixture beta control was not found after Narrator preparation' }
    $beta.SetFocus()
    Wait-Probe {
        $focus = Get-FixtureFocus
        $focus.fixture_alive -and $focus.fixture_foreground -and $focus.process_id -eq $fixture.Id -and
            $focus.has_keyboard_focus -and $focus.control_name -eq 'Narrator capability beta'
    }
    $report.evidence.narrator_preparation.fixture_focus_prepared = $true
    Record-CommandBoundary 'Narrator startup:fixture_focus_prepared'
    try {
        $recording = New-Object AtLoopback((Join-Path $output 'narrator-task.wav'))
        $report.evidence.audio_endpoint = $recording.EndpointId
    } catch {
        $report.layers.synthesized_audio.reason = 'No usable loopback audio endpoint: ' + $_.Exception.Message
        $report.errors += $report.layers.synthesized_audio.reason
    }

    # Narrator+Tab reads the current item. Then Narrator+Ctrl+X copies its own
    # most recent utterance. Focus guards prevent sending to a different window.
    $null = [AtInputGuard]::RequireFocus($fixture.Id, 'Narrator capability beta', [Func[AtFixtureFocus]] { Get-FixtureFocus })
    [Windows.Forms.Clipboard]::SetText('probe-no-narrator-output')
    Invoke-ProbeChord 'Narrator+Tab' ([System.UInt16[]]@(0x2D, 0x09)) | Out-Null
    $until = [Math]::Min($Seconds, $started.Elapsed.TotalSeconds + 4)
    do {
        if ($null -ne $recording) { $recording.Drain() }
        Start-Sleep -Milliseconds 100
    } while ($started.Elapsed.TotalSeconds -lt $until)
    Record-CommandBoundary 'Narrator+Tab:observation_window_finished'
    Invoke-ProbeChord 'Narrator+Ctrl+X' ([System.UInt16[]]@(0x2D, 0x11, 0x58)) | Out-Null
    Start-Sleep -Milliseconds 350
    $null = [AtInputGuard]::RequireFocus($fixture.Id, 'Narrator capability beta', [Func[AtFixtureFocus]] { Get-FixtureFocus })
    $utterance = [Windows.Forms.Clipboard]::GetText()
    Record-CommandBoundary 'Narrator+Ctrl+X:clipboard_observed'
    [IO.File]::WriteAllText((Join-Path $output 'narrator-utterance.txt'), $utterance)
    $spoken = $utterance -match 'Narrator capability beta'
    if ($spoken) {
        Observe 'utterance_output' @{ source = 'Narrator copy-last-phrase command'; utterance = $utterance; limitation = 'Transcript alone does not establish audio playback' }
    } else {
        $report.layers.utterance_output.reason = 'Narrator copy-last-phrase did not return the expected fixture control; inspect the recorded utterance and focus boundaries'
    }
    $beforeInvoke = [IO.File]::ReadAllText($events)
    Invoke-ProbeChord 'Narrator+Enter' ([System.UInt16[]]@(0x2D, 0x0D)) | Out-Null # Narrator invoke, not UIA InvokePattern.
    $until = [Math]::Min($Seconds, $started.Elapsed.TotalSeconds + 3)
    do {
        if ($null -ne $recording) { $recording.Drain() }
        Start-Sleep -Milliseconds 100
    } while ($started.Elapsed.TotalSeconds -lt $until)
    $afterInvoke = [IO.File]::ReadAllText($events)
    Record-CommandBoundary 'Narrator+Enter:observation_window_finished'
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
    if ('AtAudioDiagnostics' -as [type]) {
        $report.evidence.audio_com_calls = [AtAudioDiagnostics]::Calls.ToArray()
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
