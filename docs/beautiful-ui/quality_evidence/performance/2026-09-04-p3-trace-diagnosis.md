# Read-only diagnosis of the retained 87299572 P3 trace

This analysis uses the valid `20260904-87299572-p3-foreground` capture and
source at `8729957220c011329022bafc7a0f7402434ce15e`. It adds no measurement,
changes no budget or recorded result, and establishes no causal attribution to
other applications. The [capture record](./2026-09-04-87299572-native-profile.md)
retains the complete source/measurement boundary.

## Findings and practical limits

- **Diff:** all five over-interval frames (`4782`, `4825`, `4942`, `4985`,
  `5101`) occur in Next/Previous pagination steps. The sixth pagination frame,
  `5144`, has 8.027 ms build time; the actual failure remains 5/495, above 1%.
  Retained frames 4942/4985/5101 have root layout spans of
  9.709/13.463/8.493 ms and nested generic BUILD spans of
  3.412/3.257/3.159 ms. Source inspection confirms that a page change also
  recomputes the whole-table summary over 500 rows. The trace has no independent
  summary/row/text-layout samples, so it cannot quantify that cost or show that
  caching the summary would resolve the budget failure. Frame 4985 also contains
  GC work inside its layout interval.
- **Records and Insights:** Records frame 7304, during numeric sorting, has
  111.941 ms build time, including 102.099 ms root layout. Insights long-data
  scroll frames 10361 and 10600 have 92.355 and 77.207 ms root layout. Their
  generic BUILD scopes do not identify individual application row rebuilds:
  Flutter sliver creation/removal and LayoutBuilder also produce these scopes.
  The retained events do not establish failed virtualization or justify an
  additional whole-list cache.
- **Flowchart and Selection:** Flowchart's worst 573.478 ms raster frame 9265
  is absent from the retained trace window. Frame 9388 has long generic
  BUILD/layout spans without application function attribution. Selection frame
  10904 spends 27.989 ms in root PAINT, has only 4 microseconds of layout and no
  corresponding BUILD scope while scrolling the native EditableText. This
  does not support a component-build cache as the next repair.

The original timelines remain in the ignored local capture directory
`packages/beautiful_ai_ui_catalog/build/p3-profile/20260904-87299572-p3-foreground/`;
their identities are recorded by the linked capture manifest. Elapsed timeline
spans are not automatically function CPU costs. Missing frame/function evidence
is not reconstructed from source or from another capture.

No product patch is justified by this read-only diagnosis alone. The next
performance decision still needs the requested controlled comparison and,
where necessary, a targeted profile that attributes the actual expensive work.
All six P3 failures and the earlier evidence remain unchanged.
