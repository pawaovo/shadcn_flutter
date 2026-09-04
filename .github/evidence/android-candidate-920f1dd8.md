# Android candidate diagnostic — 920f1dd8

The [single manual run 33858129746](https://github.com/pawaovo/shadcn_flutter/actions/runs/33858129746)
at exact source `920f1dd88510da3847187b616cd0a4f25ddbe740` **failed during
helper APK compilation**. It did not reach native candidate input, draft commit,
input tracing or the original full native journey. This is a build failure, not
an observed IME or product failure. No run was retried.

Before that failure, the real Ubuntu job passed 10 host protocol tests, three
build-process cleanup tests, 36 Dart protocol/original helper tests and Dart
analysis. The actual Java 17 JVM compiled and ran `ProtocolTest`, passing
**36 checks** with exit 0.

The next command used `javac 17.0.20.1`, Java source/target 8 and the strict
Android 35 `android.jar` bootclasspath. It failed at
`ProbeInstrumentation.java:77`, the watchdog's `new Thread(() -> { ... })`:

```text
cannot find symbol
symbol: method metafactory(Lookup,String,MethodType,MethodType,MethodHandle,MethodType)
location: interface LambdaMetafactory
Fatal Error: Unable to find method metafactory
```

The original javac exit code was **3**; its owned process-group cleanup was
verified. No APK was produced or installed. The emulator action's finalizer
issued `adb -s emulator-5554 emu kill`, received `OK: killing emulator, bye bye`,
and completed. The native candidate supervisor never started.

The root-authorized next patch changes only the watchdog lambda to an equivalent
anonymous `Runnable`. It retains the Android API bootclasspath, all behavior,
deadlines and task assertions. That change still requires actual Android
compilation in a new source/run; it does not change this failed result.

The [JSON evidence](android-candidate-920f1dd8.json) contains exact run/job and
artifact metadata, the original build error, the job-log hash and hashes of all
nine extracted artifact files. The artifact was downloaded once. GitHub's ZIP
digest is retained as server metadata; the extracted files were hashed locally.
Raw evidence is retained under
`/tmp/beautiful-android-candidate-920f1dd8-33858129746`.
