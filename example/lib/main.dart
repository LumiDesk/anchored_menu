import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AnchoredMenuExampleApp());
}

class AnchoredMenuExampleApp extends StatelessWidget {
  const AnchoredMenuExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anchored Menu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF346EDB)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF346EDB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  String _view = 'Cards';
  String _sort = 'Newest';
  String _density = 'Comfortable';
  String _status = 'Choose an action from the menu.';

  void _select(String value) {
    setState(() => _status = 'Selected: $value');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anchored Menu'),
        actions: <Widget>[
          AnchoredMenuButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More actions',
            entries: <AnchoredMenuEntry>[
              AnchoredMenuItem(
                id: 'view',
                icon: Icons.view_quilt_outlined,
                title: 'View',
                subtitle: _view,
                children: <AnchoredMenuEntry>[
                  AnchoredMenuItem(
                    id: 'view_cards',
                    title: 'Cards',
                    selected: _view == 'Cards',
                    onPressed: () {
                      setState(() => _view = 'Cards');
                      _select('Cards view');
                    },
                  ),
                  AnchoredMenuItem(
                    id: 'view_list',
                    title: 'List',
                    selected: _view == 'List',
                    onPressed: () {
                      setState(() => _view = 'List');
                      _select('List view');
                    },
                  ),
                ],
              ),
              AnchoredMenuItem(
                id: 'sort',
                icon: Icons.sort_rounded,
                title: 'Sort',
                subtitle: _sort,
                children: <AnchoredMenuEntry>[
                  for (final value in <String>['Newest', 'Oldest', 'Name'])
                    AnchoredMenuItem(
                      id: 'sort_${value.toLowerCase()}',
                      title: value,
                      selected: _sort == value,
                      onPressed: () {
                        setState(() => _sort = value);
                        _select('$value order');
                      },
                    ),
                ],
              ),
              const AnchoredMenuDivider(),
              AnchoredMenuItem(
                id: 'details',
                icon: Icons.info_outline_rounded,
                title: 'Details',
                subtitle: 'Open a nested card',
                children: <AnchoredMenuEntry>[
                  AnchoredMenuItem(
                    id: 'about',
                    title: 'About this package',
                    subtitle: 'Recursive submenus and controlled selection',
                    onPressed: () => _select('About'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.account_tree_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Anchored menus that grow with the trigger',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open the header action for actions and submenus. '
                    'The second control demonstrates the controlled '
                    'single-choice adapter.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Last action',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(_status, style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: AnchoredMenuChoice<String>(
                      values: const <String>['Compact', 'Comfortable'],
                      selected: _density,
                      idOf: (value) => 'density_${value.toLowerCase()}',
                      labelOf: (value) => value,
                      onSelected: (value) {
                        setState(() => _density = value);
                        _select('$value layout');
                      },
                      semanticLabel: 'Choose layout density',
                      width: 208,
                      builder: (context, openMenu, menuOpen) =>
                          FilledButton.tonalIcon(
                            onPressed: openMenu,
                            icon: Icon(
                              menuOpen
                                  ? Icons.close_rounded
                                  : Icons.tune_rounded,
                            ),
                            label: const Text('Choose density'),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
