# Safari Flowchart theme change with reduced motion

Date: 2026-09-03. **Local visual gate closed; Safari overall remains Partial.**

Exactly three real Safari full-screen screenshots were independently opened
with `view_image` and checked against their paired AX exports. They show
`Theme: light` → `Theme: dark` → `Theme: light`, with `Motion: reduced` throughout.
The operator reports an intermediate `system (dark)` step; that uncaptured
intermediate state is not independently accepted here.

| Accepted capture | AX-confirmed theme | Saved pixels | Image SHA-256 |
|---|---|---|---|
| [Light before](../../../packages/beautiful_ai_ui_catalog/build/release_verification/safari/final-source-20260903/fullscreen-light-before.jpg) | light | 1229 × 768 | `ffdb727cd9213ae408088a22839e67155317c438255ef1c7202c158b66e7e555` |
| [Dark after](../../../packages/beautiful_ai_ui_catalog/build/release_verification/safari/final-source-20260903/fullscreen-dark-after.jpg) | dark | 1229 × 768 | `ffc56dd1398139ca05e78d75aadd06bc5e87e68a829abcc5298e1d981f5fffde` |
| [Light after](../../../packages/beautiful_ai_ui_catalog/build/release_verification/safari/final-source-20260903/fullscreen-light-after.jpg) | light | 1229 × 768 | `aeea3d01dbde5a6d822ecccb49b4a395fe1d3ba8efbdde9a6f3ae31313fd6165` |

The [JSON record](./2026-09-03-safari-flowchart-theme-reduced.json) includes all
six image/AX hashes, exact AX line references, observations and scope limits.
Saved-image pixel dimensions do not establish CSS viewport size or DPR.

**Observed acceptance:** Canvas remains visibly selected. Both workflow nodes,
their connector and `Stock threshold: Below 40 tubs` remain visible. The
condition control has a light surface and readable dark text in both light
captures, and a dark surface with readable light text in the dark capture.
The stale dark-background mismatch after returning to light is absent in this
captured sequence. AX labels confirm the actual selected theme rather than
relying on the operator's intended click; AX lists Canvas without a selected
flag, so Canvas selection is a visual observation.

Environment: Safari **26.6.1**, final release runtime identified by the operator
as commit `c2bde85dd5da7c33b0f7881234ae312f3be1826c`, served from
`http://127.0.0.1:8096/`. The bootstrap was independently rehashed as
`52d7a025b9bca8c5843524ed87dc9e3f802f04bb0338ca35e31e31b990d19a9d`.

The earlier `flowchart-light-after.jpg` attempt still had `Theme: system` and
is **excluded**. Earlier white captures and `noWindowsAvailable` are not used
as acceptance evidence. The operator reports that a fresh Safari window could
display `version.json` and the Catalog, then full-screen mode made theme
operations stable. No application or bootstrap change was used for that
recovery. Its cause remains unproven; this record does not classify it as a
component-library, SkWasm or capture-tool defect.

This closes only the pictured reduced-motion Flowchart theme-color gate.
The full Safari browser/component/input/assistive-technology matrix, real
screen-reader behavior, timing of transitions and performance remain outside
this evidence. Review involved no GUI interaction or retest. Images were not
edited or copied; the JPEG/AX files stay in ignored build output, with only this
record and local references intended for version control.
