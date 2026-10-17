import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_item_page.dart';
import 'archived_items_page.dart';
import 'catalog_pages.dart';
import 'dashboard_page.dart';
import 'models.dart';
import 'repository.dart';
import 'ui.dart';

const stockOutReasons = <String, String>{
  'USED': 'Used for preparation',
  'SOLD': 'Sold',
  'EXPIRED': 'Expired',
  'DAMAGED': 'Damaged',
  'SPOILED': 'Spoiled',
  'SPILLED': 'Spilled',
  'LOST': 'Missing / lost',
  'WASTE': 'Waste / discarded',
  'RETURN': 'Returned to supplier',
  'TRANSFER': 'Transferred out',
  'OTHER': 'Other (explain)',
};

const stockInReasons = <String, String>{
  'DELIVERY': 'Supplier delivery',
  'PURCHASE': 'Direct purchase',
  'RETURN': 'Customer / department return',
  'PRODUCTION': 'Produced in-house',
  'TRANSFER': 'Transferred in',
  'OTHER': 'Other (explain)',
};

const restockReasons = <String, String>{
  'LOW_STOCK': 'Low stock',
  'OUT_OF_STOCK': 'Out of stock',
  'EXPECTED_DEMAND': 'Upcoming demand',
  'ROUTINE_REPLENISHMENT': 'Routine replenishment',
  'REPLACEMENT': 'Replacement for damaged / expired goods',
  'OTHER': 'Other (explain)',
};

const adjustmentReasons = <String, String>{
  'PHYSICAL_RECOUNT': 'Physical recount difference',
  'COUNTING_ERROR': 'Previous counting error',
  'DATA_CORRECTION': 'Data entry correction',
  'FOUND_STOCK': 'Stock found during recount',
  'OTHER': 'Other (explain)',
};

const commonUnits = <String>[
  'pcs',
  'g',
  'kg',
  'mL',
  'L',
  'bottle',
  'pack',
  'box',
  'bag',
  'sack',
  'tray',
  'dozen',
  'can',
  'jar',
  'roll',
  'OTHER',
];

class TwelveApp extends StatelessWidget {
  const TwelveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Twelve Cafe Inventory',
      debugShowCheckedModeBanner: false,
      theme: buildCafeTheme(brightness: Brightness.light),
      darkTheme: buildCafeTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const Gate(),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Supabase.instance.client.auth.currentSession == null
        ? const LoginPage()
        : const Shell();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Sign in failed. Check your email and password.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: CafeColors.espresso,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: CafeColors.paper,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Image.asset('assets/the_twelve_cafe_logo.png', fit: BoxFit.contain),
                        ),
                        const Spacer(),
                        Text(
                          'Inventory that keeps\nup with the café.',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.04,
                                letterSpacing: -1.2,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Track counts, stock movements, restocking and accountability from one shared workspace.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white.withAlpha(205),
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 38),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: const [
                            _HeroPill(icon: Icons.sync_rounded, text: 'Shared inventory'),
                            _HeroPill(icon: Icons.history_rounded, text: 'Traceable changes'),
                            _HeroPill(icon: Icons.devices_rounded, text: 'Any device, one workspace'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!wide) ...[
                          Align(
                            child: Container(
                              width: 126,
                              height: 126,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CafeColors.paper,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: scheme.outline),
                              ),
                              child: Image.asset('assets/the_twelve_cafe_logo.png', fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                        Text(
                          'Welcome back',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.7,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Sign in to The Twelve Cafe Inventory.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 30),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          onSubmitted: (_) => loading ? null : signIn(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: obscure ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => obscure = !obscure),
                              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text(error!, style: TextStyle(color: scheme.onErrorContainer))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: loading ? null : signIn,
                          icon: loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(loading ? 'Signing in…' : 'Sign in'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Use the staff account provided by your café administrator.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final repo = InventoryRepository();
  int tab = 0;
  int revision = 0;
  bool loading = true;
  String? error;
  String role = 'staff';
  String displayName = '';
  List<InventoryItem> items = [];

  static const labels = [
    'Dashboard',
    'Inventory',
    'Categories',
    'Units',
    'Restock',
    'Activity',
    'Employees',
    'Reports',
    'Settings',
  ];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final found = await repo.fetch();
      final profile = await repo.myProfile();
      if (mounted) {
        setState(() {
          items = found;
          role = (profile['role'] ?? 'staff').toString();
          displayName = (profile['display_name'] ?? '').toString();
          revision++;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load inventory. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openAddItem() async {
    if (role == 'staff') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A manager or admin is required to add inventory items.')));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemPage(onCreated: refresh)));
  }

  void openItem(InventoryItem item, {String? initialAction}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemPage(item: item, role: role, onChanged: refresh, initialAction: initialAction),
      ),
    );
  }

  Future<void> showGlobalSearch() async {
    final controller = TextEditingController();
    var query = '';
    final selected = await showDialog<InventoryItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalized = query.trim().toLowerCase();
          final matches = items.where((item) {
            if (normalized.isEmpty) return true;
            return [item.name, item.code, item.category ?? '', item.storageLocation ?? '', item.supplierName ?? '', item.barcode ?? '', item.type]
                .any((value) => value.toLowerCase().contains(normalized));
          }).take(20).toList();
          return AlertDialog(
            title: const Text('Search inventory'),
            content: SizedBox(
              width: 620,
              height: 470,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (value) => setDialogState(() => query = value),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search item, ID, category, supplier, barcode…'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: matches.isEmpty
                        ? const EmptyState(icon: Icons.search_off_rounded, title: 'No matching item', message: 'Try a different name, ID, category, supplier, or barcode.')
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = matches[index];
                              return ListTile(
                                leading: const Icon(Icons.inventory_2_outlined),
                                title: Text(item.name),
                                subtitle: Text('${item.code} • ${item.stockText}'),
                                trailing: StatusChip(status: item.status),
                                onTap: () => Navigator.pop(dialogContext, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    if (selected != null && mounted) openItem(selected);
  }

  Future<void> showAttention() async {
    final attention = items.where((item) => ['LOW STOCK', 'OUT OF STOCK', 'UNRECORDED'].contains(item.status)).toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs attention', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${attention.length} inventory records need review.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Flexible(
                  child: attention.isEmpty
                      ? const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Everything looks good', message: 'No low-stock, out-of-stock, or unrecorded items need attention.')
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: attention.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = attention[index];
                            return ListTile(
                              title: Text(item.name),
                              subtitle: Text(item.stockText),
                              trailing: StatusChip(status: item.status),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                openItem(item);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pickItemForAction(String action) async {
    if (action == 'INITIAL_COUNT' && role == 'staff') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A manager or admin is required to record an initial count.')));
      return;
    }
    var choices = items;
    if (action == 'INITIAL_COUNT') choices = items.where((item) => item.quantity == null).toList();
    if (action == 'STOCK_IN' || action == 'STOCK_OUT') choices = items.where((item) => item.quantity != null).toList();
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No suitable inventory items are available for this action.')));
      return;
    }

    final selected = await showDialog<InventoryItem>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = choices.where((item) => item.name.toLowerCase().contains(query.toLowerCase()) || item.code.toLowerCase().contains(query.toLowerCase())).take(30).toList();
            return AlertDialog(
              title: Text(switch (action) {'INITIAL_COUNT' => 'Record count', 'STOCK_IN' => 'Stock in', _ => 'Stock out'}),
              content: SizedBox(
                width: 560,
                height: 430,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (value) => setDialogState(() => query = value),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Choose an inventory item'),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text('${item.code} • ${item.stockText}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(dialogContext, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) openItem(selected, initialAction: action);
  }

  Widget screenForTab() => switch (tab) {
        0 => DashboardPage(
            items: items,
            repo: repo,
            role: role,
            revision: revision,
            onOpenItem: openItem,
            onAddItem: openAddItem,
            onInventory: () => setState(() => tab = 1),
            onRestock: () => setState(() => tab = 4),
            onActivity: () => setState(() => tab = 5),
            onInitialCount: () => pickItemForAction('INITIAL_COUNT'),
            onStockIn: () => pickItemForAction('STOCK_IN'),
            onStockOut: () => pickItemForAction('STOCK_OUT'),
          ),
        1 => InventoryList(items: items, role: role, onOpen: openItem, onAdd: openAddItem),
        2 => CategoriesPage(items: items, onOpenItem: openItem),
        3 => UnitsPage(items: items, onOpenItem: openItem),
        4 => RestockPage(repo: repo, items: items, role: role, onChanged: refresh),
        5 => ActivityPage(repo: repo),
        6 => EmployeesPage(repo: repo),
        7 => ReportsPage(items: items, repo: repo),
        _ => _more(),
      };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 980;
    final attentionCount = items.where((item) => ['LOW STOCK', 'OUT OF STOCK', 'UNRECORDED'].contains(item.status)).length;
    final user = Supabase.instance.client.auth.currentUser;
    final name = displayName.trim().isNotEmpty ? displayName.trim() : (user?.email?.split('@').first ?? 'Employee');
    const mobileTabs = [0, 1, 4, 5, 8];
    final mobileIndex = mobileTabs.contains(tab) ? mobileTabs.indexOf(tab) : 4;

    return Scaffold(
      drawer: desktop
          ? null
          : Drawer(
              child: SafeArea(
                child: _MobileNavigation(
                  selected: tab,
                  onSelected: (value) {
                    Navigator.pop(context);
                    setState(() => tab = value);
                  },
                  onSignOut: () => Supabase.instance.client.auth.signOut(),
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (desktop)
              _DesktopSidebar(
                selected: tab,
                onSelected: (value) => setState(() => tab = value),
                onSignOut: () => Supabase.instance.client.auth.signOut(),
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    desktop: desktop,
                    pageTitle: labels[tab],
                    userName: name,
                    role: role,
                    attentionCount: attentionCount,
                    onSearch: showGlobalSearch,
                    onNotifications: showAttention,
                    onRefresh: refresh,
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1540),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: loading
                              ? const _LoadingView(key: ValueKey('loading'))
                              : error != null
                                  ? EmptyState(
                                      key: const ValueKey('error'),
                                      icon: Icons.cloud_off_rounded,
                                      title: 'Inventory could not load',
                                      message: error!,
                                      action: FilledButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                                    )
                                  : KeyedSubtree(key: ValueKey(tab), child: screenForTab()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: mobileIndex,
              onDestinationSelected: (index) => setState(() => tab = mobileTabs[index]),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
                NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping_rounded), label: 'Restock'),
                NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Activity'),
                NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
              ],
            ),
    );
  }

  Future<void> editDisplayName() async {
    try {
      final profile = await repo.myProfile();
      if (!mounted) return;
      final controller = TextEditingController(text: (profile['display_name'] ?? '').toString());
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Employee display name'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('This name appears in Activity so managers can clearly see who performed stock changes.'),
                const SizedBox(height: 14),
                TextField(controller: controller, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Display name', hintText: 'Example: Paul D.')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      );
      if (confirmed != true) return;
      if (controller.text.trim().isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a display name.')));
        return;
      }
      await repo.updateMyDisplayName(controller.text.trim());
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee display name updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update profile: $e')));
    }
  }

  Widget _more() {
    final user = Supabase.instance.client.auth.currentUser;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
      children: [
        const PageHeader(title: 'Settings & More', subtitle: 'Account, organization views, and workspace settings.'),
        const SizedBox(height: 18),
        SectionCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: CafeColors.creamDeep,
                foregroundColor: CafeColors.espresso,
                child: Text((displayName.trim().isNotEmpty ? displayName.trim()[0] : (user?.email?.isNotEmpty == true ? user!.email![0] : 'U')).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(displayName.trim().isNotEmpty ? displayName.trim() : user?.email ?? 'Signed-in user', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
              ),
              StatusPill(label: role.toUpperCase(), tone: StatusTone.neutral),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 760 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
            final links = <({String title, String subtitle, IconData icon, int tab})>[
              (title: 'Categories', subtitle: 'Review inventory groups and their health.', icon: Icons.category_outlined, tab: 2),
              (title: 'Units', subtitle: 'Review measurement units and pack conversions.', icon: Icons.straighten_outlined, tab: 3),
              (title: 'Employees', subtitle: 'See staff profiles used for accountability.', icon: Icons.people_outline_rounded, tab: 6),
              (title: 'Reports', subtitle: 'See inventory and audit summaries.', icon: Icons.bar_chart_rounded, tab: 7),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final link in links)
                  SizedBox(
                    width: width,
                    child: SectionCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _SettingsIcon(icon: link.icon),
                        title: Text(link.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(link.subtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => setState(() => tab = link.tab),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const _SettingsIcon(icon: Icons.badge_outlined),
                title: const Text('Employee display name'),
                subtitle: const Text('Used in the Activity log for accountability.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: editDisplayName,
              ),
              if (role != 'staff') ...[
                const Divider(height: 1, indent: 68),
                ListTile(
                  leading: const _SettingsIcon(icon: Icons.archive_outlined),
                  title: const Text('Archived inventory'),
                  subtitle: const Text('Restore discontinued or accidentally archived items.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArchivedItemsPage(onChanged: refresh))),
                ),
              ],
              const Divider(height: 1, indent: 68),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.logout_rounded, danger: true),
                title: const Text('Sign out'),
                subtitle: const Text('End this session on the current device.'),
                onTap: () => Supabase.instance.client.auth.signOut(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.selected, required this.onSelected, required this.onSignOut});
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    const nav = [
      (0, 'Dashboard', Icons.dashboard_outlined),
      (1, 'Inventory', Icons.inventory_2_outlined),
      (2, 'Categories', Icons.category_outlined),
      (3, 'Units', Icons.straighten_outlined),
      (4, 'Restock', Icons.local_shipping_outlined),
      (5, 'Activity', Icons.history_rounded),
      (6, 'Employees', Icons.people_outline_rounded),
      (7, 'Reports', Icons.bar_chart_rounded),
    ];
    return Container(
      width: 238,
      color: CafeColors.espressoDeep,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Container(
              height: 122,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: CafeColors.paper, borderRadius: BorderRadius.circular(18)),
              child: Image.asset('assets/the_twelve_cafe_logo.png', fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const _SidebarLabel('WORKSPACE'),
                const SizedBox(height: 8),
                for (final entry in nav)
                  _SidebarItem(label: entry.$2, icon: entry.$3, selected: selected == entry.$1, onTap: () => onSelected(entry.$1)),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFF5A4940), height: 1),
                const SizedBox(height: 14),
                _SidebarItem(label: 'Settings', icon: Icons.settings_outlined, selected: selected == 8, onTap: () => onSelected(8)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            child: Column(
              children: [
                _SidebarItem(label: 'Logout', icon: Icons.logout_rounded, selected: false, onTap: onSignOut),
                const SizedBox(height: 14),
                Text('GOOD COFFEE • BETTER DAYS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withAlpha(105), fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: TextStyle(color: Colors.white.withAlpha(105), fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
      );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? const Color(0xFF725846) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? Colors.white : Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.selected, required this.onSelected, required this.onSignOut});
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (0, 'Dashboard', Icons.dashboard_outlined),
      (1, 'Inventory', Icons.inventory_2_outlined),
      (2, 'Categories', Icons.category_outlined),
      (3, 'Units', Icons.straighten_outlined),
      (4, 'Restock', Icons.local_shipping_outlined),
      (5, 'Activity', Icons.history_rounded),
      (6, 'Employees', Icons.people_outline_rounded),
      (7, 'Reports', Icons.bar_chart_rounded),
      (8, 'Settings', Icons.settings_outlined),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(height: 110, child: Image.asset('assets/the_twelve_cafe_logo.png', fit: BoxFit.contain)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final entry in entries)
                ListTile(
                  leading: Icon(entry.$3),
                  title: Text(entry.$2),
                  selected: selected == entry.$1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => onSelected(entry.$1),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Logout'), onTap: onSignOut),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.desktop, required this.pageTitle, required this.userName, required this.role, required this.attentionCount, required this.onSearch, required this.onNotifications, required this.onRefresh});
  final bool desktop;
  final String pageTitle;
  final String userName;
  final String role;
  final int attentionCount;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: desktop ? 82 : 68,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 26 : 12),
      decoration: BoxDecoration(color: scheme.surface, border: Border(bottom: BorderSide(color: scheme.outline.withAlpha(135)))),
      child: Row(
        children: [
          if (!desktop) ...[
            Builder(builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu_rounded))),
            const SizedBox(width: 4),
          ],
          if (desktop)
            Expanded(
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withAlpha(115), borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outline.withAlpha(130))),
                  child: Row(children: [const Icon(Icons.search_rounded, size: 21), const SizedBox(width: 10), Expanded(child: Text('Search item, ID, supplier, barcode…', style: TextStyle(color: scheme.onSurfaceVariant))), const _ShortcutBadge()]),
                ),
              ),
            )
          else
            Expanded(child: Text(pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          const Spacer(),
          if (!desktop) IconButton(onPressed: onSearch, icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: onRefresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(onPressed: onNotifications, tooltip: 'Needs attention', icon: const Icon(Icons.notifications_none_rounded)),
              if (attentionCount > 0)
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: CafeColors.danger, borderRadius: BorderRadius.circular(99), border: Border.all(color: scheme.surface, width: 2)),
                    child: Center(child: Text(attentionCount > 99 ? '99+' : '$attentionCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 8))),
                  ),
                ),
            ],
          ),
          if (desktop) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 34, color: scheme.outline),
            const SizedBox(width: 15),
            CircleAvatar(radius: 20, backgroundColor: CafeColors.creamDeep, foregroundColor: CafeColors.espresso, child: Text(userName.isEmpty ? 'U' : userName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900))),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(titleCaseCode(role), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: Theme.of(context).colorScheme.outline)),
        child: Text('Search', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}


class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Loading inventory…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, this.danger = false});
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'AVAILABLE' => StatusTone.success,
      'LOW STOCK' => StatusTone.warning,
      'OUT OF STOCK' => StatusTone.danger,
      _ => StatusTone.neutral,
    };
    return StatusPill(label: status, tone: tone);
  }
}

class InventoryList extends StatefulWidget {
  const InventoryList({super.key, required this.items, required this.role, required this.onOpen, required this.onAdd});
  final List<InventoryItem> items;
  final String role;
  final void Function(InventoryItem) onOpen;
  final Future<void> Function() onAdd;

  @override
  State<InventoryList> createState() => _InventoryListState();
}

class _InventoryListState extends State<InventoryList> {
  final search = TextEditingController();
  String filter = 'All Inventory';
  String status = 'All';
  String sort = 'Name A–Z';
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<InventoryItem> get filteredItems {
    final data = widget.items
        .where(
          (item) =>
              (filter == 'All Inventory' || item.type == filter) &&
              (status == 'All' || item.status == status) &&
              (item.name.toLowerCase().contains(query.toLowerCase()) ||
                  item.code.toLowerCase().contains(query.toLowerCase()) ||
                  item.type.toLowerCase().contains(query.toLowerCase()) ||
                  (item.category ?? '').toLowerCase().contains(query.toLowerCase()) ||
                  (item.storageLocation ?? '').toLowerCase().contains(query.toLowerCase()) ||
                  (item.supplierName ?? '').toLowerCase().contains(query.toLowerCase()) ||
                  (item.barcode ?? '').toLowerCase().contains(query.toLowerCase())),
        )
        .toList();

    switch (sort) {
      case 'Name Z–A':
        data.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'Lowest Stock':
        data.sort((a, b) => (a.quantity ?? double.infinity).compareTo(b.quantity ?? double.infinity));
        break;
      case 'Highest Stock':
        data.sort((a, b) => (b.quantity ?? -1).compareTo(a.quantity ?? -1));
        break;
      case 'Status':
        data.sort((a, b) => a.status.compareTo(b.status));
        break;
      case 'Recently Updated':
        data.sort((a, b) {
          final ad = DateTime.tryParse(a.updatedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse(b.updatedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        break;
      default:
        data.sort((a, b) => a.name.compareTo(b.name));
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final data = filteredItems;
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 12, wide ? 24 : 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Inventory',
                    subtitle: '${data.length} of ${widget.items.length} items shown',
                    trailing: widget.role == 'staff'
                        ? null
                        : FilledButton.icon(
                            onPressed: widget.onAdd,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add item'),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: search,
                          onChanged: (value) => setState(() => query = value),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: 'Search name, ID, barcode, storage or supplier',
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      search.clear();
                                      setState(() => query = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        tooltip: 'Sort inventory',
                        initialValue: sort,
                        onSelected: (value) => setState(() => sort = value),
                        itemBuilder: (_) => ['Name A–Z', 'Name Z–A', 'Lowest Stock', 'Highest Stock', 'Recently Updated', 'Status']
                            .map((value) => PopupMenuItem(value: value, child: Text(value)))
                            .toList(),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outline)),
                          child: const Row(children: [Icon(Icons.sort_rounded), SizedBox(width: 8), Text('Sort', style: TextStyle(fontWeight: FontWeight.w700))]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterMenu(
                          icon: Icons.layers_outlined,
                          value: filter,
                          values: const ['All Inventory', 'General Inventory', 'Production Inventory'],
                          onChanged: (value) => setState(() => filter = value),
                        ),
                        const SizedBox(width: 8),
                        _FilterMenu(
                          icon: Icons.tune_rounded,
                          value: status,
                          values: const ['All', 'AVAILABLE', 'LOW STOCK', 'OUT OF STOCK', 'UNRECORDED', 'THRESHOLD NOT SET'],
                          onChanged: (value) => setState(() => status = value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching inventory item',
                      message: 'Try another search term or clear one of the active filters.',
                    )
                  : wide
                      ? _InventoryTable(items: data, onOpen: widget.onOpen)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: data.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 9),
                          itemBuilder: (context, index) {
                            final item = data[index];
                            return _InventoryCard(item: item, onTap: () => widget.onOpen(item));
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.icon, required this.value, required this.values, required this.onChanged});
  final IconData icon;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => values.map((entry) => PopupMenuItem(value: entry, child: Text(titleCaseCode(entry)))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(titleCaseCode(value), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onTap});
  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.inventory_2_outlined, color: scheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${item.code} • ${item.type}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 7),
                    Text(item.stockText, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(status: item.status),
                  const SizedBox(height: 9),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.items, required this.onOpen});
  final List<InventoryItem> items;
  final void Function(InventoryItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800),
                child: const Row(
                  children: [
                    Expanded(flex: 4, child: Text('ITEM')),
                    Expanded(flex: 2, child: Text('CATEGORY')),
                    Expanded(flex: 2, child: Text('QUANTITY')),
                    Expanded(flex: 2, child: Text('STATUS')),
                    SizedBox(width: 32),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 18, endIndent: 18),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: () => onOpen(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(item.code, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(item.type)),
                          Expanded(flex: 2, child: Text(item.stockText, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: StatusChip(status: item.status))),
                          const SizedBox(width: 32, child: Icon(Icons.chevron_right_rounded, size: 20)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItemPage extends StatefulWidget {
  const ItemPage({super.key, required this.item, required this.role, required this.onChanged, this.initialAction});
  final InventoryItem item;
  final String role;
  final Future<void> Function() onChanged;
  final String? initialAction;

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  final repo = InventoryRepository();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) movement(widget.initialAction!);
      });
    }
  }

  void notify(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  List<String> unitOptions(String? current) {
    final values = commonUnits.where((unit) => unit != 'OTHER').toList();
    if (current != null && current.trim().isNotEmpty && !values.contains(current)) values.insert(0, current);
    values.add('OTHER');
    return values;
  }

  Future<void> editItem() async {
    final name = TextEditingController(text: widget.item.name);
    final customBase = TextEditingController();
    final customPack = TextEditingController();
    final factor = TextEditingController(text: widget.item.unitsPerPack?.toString() ?? '');
    final min = TextEditingController(text: widget.item.minimum?.toString() ?? '');
    final target = TextEditingController(text: widget.item.target?.toString() ?? '');
    final notes = TextEditingController(text: widget.item.notes ?? '');
    final category = TextEditingController(text: widget.item.category ?? '');
    final storageLocation = TextEditingController(text: widget.item.storageLocation ?? '');
    final supplierName = TextEditingController(text: widget.item.supplierName ?? '');
    final barcode = TextEditingController(text: widget.item.barcode ?? '');

    final baseOptions = unitOptions(widget.item.unit);
    final packOptions = unitOptions(widget.item.packUnit);
    String selectedBase = widget.item.unit?.isNotEmpty == true ? widget.item.unit! : 'pcs';
    String selectedPack = widget.item.packUnit?.isNotEmpty == true ? widget.item.packUnit! : 'pack';
    bool hasPack = widget.item.packUnit != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit item settings'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name', prefixIcon: Icon(Icons.inventory_2_outlined))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: baseOptions.contains(selectedBase) ? selectedBase : 'OTHER',
                    decoration: const InputDecoration(labelText: 'Base stock unit', prefixIcon: Icon(Icons.straighten_rounded)),
                    items: baseOptions.map((unit) => DropdownMenuItem(value: unit, child: Text(unit == 'OTHER' ? 'Other / custom unit' : unit))).toList(),
                    onChanged: (value) => setDialogState(() => selectedBase = value!),
                  ),
                  if (selectedBase == 'OTHER') ...[
                    const SizedBox(height: 12),
                    TextField(controller: customBase, decoration: const InputDecoration(labelText: 'Custom base unit', hintText: 'Example: tub, bundle, cup')),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: hasPack,
                    title: const Text('Use a purchase / pack unit', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Example: 1 pack = 12 pcs or 1 sack = 25 kg'),
                    onChanged: (value) => setDialogState(() => hasPack = value),
                  ),
                  if (hasPack) ...[
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      initialValue: packOptions.contains(selectedPack) ? selectedPack : 'OTHER',
                      decoration: const InputDecoration(labelText: 'Purchase unit'),
                      items: packOptions.map((unit) => DropdownMenuItem(value: unit, child: Text(unit == 'OTHER' ? 'Other / custom unit' : unit))).toList(),
                      onChanged: (value) => setDialogState(() => selectedPack = value!),
                    ),
                    if (selectedPack == 'OTHER') ...[
                      const SizedBox(height: 12),
                      TextField(controller: customPack, decoration: const InputDecoration(labelText: 'Custom purchase unit', hintText: 'Example: case, pouch')),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: factor,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Base units in one purchase unit',
                        helperText: 'Only enter a verified conversion. Example: 1 pack = 12 pieces.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: min, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum stock'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target stock'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: category, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined), hintText: 'Example: Dairy, Sauces, Packaging')),
                  const SizedBox(height: 12),
                  TextField(controller: storageLocation, decoration: const InputDecoration(labelText: 'Storage location', prefixIcon: Icon(Icons.location_on_outlined), hintText: 'Example: Chiller, Dry Storage, Kitchen')),
                  const SizedBox(height: 12),
                  TextField(controller: supplierName, decoration: const InputDecoration(labelText: 'Preferred supplier', prefixIcon: Icon(Icons.local_shipping_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: barcode, decoration: const InputDecoration(labelText: 'Barcode / QR value', prefixIcon: Icon(Icons.qr_code_2_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save changes')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final baseUnit = selectedBase == 'OTHER' ? customBase.text.trim() : selectedBase;
    final packUnit = !hasPack ? null : (selectedPack == 'OTHER' ? customPack.text.trim() : selectedPack);
    final packSize = hasPack ? double.tryParse(factor.text) : null;

    if (name.text.trim().isEmpty ||
        baseUnit.isEmpty ||
        (hasPack && (packUnit == null || packUnit.isEmpty || (packSize ?? 0) <= 0)) ||
        (min.text.isNotEmpty && double.tryParse(min.text) == null) ||
        (target.text.isNotEmpty && double.tryParse(target.text) == null)) {
      notify('Check the item name, units, conversion and stock levels.');
      return;
    }

    setState(() => busy = true);
    try {
      await repo.editItem(
        item: widget.item,
        name: name.text.trim(),
        baseUnit: baseUnit,
        packUnit: packUnit,
        packSize: packSize,
        minimum: double.tryParse(min.text),
        target: double.tryParse(target.text),
        notes: notes.text.trim(),
        category: category.text.trim().isEmpty ? null : category.text.trim(),
        storageLocation: storageLocation.text.trim().isEmpty ? null : storageLocation.text.trim(),
        supplierName: supplierName.text.trim().isEmpty ? null : supplierName.text.trim(),
        barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
      );
      await widget.onChanged();
      if (mounted) {
        notify('Item settings saved.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notify('Unable to save: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestRestock() async {
    final suggested = widget.item.target != null && widget.item.quantity != null
        ? (widget.item.target! - widget.item.quantity!).clamp(0, double.infinity)
        : null;
    final amount = TextEditingController(text: suggested != null && suggested > 0 ? suggested.toStringAsFixed(suggested % 1 == 0 ? 0 : 2) : '');
    final detail = TextEditingController();
    String reason = widget.item.status == 'OUT OF STOCK'
        ? 'OUT_OF_STOCK'
        : widget.item.status == 'LOW STOCK'
            ? 'LOW_STOCK'
            : 'ROUTINE_REPLENISHMENT';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create restock request'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogItemSummary(item: widget.item),
                const SizedBox(height: 15),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Requested quantity (${widget.item.unit ?? 'units'})'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason for restock'),
                  items: restockReasons.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) => setDialogState(() => reason = value!),
                ),
                if (reason == 'OTHER') ...[
                  const SizedBox(height: 12),
                  TextField(controller: detail, maxLines: 2, decoration: const InputDecoration(labelText: 'Explain the reason')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit request')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final quantity = double.tryParse(amount.text);
    if (quantity == null || quantity <= 0 || (reason == 'OTHER' && detail.text.trim().isEmpty)) {
      notify('Enter a valid quantity and reason.');
      return;
    }

    setState(() => busy = true);
    try {
      await repo.requestRestock(widget.item, quantity, reason: reason, details: detail.text.trim());
      if (mounted) notify('Restock request created.');
    } catch (e) {
      if (mounted) notify('Unable to request restock: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> movement(String kind) async {
    final amount = TextEditingController();
    final detail = TextEditingController();
    final initial = kind == 'INITIAL_COUNT';
    final units = <String>[widget.item.unit ?? 'unit', if (widget.item.packUnit != null && widget.item.unitsPerPack != null) widget.item.packUnit!];
    String selectedUnit = units.first;
    final reasons = kind == 'STOCK_OUT' ? stockOutReasons : stockInReasons;
    String? reason = initial ? null : reasons.keys.first;

    String noteLabel() {
      if (initial) return 'Optional note';
      if (reason == 'OTHER') return 'Explain the reason';
      return switch (reason) {
        'EXPIRED' => 'Expiry / batch note (optional)',
        'DAMAGED' => 'Damage details (optional)',
        'SPOILED' => 'Spoilage details (optional)',
        'SPILLED' => 'Spill details (optional)',
        'LOST' => 'Loss details (optional)',
        'DELIVERY' => 'Delivery reference (optional)',
        'PURCHASE' => 'Receipt / purchase note (optional)',
        _ => 'Additional notes (optional)',
      };
    }

    String noteHint() {
      if (initial) return 'Example: Opening inventory verified by physical count';
      return switch (reason) {
        'EXPIRED' => 'Example: Expired Oct 16 • Batch 24A',
        'DAMAGED' => 'Example: Seal broken during delivery',
        'SPOILED' => 'Example: Discoloration found during prep',
        'SPILLED' => 'Example: Spilled during service',
        'LOST' => 'Example: Missing during closing count',
        'DELIVERY' => 'Example: Supplier invoice or delivery reference',
        'PURCHASE' => 'Example: Receipt number or store name',
        _ => 'Add useful context only when needed',
      };
    }

    final form = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(initial ? 'Record physical count' : kind == 'STOCK_OUT' ? 'Stock out' : 'Stock in'),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DialogItemSummary(item: widget.item),
                  const SizedBox(height: 15),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: initial ? 'Physical count${widget.item.unit?.trim().isNotEmpty == true ? ' (${widget.item.unit})' : ''}' : 'Quantity',
                      prefixIcon: const Icon(Icons.numbers_rounded),
                    ),
                  ),
                  if (!initial) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Measurement unit', prefixIcon: Icon(Icons.straighten_rounded)),
                      items: units.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                      onChanged: (value) => setDialogState(() => selectedUnit = value!),
                    ),
                    if (widget.item.packUnit != null) ...[
                      const SizedBox(height: 8),
                      Text('1 ${widget.item.packUnit} = ${widget.item.unitsPerPack} ${widget.item.unit}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ],
                  if (!initial) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration: const InputDecoration(labelText: 'Reason', prefixIcon: Icon(Icons.fact_check_outlined)),
                      items: reasons.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                      onChanged: (value) => setDialogState(() => reason = value!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: detail,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: noteLabel(),
                      hintText: noteHint(),
                    ),
                  ),
                  if (initial) ...[
                    const SizedBox(height: 8),
                    Text(
                      'This count will be saved to Activity with your employee account.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _EmployeeNotice(email: Supabase.instance.client.auth.currentUser?.email ?? 'Signed-in employee'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Review')),
          ],
        ),
      ),
    );

    if (form != true || !mounted) return;
    final quantity = double.tryParse(amount.text);
    if (quantity == null || (initial ? quantity < 0 : quantity <= 0) || (!initial && reason == 'OTHER' && detail.text.trim().isEmpty)) {
      notify(initial ? 'Enter a valid physical count.' : 'Enter a valid quantity and reason.');
      return;
    }

    final standardized = selectedUnit == widget.item.packUnit ? quantity * (widget.item.unitsPerPack ?? 1) : quantity;
    final change = kind == 'STOCK_OUT' ? -standardized : standardized;
    final resulting = widget.item.quantity == null ? null : widget.item.quantity! + change;
    if (!initial && resulting != null && resulting < 0) {
      notify('Cannot remove more than the available stock.');
      return;
    }

    final employee = Supabase.instance.client.auth.currentUser?.email ?? 'Signed-in user';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial ? 'Confirm physical count' : 'Confirm stock movement'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConfirmRow(label: 'Item', value: widget.item.name),
              _ConfirmRow(label: 'Entered', value: '$quantity $selectedUnit'),
              _ConfirmRow(label: initial ? 'New count' : 'Base change', value: initial ? '$quantity ${widget.item.unit ?? ''}' : '$change ${widget.item.unit ?? 'units'}'),
              if (!initial) _ConfirmRow(label: 'Result', value: resulting?.toString() ?? 'Unrecorded'),
              if (!initial) _ConfirmRow(label: 'Reason', value: reasons[reason] ?? reason ?? ''),
              if (detail.text.trim().isNotEmpty) _ConfirmRow(label: 'Notes', value: detail.text.trim()),
              _ConfirmRow(label: 'Responsible', value: employee),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (approved != true) return;
    setState(() => busy = true);
    try {
      if (initial) {
        await repo.client.rpc(
          'initialize_count',
          params: {
            'p_item_id': widget.item.id,
            'p_count': quantity,
            'p_expected_version': widget.item.version,
            'p_reason': 'First physical inventory${detail.text.trim().isEmpty ? '' : ': ${detail.text.trim()}'}',
          },
        );
      } else {
        await repo.stockV2(
          item: widget.item,
          direction: kind == 'STOCK_OUT' ? 'OUT' : 'IN',
          amount: quantity,
          unit: selectedUnit,
          reason: reason!,
          detail: detail.text.trim(),
        );
      }
      await widget.onChanged();
      if (mounted) {
        notify('Inventory updated and employee recorded.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notify('Could not save: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }


  Future<void> adjustPhysicalCount() async {
    if (widget.item.quantity == null) {
      notify('Record the first physical count before using adjustments.');
      return;
    }
    final count = TextEditingController(text: widget.item.quantity!.toString());
    final detail = TextEditingController();
    String reason = 'PHYSICAL_RECOUNT';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust physical count'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogItemSummary(item: widget.item),
                const SizedBox(height: 14),
                TextField(
                  controller: count,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Verified physical count (${widget.item.unit ?? 'units'})'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason for correction'),
                  items: adjustmentReasons.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) => setDialogState(() => reason = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detail,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: reason == 'OTHER' ? 'Explanation *' : 'Notes (optional)',
                    hintText: 'What caused the difference?',
                  ),
                ),
                const SizedBox(height: 12),
                const _EmployeeNotice(email: 'Signed-in manager / admin'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Review adjustment')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final physical = double.tryParse(count.text);
    if (physical == null || physical < 0 || (reason == 'OTHER' && detail.text.trim().isEmpty)) {
      notify('Enter a valid physical count and reason.');
      return;
    }
    final difference = physical - widget.item.quantity!;
    if (difference == 0) {
      notify('The physical count already matches the recorded quantity.');
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm inventory correction'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConfirmRow(label: 'Recorded', value: widget.item.stockText),
              _ConfirmRow(label: 'Physical', value: '$physical ${widget.item.unit ?? ''}'),
              _ConfirmRow(label: 'Difference', value: '${difference > 0 ? '+' : ''}$difference ${widget.item.unit ?? ''}'),
              _ConfirmRow(label: 'Reason', value: adjustmentReasons[reason] ?? reason),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply correction')),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => busy = true);
    try {
      await repo.adjustPhysicalCount(
        item: widget.item,
        physicalCount: physical,
        reason: reason,
        detail: detail.text.trim(),
      );
      await widget.onChanged();
      if (mounted) {
        notify('Physical count corrected and logged.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notify('Could not adjust inventory: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> archiveItem() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this item?'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.item.name} will disappear from active inventory, but its complete transaction history will be preserved.'),
              const SizedBox(height: 14),
              TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason for archiving *', hintText: 'Example: Product discontinued')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive item')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (reason.text.trim().isEmpty) {
      notify('Enter a reason for archiving the item.');
      return;
    }
    setState(() => busy = true);
    try {
      await repo.archiveItem(widget.item, reason.text.trim());
      await widget.onChanged();
      if (mounted) {
        notify('${widget.item.name} archived.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notify('Could not archive item: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final manager = widget.role != 'staff';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item details'),
        actions: [
          if (manager)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(tooltip: 'Edit item', onPressed: busy ? null : editItem, icon: const Icon(Icons.edit_outlined)),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(17)),
                          child: Icon(Icons.inventory_2_outlined, color: scheme.onPrimaryContainer, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.4)),
                              const SizedBox(height: 5),
                              Text('${item.code} • ${item.type}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        StatusChip(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text('CURRENT STOCK', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800, letterSpacing: .6)),
                    const SizedBox(height: 6),
                    Text(item.stockText, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    _InfoGrid(item: item),
                  ],
                ),
              ),
              if (item.notes?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 14),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 7),
                      Text(item.notes!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                    ],
                  ),
                ),
              ],
            ],
          );

          final actions = SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Every stock change is recorded with the signed-in employee.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 18),
                if (busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 14),
                ],
                if (item.quantity == null && manager)
                  FilledButton.icon(onPressed: busy ? null : () => movement('INITIAL_COUNT'), icon: const Icon(Icons.fact_check_outlined), label: const Text('Record initial count')),
                if (item.quantity != null) ...[
                  FilledButton.icon(onPressed: busy ? null : () => movement('STOCK_IN'), icon: const Icon(Icons.add_rounded), label: const Text('Stock in')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: busy ? null : () => movement('STOCK_OUT'), icon: const Icon(Icons.remove_rounded), label: const Text('Stock out / waste')),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: busy ? null : requestRestock, icon: const Icon(Icons.shopping_bag_outlined), label: const Text('Request restock')),
                if (manager) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: busy ? null : editItem, icon: const Icon(Icons.tune_rounded), label: const Text('Edit item settings')),
                  if (item.quantity != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(onPressed: busy ? null : adjustPhysicalCount, icon: const Icon(Icons.rule_rounded), label: const Text('Adjust physical count')),
                  ],
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: busy ? null : archiveItem,
                    icon: Icon(Icons.archive_outlined, color: scheme.error),
                    label: Text('Archive item', style: TextStyle(color: scheme.error)),
                  ),
                ],
                if (item.quantity == null && !manager) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
                    child: Text('Ask a manager to record the first physical count.', style: TextStyle(color: scheme.onSecondaryContainer)),
                  ),
                ],
              ],
            ),
          );

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 12, wide ? 28 : 16, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: details),
                        const SizedBox(width: 16),
                        SizedBox(width: 330, child: actions),
                      ],
                    )
                  : Column(
                      children: [
                        details,
                        const SizedBox(height: 14),
                        actions,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final cells = <({String label, String value, IconData icon})>[
      (label: 'Base unit', value: item.unit ?? 'Not configured', icon: Icons.straighten_rounded),
      (
        label: 'Purchase unit',
        value: item.packUnit == null ? 'Not configured' : '${item.packUnit} • 1 = ${item.unitsPerPack} ${item.unit ?? ''}',
        icon: Icons.inventory_outlined,
      ),
      (label: 'Minimum stock', value: '${item.minimum?.toString() ?? 'Not set'} ${item.unit ?? ''}'.trim(), icon: Icons.arrow_downward_rounded),
      (label: 'Target stock', value: '${item.target?.toString() ?? 'Not set'} ${item.unit ?? ''}'.trim(), icon: Icons.flag_outlined),
      (
        label: 'Suggested restock',
        value: item.target != null && item.quantity != null
            ? '${(item.target! - item.quantity!).clamp(0, double.infinity).toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '')} ${item.unit ?? ''}'.trim()
            : 'Not available',
        icon: Icons.shopping_cart_checkout_rounded,
      ),
      (label: 'Category', value: item.category?.trim().isNotEmpty == true ? item.category! : 'Not set', icon: Icons.category_outlined),
      (label: 'Storage', value: item.storageLocation?.trim().isNotEmpty == true ? item.storageLocation! : 'Not set', icon: Icons.location_on_outlined),
      (label: 'Supplier', value: item.supplierName?.trim().isNotEmpty == true ? item.supplierName! : 'Not set', icon: Icons.local_shipping_outlined),
      (label: 'Barcode / QR', value: item.barcode?.trim().isNotEmpty == true ? item.barcode! : 'Not set', icon: Icons.qr_code_2_rounded),
      (label: 'Last updated', value: prettyDateTime(item.updatedAt), icon: Icons.schedule_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        final gap = 10.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final cell in cells)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(cell.icon, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 10),
                      Text(cell.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 3),
                      Text(cell.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DialogItemSummary extends StatelessWidget {
  const _DialogItemSummary({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: scheme.primaryContainer.withAlpha(110), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: scheme.onPrimaryContainer),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
                const SizedBox(height: 2),
                Text('Current: ${item.stockText}', style: TextStyle(color: scheme.onPrimaryContainer.withAlpha(190))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeNotice extends StatelessWidget {
  const _EmployeeNotice({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 19, color: scheme.primary),
          const SizedBox(width: 9),
          Expanded(child: Text('Responsible employee: $email', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class RestockPage extends StatefulWidget {
  const RestockPage({super.key, required this.repo, required this.items, required this.role, required this.onChanged});
  final InventoryRepository repo;
  final List<InventoryItem> items;
  final String role;
  final Future<void> Function() onChanged;

  @override
  State<RestockPage> createState() => _RestockPageState();
}

class _RestockPageState extends State<RestockPage> {
  late Future<List<Map<String, dynamic>>> records;

  @override
  void initState() {
    super.initState();
    records = widget.repo.restocks();
  }

  void reload() => setState(() => records = widget.repo.restocks());

  Future<void> selectManualRestock() async {
    if (widget.items.isEmpty) return;
    final chosen = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Choose an item', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(item.stockText),
                        trailing: StatusChip(status: item.status),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen != null) await request(chosen);
  }

  Future<void> request(InventoryItem item) async {
    final suggested = item.target != null && item.quantity != null ? (item.target! - item.quantity!).clamp(0, double.infinity).toStringAsFixed(0) : '';
    final amount = TextEditingController(text: suggested);
    final detail = TextEditingController();
    String reason = item.status == 'OUT OF STOCK'
        ? 'OUT_OF_STOCK'
        : item.status == 'LOW STOCK'
            ? 'LOW_STOCK'
            : 'ROUTINE_REPLENISHMENT';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New restock request'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogItemSummary(item: item),
                const SizedBox(height: 14),
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Quantity to request (${item.unit ?? 'units'})')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: restockReasons.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) => setDialogState(() => reason = value!),
                ),
                if (reason == 'OTHER') ...[
                  const SizedBox(height: 12),
                  TextField(controller: detail, decoration: const InputDecoration(labelText: 'Explain the reason')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Request')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final quantity = double.tryParse(amount.text);
    if (quantity == null || quantity <= 0 || (reason == 'OTHER' && detail.text.trim().isEmpty)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity and reason.')));
      return;
    }

    try {
      await widget.repo.requestRestock(item, quantity, reason: reason, details: detail.text.trim());
      reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    }
  }

  Future<void> receive(Map<String, dynamic> request) async {
    final amount = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive delivery'),
        content: TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Actual quantity received')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, amount.text), child: const Text('Confirm receipt')),
        ],
      ),
    );
    final quantity = double.tryParse(result ?? '');
    if (quantity == null || quantity <= 0) return;
    try {
      await widget.repo.receive(request['id'] as String, quantity);
      await widget.onChanged();
      reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Receipt failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsOrdering = widget.items.where((item) => item.status == 'LOW STOCK' || item.status == 'OUT OF STOCK').toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 12, wide ? 24 : 16, 34),
          children: [
            PageHeader(
              title: 'Restock',
              subtitle: 'Turn low stock into clear, trackable purchase requests.',
              trailing: wide
                  ? FilledButton.icon(onPressed: selectManualRestock, icon: const Icon(Icons.add_shopping_cart_rounded), label: const Text('New request'))
                  : null,
            ),
            if (!wide) ...[
              const SizedBox(height: 15),
              FilledButton.icon(onPressed: selectManualRestock, icon: const Icon(Icons.add_shopping_cart_rounded), label: const Text('New restock request')),
            ],
            const SizedBox(height: 24),
            Text('Needs ordering', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 11),
            if (needsOrdering.isEmpty)
              const SectionCard(
                child: EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Nothing needs ordering yet',
                  message: 'Confirmed low and out-of-stock items will appear here. Unrecorded quantities must be counted first.',
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in needsOrdering)
                    SizedBox(
                      width: wide ? 330 : constraints.maxWidth,
                      child: _RestockNeedCard(item: item, onRequest: () => request(item)),
                    ),
                ],
              ),
            const SizedBox(height: 28),
            Text('Requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 11),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: records,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const SectionCard(child: Text('Unable to load restock requests.'));
                }
                if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()));
                if (snapshot.data!.isEmpty) {
                  return const SectionCard(
                    child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No restock requests', message: 'New requests and their delivery progress will appear here.'),
                  );
                }
                return Column(
                  children: [
                    for (final request in snapshot.data!) ...[
                      _RestockRequestCard(
                        request: request,
                        manager: widget.role != 'staff',
                        onOrdered: () async {
                          try {
                            await widget.repo.setRestockStatus(request['id'] as String, 'ORDERED');
                            reload();
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                        onReceive: () => receive(request),
                        onCancel: () async {
                          try {
                            await widget.repo.setRestockStatus(request['id'] as String, 'CANCELLED');
                            reload();
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                      ),
                      const SizedBox(height: 9),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _RestockNeedCard extends StatelessWidget {
  const _RestockNeedCard({required this.item, required this.onRequest});
  final InventoryItem item;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900))), StatusChip(status: item.status)]),
          const SizedBox(height: 8),
          Text(item.stockText, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Target: ${item.target?.toString() ?? 'Not set'} ${item.unit ?? ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: onRequest, icon: const Icon(Icons.add_shopping_cart_rounded), label: const Text('Request'))),
        ],
      ),
    );
  }
}

class _RestockRequestCard extends StatelessWidget {
  const _RestockRequestCard({required this.request, required this.manager, required this.onOrdered, required this.onReceive, required this.onCancel});
  final Map<String, dynamic> request;
  final bool manager;
  final VoidCallback onOrdered;
  final VoidCallback onReceive;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'REQUESTED';
    final received = (request['received_qty'] as num?)?.toDouble() ?? 0;
    final requested = (request['requested_qty'] as num?)?.toDouble() ?? 0;
    final itemName = (request['inventory_items']?['name'] ?? 'Item').toString();
    final reason = request['reason_code']?.toString();
    final notes = request['notes']?.toString();
    final progress = requested <= 0 ? 0.0 : (received / requested).clamp(0, 1).toDouble();
    final tone = switch (status) {
      'RECEIVED' => StatusTone.success,
      'CANCELLED' => StatusTone.neutral,
      'ORDERED' || 'PARTIALLY RECEIVED' => StatusTone.warning,
      _ => StatusTone.neutral,
    };

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(itemName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              StatusPill(label: titleCaseCode(status).toUpperCase(), tone: tone),
            ],
          ),
          if (reason?.isNotEmpty == true) ...[
            const SizedBox(height: 7),
            Text('Reason: ${titleCaseCode(reason!)}', style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(notes!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Row(children: [Expanded(child: Text('$received of $requested received', style: const TextStyle(fontWeight: FontWeight.w700))), Text('${(progress * 100).round()}%')]),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: progress, borderRadius: BorderRadius.circular(99), minHeight: 7),
          if (manager && status != 'RECEIVED' && status != 'CANCELLED') ...[
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'REQUESTED') FilledButton.tonal(onPressed: onOrdered, child: const Text('Mark ordered')),
                OutlinedButton(onPressed: onReceive, child: const Text('Receive delivery')),
                if (received == 0) TextButton(onPressed: onCancel, child: const Text('Cancel request')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.repo});
  final InventoryRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.activity(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load activity', message: 'Try refreshing the app and checking your connection.');
        }
        if (!snapshot.hasData) return const _LoadingView();
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No activity yet', message: 'Stock movements and count changes will appear here.');
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          children: [
            const PageHeader(title: 'Activity', subtitle: 'A traceable history of inventory changes and responsible employees.'),
            const SizedBox(height: 20),
            for (final row in rows) ...[
              _ActivityCard(row: row),
              const SizedBox(height: 9),
            ],
          ],
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final kind = row['kind']?.toString() ?? 'ACTIVITY';
    final name = (row['inventory_items']?['name'] ?? 'Item').toString();
    final reason = (row['reason'] ?? row['reason_code'] ?? '').toString();
    final employee = (row['employee_name'] ?? row['actor'] ?? 'Unknown').toString();
    final before = row['before_qty'] ?? 'Unrecorded';
    final after = row['after_qty'] ?? 'Unrecorded';
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (kind) {
      'STOCK_IN' || 'RESTOCK_RECEIVED' => Icons.add_circle_outline_rounded,
      'STOCK_OUT' => Icons.remove_circle_outline_rounded,
      'INITIAL_COUNT' || 'DAILY_COUNT_ADJUSTMENT' => Icons.fact_check_outlined,
      _ => Icons.swap_horiz_rounded,
    };

    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    const SizedBox(width: 8),
                    StatusPill(label: titleCaseCode(kind).toUpperCase(), tone: StatusTone.neutral),
                  ],
                ),
                const SizedBox(height: 7),
                Text('$before → $after', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('Reason: $reason', style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 14,
                  runSpacing: 5,
                  children: [
                    _Meta(icon: Icons.person_outline_rounded, text: employee),
                    _Meta(icon: Icons.schedule_rounded, text: prettyDateTime(row['created_at'])),
                    if (row['entered_quantity'] != null) _Meta(icon: Icons.straighten_rounded, text: '${row['entered_quantity']} ${row['entered_unit'] ?? ''}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
