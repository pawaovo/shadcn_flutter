import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/layout.dart';
import '../foundation/theme.dart';
import '../implementation/controls/text_selection.dart';

/// The available navigation presentation.
enum BeautifulSidebarPresentation {
  /// Resolve the presentation from the widget's actual available width.
  adaptive,

  /// A navigation trigger that opens an inline drawer panel.
  drawer,

  /// An icon rail that can expand to show complete labels and chat history.
  rail,

  /// An expanded sidebar that can collapse to an icon rail.
  expanded,
}

/// Host actions available from the workspace menu.
enum BeautifulSidebarWorkspaceAction {
  /// Create a workspace.
  create,

  /// Open settings for the selected workspace.
  settings,

  /// Invite a team member.
  invite,

  /// Sign out of the host application.
  signOut,
}

/// An immutable workspace identity and its display name.
@immutable
final class BeautifulSidebarWorkspace {
  /// Creates a workspace. IDs and labels must be nonblank.
  BeautifulSidebarWorkspace({required this.id, required this.label}) {
    _requireText(id, 'id');
    _requireText(label, 'label');
  }

  /// Stable identity, unique within the workspace collection.
  final String id;

  /// Complete display name; the expanded panel wraps it without truncation.
  final String label;
}

/// An immutable primary navigation destination.
@immutable
final class BeautifulSidebarItem {
  /// Creates a destination with an optional localized count.
  BeautifulSidebarItem({required this.id, required this.label, this.count}) {
    _requireText(id, 'id');
    _requireText(label, 'label');
    if (count != null) _requireText(count!, 'count');
  }

  /// Stable identity, unique within primary destinations.
  final String id;

  /// Complete destination name.
  final String label;

  /// Optional caller-formatted count, such as `3/10`.
  final String? count;
}

/// An immutable recent chat summary.
@immutable
final class BeautifulSidebarRecent {
  /// Creates a chat summary. The optional prompt is passed back unchanged.
  BeautifulSidebarRecent({required this.id, required this.label, this.prompt}) {
    _requireText(id, 'id');
    _requireText(label, 'label');
  }

  /// Stable chat identity, independent of its display name or list position.
  final String id;

  /// Complete searchable chat name.
  final String label;

  /// Optional host metadata; this widget never submits or executes it.
  final String? prompt;
}

/// Localizable labels for navigation controls and workspace actions.
@immutable
final class BeautifulSidebarLabels {
  /// Creates labels with English defaults.
  const BeautifulSidebarLabels({
    this.navigation = 'Workspace navigation',
    this.open = 'Open navigation',
    this.close = 'Close navigation',
    this.expand = 'Expand sidebar',
    this.collapse = 'Collapse sidebar',
    this.workspace = 'Switch workspace',
    this.newChat = 'New chat',
    this.chats = 'Chats',
    this.search = 'Search chat history',
    this.closeSearch = 'Close chat search',
    this.empty = 'No chats found',
    this.createWorkspace = 'New workspace',
    this.workspaceSettings = 'Workspace settings',
    this.invite = 'Invite team members',
    this.signOut = 'Sign out',
    this.closeWorkspaceMenu = 'Close workspace menu',
  });

  /// Name of the navigation region.
  final String navigation;

  /// Compact drawer open action.
  final String open;

  /// Compact drawer close action.
  final String close;

  /// Rail expansion action.
  final String expand;

  /// Sidebar collapse action.
  final String collapse;

  /// Workspace switcher action.
  final String workspace;

  /// New chat action.
  final String newChat;

  /// Recent chat section heading.
  final String chats;

  /// Search trigger and editor label.
  final String search;

  /// Search close action.
  final String closeSearch;

  /// Empty search result text.
  final String empty;

  /// Create workspace action.
  final String createWorkspace;

  /// Workspace settings action.
  final String workspaceSettings;

  /// Invite action.
  final String invite;

  /// Sign out action.
  final String signOut;

  /// Workspace menu dismissal action.
  final String closeWorkspaceMenu;
}

/// Workspace navigation with primary destinations and searchable chat history.
///
/// The host controls all selected IDs and executes navigation, workspace, and
/// account actions through callbacks. This widget only owns search, disclosure,
/// keyboard focus, and scrolling. Null action callbacks produce disabled
/// controls; no router, account service, or network client is created.
///
/// Adaptive presentation uses actual local constraints: compact opens an
/// inline drawer, medium starts as a rail, and expanded starts as a sidebar.
/// Use an explicit [presentation] when the host has already allocated a narrow
/// sidebar lane. [height] is capped by bounded parent height; [expandedWidth]
/// is capped by available width. An inline drawer requires no Navigator.
///
/// User expansion choices, search text and selection, and chat scroll position
/// survive resize and presentation changes. Chat rows are built lazily; names
/// wrap completely in the panel and remain accessible names in the rail.
/// Escape closes the active workspace menu, search, or panel in that order and
/// restores focus to its trigger. Tab traverses controls; Enter and Space
/// activate them. Selecting an item never changes a host-owned selected ID.
final class BeautifulSidebarNav extends StatefulWidget {
  /// Creates navigation from defensively copied, uniquely identified snapshots.
  BeautifulSidebarNav({
    super.key,
    required Iterable<BeautifulSidebarWorkspace> workspaces,
    required this.selectedWorkspaceId,
    Iterable<BeautifulSidebarItem> items = const [],
    Iterable<BeautifulSidebarRecent> recents = const [],
    this.selectedItemId,
    this.selectedRecentId,
    this.onWorkspaceSelected,
    this.onWorkspaceAction,
    this.onItemSelected,
    this.onRecentSelected,
    this.onNewChat,
    this.footerLabel,
    this.onFooterPressed,
    this.labels = const BeautifulSidebarLabels(),
    this.presentation = BeautifulSidebarPresentation.adaptive,
    this.height = 600,
    this.expandedWidth = 288,
  }) : workspaces = List.unmodifiable(workspaces),
       items = List.unmodifiable(items),
       recents = List.unmodifiable(recents) {
    _requireUniqueIds(this.workspaces.map((item) => item.id), 'workspaces');
    _requireUniqueIds(this.items.map((item) => item.id), 'items');
    _requireUniqueIds(this.recents.map((item) => item.id), 'recents');
    if (!this.workspaces.any((item) => item.id == selectedWorkspaceId)) {
      throw ArgumentError.value(selectedWorkspaceId, 'selectedWorkspaceId');
    }
    if (selectedItemId != null &&
        !this.items.any((item) => item.id == selectedItemId)) {
      throw ArgumentError.value(selectedItemId, 'selectedItemId');
    }
    if (selectedRecentId != null &&
        !this.recents.any((item) => item.id == selectedRecentId)) {
      throw ArgumentError.value(selectedRecentId, 'selectedRecentId');
    }
    if (footerLabel != null) _requireText(footerLabel!, 'footerLabel');
    if (!height.isFinite || height < 96) {
      throw ArgumentError.value(height, 'height', 'must be finite and >= 96');
    }
    if (!expandedWidth.isFinite || expandedWidth < 160) {
      throw ArgumentError.value(
        expandedWidth,
        'expandedWidth',
        'must be finite and >= 160',
      );
    }
  }

  /// Available workspace snapshots.
  final List<BeautifulSidebarWorkspace> workspaces;

  /// Host-owned selected workspace identity.
  final String selectedWorkspaceId;

  /// Primary navigation destinations.
  final List<BeautifulSidebarItem> items;

  /// Chat history, searched locally by display name.
  final List<BeautifulSidebarRecent> recents;

  /// Host-owned selected primary destination, or null.
  final String? selectedItemId;

  /// Host-owned selected chat, or null.
  final String? selectedRecentId;

  /// Requests a workspace selection; the host supplies the accepted ID.
  final ValueChanged<BeautifulSidebarWorkspace>? onWorkspaceSelected;

  /// Requests a workspace/account action for the currently selected workspace.
  final ValueChanged<BeautifulSidebarWorkspaceAction>? onWorkspaceAction;

  /// Requests navigation to a primary destination.
  final ValueChanged<BeautifulSidebarItem>? onItemSelected;

  /// Requests opening a chat and returns its exact snapshot, including prompt.
  final ValueChanged<BeautifulSidebarRecent>? onRecentSelected;

  /// Requests a new chat.
  final VoidCallback? onNewChat;

  /// Optional footer call-to-action label; omitted when null.
  final String? footerLabel;

  /// Requests the optional footer action.
  final VoidCallback? onFooterPressed;

  /// Localized controls and section names.
  final BeautifulSidebarLabels labels;

  /// Automatic presentation or an explicit choice for a host sidebar lane.
  final BeautifulSidebarPresentation presentation;

  /// Maximum panel height in logical pixels, at least 96.
  final double height;

  /// Maximum width of the open panel in logical pixels, at least 160.
  final double expandedWidth;

  @override
  State<BeautifulSidebarNav> createState() => _BeautifulSidebarNavState();
}

final class _BeautifulSidebarNavState extends State<BeautifulSidebarNav> {
  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  final _navigationFocus = FocusNode(skipTraversal: true);
  final _toggleFocus = FocusNode();
  final _workspaceFocus = FocusNode();
  final _searchTriggerFocus = FocusNode();
  final _newChatFocus = FocusNode();
  final _footerFocus = FocusNode();
  final _itemFocus = <String, FocusNode>{};
  final _menuFocus = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final _editableKey = GlobalKey<EditableTextState>();
  final _scroll = ScrollController();
  final _pageStorage = PageStorageBucket();
  List<BeautifulSidebarRecent> _matches = const [];
  bool? _expandedChoice;
  bool _workspaceOpen = false;
  bool _searchOpen = false;
  bool _drawerOpen = false;
  bool _searchFocused = false;
  bool _restoreSearchFocus = false;
  BeautifulSidebarPresentation? _lastPresentation;

  @override
  void initState() {
    super.initState();
    _matches = widget.recents;
    _query.addListener(_filter);
    _searchFocus.addListener(_searchFocusChanged);
  }

  @override
  void didUpdateWidget(BeautifulSidebarNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemIds = widget.items.map((item) => item.id).toSet();
    final removedIds = _itemFocus.keys
        .where((id) => !itemIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      final removed = _itemFocus.remove(id)!;
      final hadFocus = removed.hasFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        removed.dispose();
      });
      if (hadFocus) _focusAfterBuild(_toggleFocus);
    }
    _filter(notify: false);
  }

  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    _navigationFocus.dispose();
    _toggleFocus.dispose();
    _workspaceFocus.dispose();
    _searchTriggerFocus.dispose();
    _newChatFocus.dispose();
    _footerFocus.dispose();
    for (final node in _itemFocus.values) {
      node.dispose();
    }
    _menuFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter({bool notify = true}) {
    final query = _query.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.recents
        : widget.recents
              .where((item) => item.label.toLowerCase().contains(query))
              .toList(growable: false);
    if (notify) {
      setState(() => _matches = matches);
    } else {
      _matches = matches;
    }
  }

  void _searchFocusChanged() {
    if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
  }

  void _focusAfterBuild(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.context != null) node.requestFocus();
    });
  }

  void _closeWorkspace({bool restoreFocus = true}) {
    if (!_workspaceOpen) return;
    setState(() => _workspaceOpen = false);
    if (restoreFocus) _focusAfterBuild(_workspaceFocus);
  }

  void _closeSearch() {
    setState(() => _searchOpen = false);
    _query.clear();
    _focusAfterBuild(_searchTriggerFocus);
  }

  void _toggle(bool panel, bool drawer) {
    setState(() {
      _workspaceOpen = false;
      if (drawer) {
        _drawerOpen = !panel;
      } else {
        _expandedChoice = !panel;
      }
    });
    _focusAfterBuild(_toggleFocus);
  }

  void _navigate(VoidCallback action) {
    if (_lastPresentation == BeautifulSidebarPresentation.drawer &&
        _drawerOpen) {
      _toggle(true, true);
    }
    action();
  }

  BeautifulSidebarPresentation _presentation(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    if (widget.presentation != BeautifulSidebarPresentation.adaptive) {
      return widget.presentation;
    }
    return switch (BeautifulUiEnvironment.of(context)
        .modeFor(context, constraints)) {
      BeautifulLayoutMode.compact => BeautifulSidebarPresentation.drawer,
      BeautifulLayoutMode.medium => BeautifulSidebarPresentation.rail,
      BeautifulLayoutMode.expanded => BeautifulSidebarPresentation.expanded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final workspace = widget.workspaces.firstWhere(
      (item) => item.id == widget.selectedWorkspaceId,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final presentation = _presentation(context, constraints);
        final drawer = presentation == BeautifulSidebarPresentation.drawer;
        final panel = drawer
            ? _drawerOpen
            : _expandedChoice ??
                  presentation == BeautifulSidebarPresentation.expanded;
        if (_lastPresentation != presentation) {
          if (_lastPresentation != null) {
            final focusedAction = [
              _newChatFocus,
              _footerFocus,
              ..._itemFocus.values,
            ].where((node) => node.hasFocus).firstOrNull;
            if (_searchFocus.hasFocus && !panel) {
              _restoreSearchFocus = true;
              _focusAfterBuild(_toggleFocus);
            } else if (focusedAction != null) {
              _restoreSearchFocus = false;
              _focusAfterBuild(drawer && !panel ? _toggleFocus : focusedAction);
            } else if (panel &&
                _searchOpen &&
                _restoreSearchFocus &&
                _toggleFocus.hasFocus) {
              _restoreSearchFocus = false;
              _focusAfterBuild(_searchFocus);
            } else if (_navigationFocus.hasFocus && !panel) {
              _focusAfterBuild(_toggleFocus);
            }
          }
          _lastPresentation = presentation;
        }
        final width = math.min(
          constraints.maxWidth,
          panel || drawer ? widget.expandedWidth : 64.0,
        );
        final height = drawer && !panel
            ? null
            : math.min(widget.height, constraints.maxHeight);
        return Semantics(
          container: true,
          explicitChildNodes: true,
          role: SemanticsRole.navigation,
          label: widget.labels.navigation,
          child: Focus(
            focusNode: _navigationFocus,
            skipTraversal: true,
            includeSemantics: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent ||
                  event.logicalKey != LogicalKeyboardKey.escape) {
                return KeyEventResult.ignored;
              }
              if (_workspaceOpen) {
                _closeWorkspace();
              } else if (_searchOpen && panel) {
                _closeSearch();
              } else if (panel) {
                _toggle(panel, drawer);
              } else {
                return KeyEventResult.ignored;
              }
              return KeyEventResult.handled;
            },
            child: TapRegion(
              onTapOutside: (_) => _closeWorkspace(restoreFocus: false),
              child: SizedBox(
                width: width,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colors.surface,
                    border: Border.all(color: theme.colors.lineStrong),
                    borderRadius: BorderRadius.circular(theme.radii.card),
                  ),
                  child: PageStorage(
                    bucket: _pageStorage,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              if (panel)
                                Expanded(
                                  child: _SidebarButton(
                                    key: const ValueKey(
                                      'beautiful-sidebar-workspace',
                                    ),
                                    label: workspace.label,
                                    maxLines: 2,
                                    semanticLabel:
                                        '${widget.labels.workspace}: '
                                        '${workspace.label}',
                                    icon: _SidebarIconKind.workspace,
                                    focusNode: _workspaceFocus,
                                    expanded: _workspaceOpen,
                                    onPressed: () {
                                      if (_workspaceOpen) {
                                        _closeWorkspace();
                                      } else {
                                        setState(() => _workspaceOpen = true);
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted) {
                                                _menuFocus.nextFocus();
                                              }
                                            });
                                      }
                                    },
                                  ),
                                ),
                              if (!panel || !drawer)
                                if (drawer && !panel)
                                  Expanded(
                                    child: _SidebarButton(
                                      key: const ValueKey(
                                        'beautiful-sidebar-toggle',
                                      ),
                                      label: widget.labels.open,
                                      icon: _SidebarIconKind.menu,
                                      focusNode: _toggleFocus,
                                      expanded: false,
                                      onPressed: () => _toggle(panel, drawer),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: 54,
                                    child: _SidebarButton(
                                      key: const ValueKey(
                                        'beautiful-sidebar-toggle',
                                      ),
                                      label: panel
                                          ? widget.labels.collapse
                                          : widget.labels.expand,
                                      icon: _SidebarIconKind.menu,
                                      iconOnly: true,
                                      focusNode: _toggleFocus,
                                      expanded: panel,
                                      onPressed: () => _toggle(panel, drawer),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        if (panel || !drawer)
                          Expanded(
                            child: Stack(
                              children: [
                                ExcludeFocus(
                                  excluding: _workspaceOpen && panel,
                                  child: ExcludeSemantics(
                                    excluding: _workspaceOpen && panel,
                                    child: panel
                                        ? _panel(context, drawer)
                                        : _rail(context),
                                  ),
                                ),
                                if (_workspaceOpen && panel)
                                  Positioned.fill(child: _menu(context)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panel(BuildContext context, bool drawer) {
    final theme = BeautifulUiTheme.of(context);
    final history = RawScrollbar(
      controller: _scroll,
      thumbVisibility: true,
      thumbColor: theme.colors.inkMuted,
      child: CustomScrollView(
        key: const PageStorageKey('beautiful-sidebar-history'),
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            sliver: SliverList.list(
              children: [
                if (drawer)
                  _SidebarButton(
                    key: const ValueKey('beautiful-sidebar-toggle'),
                    label: widget.labels.close,
                    icon: _SidebarIconKind.close,
                    focusNode: _toggleFocus,
                    onPressed: () => _toggle(true, true),
                  ),
                _SidebarButton(
                  label: widget.labels.newChat,
                  focusNode: _newChatFocus,
                  icon: _SidebarIconKind.add,
                  onPressed: widget.onNewChat == null
                      ? null
                      : () => _navigate(widget.onNewChat!),
                ),
                for (final item in widget.items) _item(item, false),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, top: 12),
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.labels.chats,
                      style: theme.typography.label.copyWith(
                        color: theme.colors.inkMuted,
                      ),
                    ),
                  ),
                ),
                if (_searchOpen)
                  _search(context)
                else
                  _SidebarButton(
                    key: const ValueKey('beautiful-sidebar-search-trigger'),
                    label: widget.labels.search,
                    icon: _SidebarIconKind.search,
                    focusNode: _searchTriggerFocus,
                    expanded: false,
                    onPressed: () {
                      setState(() => _searchOpen = true);
                      _focusAfterBuild(_searchFocus);
                    },
                  ),
                if (_matches.isEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        widget.labels.empty,
                        style: theme.typography.body.copyWith(
                          color: theme.colors.inkMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            sliver: SliverList.builder(
              itemCount: _matches.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index = _matches.indexWhere(
                  (item) => 'beautiful-sidebar-recent-${item.id}' == key.value,
                );
                return index < 0 ? null : index;
              },
              itemBuilder: (context, index) {
                final item = _matches[index];
                return _SidebarButton(
                  key: ValueKey('beautiful-sidebar-recent-${item.id}'),
                  label: item.label,
                  icon: _SidebarIconKind.chat,
                  selected: item.id == widget.selectedRecentId,
                  onPressed: widget.onRecentSelected == null
                      ? null
                      : () => _navigate(() => widget.onRecentSelected!(item)),
                );
              },
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: history),
        if (widget.footerLabel != null)
          Padding(padding: const EdgeInsets.all(4), child: _footer(false)),
      ],
    );
  }

  Widget _rail(BuildContext context) => ListView(
    key: const PageStorageKey('beautiful-sidebar-rail'),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    children: [
      _SidebarButton(
        label: widget.labels.newChat,
        focusNode: _newChatFocus,
        icon: _SidebarIconKind.add,
        iconOnly: true,
        onPressed: widget.onNewChat,
      ),
      for (final item in widget.items) _item(item, true),
      if (widget.footerLabel != null) _footer(true),
    ],
  );

  Widget _item(BeautifulSidebarItem item, bool rail) => _SidebarButton(
    key: ValueKey('beautiful-sidebar-item-${item.id}'),
    label: item.label,
    focusNode: _itemFocus.putIfAbsent(item.id, FocusNode.new),
    semanticLabel: item.count == null
        ? item.label
        : '${item.label}, ${item.count}',
    count: item.count,
    icon: _SidebarIconKind.destination,
    iconOnly: rail,
    selected: item.id == widget.selectedItemId,
    onPressed: widget.onItemSelected == null
        ? null
        : () => _navigate(() => widget.onItemSelected!(item)),
  );

  Widget _footer(bool rail) => _SidebarButton(
    label: widget.footerLabel!,
    focusNode: _footerFocus,
    icon: _SidebarIconKind.forward,
    iconOnly: rail,
    onPressed: widget.onFooterPressed == null
        ? null
        : () => _navigate(widget.onFooterPressed!),
  );

  Widget _search(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.field,
              border: Border.all(
                color: _searchFocused
                    ? theme.colors.accent
                    : theme.colors.lineStrong,
                width: _searchFocused ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(theme.radii.control),
            ),
            child: MergeSemantics(
              child: Semantics(
                label: widget.labels.search,
                textField: true,
                onTap: _searchFocus.requestFocus,
                child: BeautifulTextSelectionGestureDetector(
                  editableTextKey: _editableKey,
                  identity: widget.selectedWorkspaceId,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: EditableText(
                        key: _editableKey,
                        controller: _query,
                        focusNode: _searchFocus,
                        style: theme.typography.body.copyWith(
                          color: theme.colors.ink,
                        ),
                        cursorColor: theme.colors.accent,
                        backgroundCursorColor: theme.colors.inkSubtle,
                        selectionColor: theme.colors.accentTint,
                        rendererIgnoresPointer: true,
                        maxLines: 1,
                        textInputAction: TextInputAction.search,
                        showSelectionHandles: Overlay.maybeOf(context) != null,
                        selectionControls: Overlay.maybeOf(context) == null
                            ? null
                            : BeautifulTextSelectionControls(
                                theme.colors.accent,
                              ),
                        contextMenuBuilder: Overlay.maybeOf(context) == null
                            ? null
                            : (context, editable) {
                                final workspace = widget.selectedWorkspaceId;
                                return beautifulEditableTextContextMenu(
                                  editable.context,
                                  editable,
                                  isCurrent: () =>
                                      mounted &&
                                      workspace == widget.selectedWorkspaceId,
                                );
                              },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _SidebarButton(
          label: widget.labels.closeSearch,
          icon: _SidebarIconKind.close,
          onPressed: _closeSearch,
        ),
      ],
    );
  }

  Widget _menu(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final actions = [
      (BeautifulSidebarWorkspaceAction.create, widget.labels.createWorkspace),
      (
        BeautifulSidebarWorkspaceAction.settings,
        widget.labels.workspaceSettings,
      ),
      (BeautifulSidebarWorkspaceAction.invite, widget.labels.invite),
      (BeautifulSidebarWorkspaceAction.signOut, widget.labels.signOut),
    ];
    return ColoredBox(
      color: theme.colors.surface,
      child: FocusScope(
        node: _menuFocus,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _menuFocus.nextFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _menuFocus.previousFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ListView(
          padding: const EdgeInsets.all(4),
          children: [
            for (final workspace in widget.workspaces)
              _SidebarButton(
                key: ValueKey('beautiful-sidebar-workspace-${workspace.id}'),
                label: workspace.label,
                icon: _SidebarIconKind.workspace,
                selected: workspace.id == widget.selectedWorkspaceId,
                onPressed: widget.onWorkspaceSelected == null
                    ? null
                    : () {
                        _closeWorkspace();
                        widget.onWorkspaceSelected!(workspace);
                      },
              ),
            for (final (action, label) in actions)
              _SidebarButton(
                label: label,
                icon: action == BeautifulSidebarWorkspaceAction.create
                    ? _SidebarIconKind.add
                    : _SidebarIconKind.forward,
                onPressed: widget.onWorkspaceAction == null
                    ? null
                    : () {
                        _closeWorkspace();
                        widget.onWorkspaceAction!(action);
                      },
              ),
            _SidebarButton(
              label: widget.labels.closeWorkspaceMenu,
              icon: _SidebarIconKind.close,
              onPressed: _closeWorkspace,
            ),
          ],
        ),
      ),
    );
  }
}

final class _SidebarButton extends StatefulWidget {
  const _SidebarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.count,
    this.focusNode,
    this.iconOnly = false,
    this.selected,
    this.expanded,
    this.maxLines,
  });

  final String label;
  final _SidebarIconKind icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? count;
  final FocusNode? focusNode;
  final bool iconOnly;
  final bool? selected;
  final bool? expanded;
  final int? maxLines;

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

final class _SidebarButtonState extends State<_SidebarButton> {
  var _focused = false;
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      button: true,
      enabled: enabled,
      focusable: enabled,
      focused: enabled && _focused,
      selected: widget.selected,
      expanded: widget.expanded,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: enabled,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: widget.selected == true
                  ? theme.colors.hoverStrong
                  : _hovered
                  ? theme.colors.hover
                  : null,
              border: Border.all(
                color: _focused ? theme.colors.accent : const Color(0x00000000),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(theme.radii.control),
            ),
            child: Row(
              mainAxisAlignment: widget.iconOnly
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                CustomPaint(
                  size: const Size.square(20),
                  painter: _SidebarIconPainter(
                    widget.selected == true
                        ? _SidebarIconKind.selected
                        : widget.icon,
                    enabled ? theme.colors.ink : theme.colors.inkMuted,
                    Directionality.of(context),
                  ),
                ),
                if (!widget.iconOnly) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.count == null
                          ? widget.label
                          : '${widget.label}  ${widget.count}',
                      maxLines: widget.maxLines,
                      overflow: widget.maxLines == null
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      style: theme.typography.label.copyWith(
                        color: theme.colors.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SidebarIconKind {
  menu,
  workspace,
  add,
  chat,
  destination,
  search,
  close,
  forward,
  selected,
}

final class _SidebarIconPainter extends CustomPainter {
  const _SidebarIconPainter(this.kind, this.color, this.direction);

  final _SidebarIconKind kind;
  final Color color;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    if (direction == TextDirection.rtl) {
      canvas.translate(20, 0);
      canvas.scale(-1, 1);
    }
    final path = Path();
    switch (kind) {
      case _SidebarIconKind.menu:
        for (final y in [5.0, 10.0, 15.0]) {
          path.moveTo(3, y);
          path.lineTo(17, y);
        }
      case _SidebarIconKind.add:
        path.moveTo(10, 3);
        path.lineTo(10, 17);
        path.moveTo(3, 10);
        path.lineTo(17, 10);
      case _SidebarIconKind.close:
        path.moveTo(5, 5);
        path.lineTo(15, 15);
        path.moveTo(15, 5);
        path.lineTo(5, 15);
      case _SidebarIconKind.search:
        canvas.drawCircle(const Offset(8, 8), 5, paint);
        path.moveTo(12, 12);
        path.lineTo(17, 17);
      case _SidebarIconKind.selected:
        path.moveTo(3, 10);
        path.lineTo(8, 15);
        path.lineTo(17, 5);
      case _SidebarIconKind.forward:
        path.moveTo(3, 10);
        path.lineTo(17, 10);
        path.moveTo(12, 5);
        path.lineTo(17, 10);
        path.lineTo(12, 15);
      case _SidebarIconKind.chat:
        path.moveTo(3, 3);
        path.lineTo(17, 3);
        path.lineTo(17, 14);
        path.lineTo(8, 14);
        path.lineTo(3, 18);
        path.close();
      case _SidebarIconKind.destination:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 3, 14, 14),
            const Radius.circular(3),
          ),
          paint,
        );
        path.moveTo(7, 8);
        path.lineTo(13, 8);
        path.moveTo(7, 12);
        path.lineTo(11, 12);
      case _SidebarIconKind.workspace:
        for (final offset in [
          const Offset(3, 3),
          const Offset(12, 3),
          const Offset(3, 12),
          const Offset(12, 12),
        ]) {
          canvas.drawRect(offset & const Size.square(5), paint);
        }
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SidebarIconPainter oldDelegate) =>
      kind != oldDelegate.kind ||
      color != oldDelegate.color ||
      direction != oldDelegate.direction;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must be nonblank');
  }
}

void _requireUniqueIds(Iterable<String> ids, String name) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw ArgumentError.value(id, name, 'IDs must be unique');
    }
  }
}
