part of 'main.dart';

/// One composed example for reviewing the library's opt-in workspace variants.
final class _CatalogWorkspaceVariants extends StatefulWidget {
  const _CatalogWorkspaceVariants();

  @override
  State<_CatalogWorkspaceVariants> createState() =>
      _CatalogWorkspaceVariantsState();
}

final class _CatalogWorkspaceVariantsState
    extends State<_CatalogWorkspaceVariants> {
  var _density = BeautifulUiDensity.compact;
  var _model = 'balanced';
  var _expanded = false;
  var _showSource = true;
  String? _submission;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final caption = theme.typography.caption.copyWith(
      color: theme.colors.inkMuted,
    );
    return _CatalogCard(
      title: 'Workspace variants · Compact + Embedded',
      caption:
          'Compare density, quiet transcript actions, and surfaces embedded in '
          'one parent. Callbacks stay local to this example.',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CatalogButton(
                label: _expanded
                    ? 'Hide workspace variants'
                    : 'Show workspace variants',
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded) ...[
                SizedBox(height: theme.spacing.md),
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BeautifulButton(
                      label: 'Density: ${_density.name}',
                      density: _density,
                      onPressed: () => setState(() {
                        _density = _density == BeautifulUiDensity.compact
                            ? BeautifulUiDensity.comfortable
                            : BeautifulUiDensity.compact;
                      }),
                    ),
                    BeautifulIconButton(
                      label: _showSource
                          ? 'Hide sample source'
                          : 'Show sample source',
                      // ASCII glyphs use the same bundled face as this catalog.
                      icon: _showSource
                          ? const IconData(
                              0x2d,
                              fontFamily: 'GeistSans',
                              fontPackage: 'shadcn_flutter',
                            )
                          : const IconData(
                              0x2b,
                              fontFamily: 'GeistSans',
                              fontPackage: 'shadcn_flutter',
                            ),
                      density: _density,
                      selected: _showSource,
                      onPressed: () =>
                          setState(() => _showSource = !_showSource),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.lg),
                BeautifulStreamingText(
                  id: 'catalog-workspace-answer',
                  quiet: true,
                  density: _density,
                  status: BeautifulStreamingStatus.complete,
                  content: const [
                    BeautifulStreamingPart.text(
                      'The restock helper now keeps the freezer temperature '
                      'consistent. Review the source below, or expand the tool '
                      'row to inspect its context.',
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.md),
                BeautifulToolChips(
                  density: _density,
                  surfaceVariant: BeautifulSurfaceVariant.embedded,
                  maxWidth: null,
                  headerLabel: '1 source inspected',
                  steps: [
                    BeautifulToolStep(
                      id: 'catalog-workspace-read',
                      label: 'Read source',
                      chip: 'churn.ts',
                      kind: BeautifulToolKind.read,
                      details: const [
                        BeautifulToolDetailLine(
                          text: 'Read the existing freezer storage call.',
                        ),
                      ],
                    ),
                  ],
                ),
                if (_showSource) ...[
                  SizedBox(height: theme.spacing.md),
                  BeautifulCodeBlock.code(
                    filename: 'churn.ts',
                    code: _sampleCode,
                    density: _density,
                    surfaceVariant: BeautifulSurfaceVariant.embedded,
                    maxWidth: null,
                  ),
                ],
                SizedBox(height: theme.spacing.lg),
                BeautifulPromptBar(
                  composerId: 'catalog-workspace-composer',
                  density: _density,
                  contextHeader: Text('restock / main', style: caption),
                  footerLeading: Text('Read only', style: caption),
                  placeholder: 'Ask a follow-up, or type @ for context',
                  sources: const [
                    BeautifulPromptSource(id: 'source', label: 'churn.ts'),
                  ],
                  models: const [
                    BeautifulPromptModel(id: 'balanced', label: 'Balanced'),
                    BeautifulPromptModel(id: 'precise', label: 'Precise'),
                  ],
                  selectedModelId: _model,
                  onModelChanged: (model) => setState(() => _model = model),
                  onSend: (submission) => setState(() {
                    _submission = submission.text;
                  }),
                ),
                if (_submission != null) ...[
                  SizedBox(height: theme.spacing.sm),
                  Text('Local submission: $_submission', style: caption),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
