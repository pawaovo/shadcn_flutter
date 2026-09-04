# Native profile timeout and evidence recovery validation

The recorder now enforces real frame deadlines, stops further input after a
pending SDK Future times out, and preserves independent frame/RSS evidence and
the original failure before cleanup. The host has a real 25-minute transport
bound, durable checkpoint acknowledgement and explicit failed partial recovery.
Flutter compilation and native-process shutdown are outside that host bound.

[The exact validation manifest](validation.json) records the 19 reviewed source
hashes and original log hashes. The copied logs retain their original bytes;
only those evidence logs have a whitespace-check exemption. The headless checks
pass **68/68**: 40 recorder/guard/pointer/environment/helper/workload checks,
21 host/writer checks and seven timeline codec checks. The deliberately restored
old pointer replay fails three late-continuation checks; the guarded source was
restored byte-for-byte. Analysis passes and formatting changes zero files.

These results validate failure handling and the existing workloads in headless
execution. They do not claim a new native profile or a performance-budget pass.
The real native baseline interruption and the separate f15f27eb P3 budget pass
remain recorded with their original source and evidence.
