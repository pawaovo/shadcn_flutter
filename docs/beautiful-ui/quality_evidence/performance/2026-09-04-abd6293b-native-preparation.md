# Native all-suite preparation at abd6293b

This run produced **no workload measurements**. Computer Use reported that the
Mac was locked and could not be automatically unlocked, so the Start button was
not operated. The original 120-second preparation deadline expired and the
workload precondition correctly failed. No lock-screen bypass or synthetic
activation was used.

The new host transport connected to the actual native VM, subscribed to its
extension stream, received the failed test response, and saved independent
failure artifacts. The runner finalized with exit 1 and verified unchanged
source manifests. No checkpoint or measured scenario was produced; this does
not validate the successful checkpoint path or any new performance budget.
The underlying SDK's formatted failure includes the later widget precondition;
the full preparation timeout remains in the original launch log.

[The JSON companion](2026-09-04-abd6293b-native-preparation.json) records source,
runner/transport outcomes and all raw hashes. The existing successful f15f27eb
P3 capture remains a separate observation. A fresh all-suite capture requires
an unlocked Mac and an actual stable, visible native window.
