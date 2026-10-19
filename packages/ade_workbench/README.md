# ADE Workbench

A responsive frontend shell composed from `beautiful_ai_ui`. Chat, task tools,
Git review, automations and settings use local preview data and callbacks for a
future execution kernel.

From this directory, run `flutter run -d chrome`. Build the static preview with
`flutter build web --release --no-web-resources-cdn`.

The workspace uses compact controls, embedded tool traces, quiet answer actions,
and stretchable code/Diff views from the component package. Desktop tools can be
resized, collapsed or expanded; narrow layouts open tools as full-width details.
Composer drafts, review selection and unsaved file edits survive these changes.
The Catalog separately demonstrates the reusable variants.

Validation commands from the repository root:

```sh
flutter test packages/ade_workbench/test
```

The existing page matrix checks every route at desktop, intermediate and phone
sizes in light and dark themes. Continuity regressions cover workspace changes,
tool expansion, file drafts, approvals and message/run ordering. These checks do
not imply that a real AI, terminal, Git service or scheduler is connected.
