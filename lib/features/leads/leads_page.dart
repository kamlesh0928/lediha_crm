import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../followups/followups_page.dart';
import 'lead_detail_page.dart';
import 'lead_form_page.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  String _q = '';
  String _filter = 'all';

  Future<Map<String, dynamic>> _load() async => {
        'leads': await Q.leads(),
        'names': await Q.names(),
      };

  @override
  Widget build(BuildContext context) {
    final admin = AppAuth.instance.isAdmin;
    final filters = ['all', if (admin) 'unassigned', 'hot', ...leadStatuses];

    return Scaffold(
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeadFormPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add TV Lead', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColors.brandRed, size: 20),
                hintText: 'Search TV model, customer name or phone...',
                suffixIcon: _q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _q = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),

          // Horizontal Filter Chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: ChoiceChip(
                      label: Text(label(f)),
                      selected: _filter == f,
                      selectedColor: AppColors.brandRed.withAlpha(25),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _filter == f ? FontWeight.w700 : FontWeight.w500,
                        color: _filter == f ? AppColors.brandRed : AppColors.textPrimary,
                      ),
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),

          // Leads List
          Expanded(
            child: Live<Map<String, dynamic>>(
              load: _load,
              builder: (context, data) {
                final all = data['leads'] as List<Rec>;
                final names = data['names'] as Map<String, String>;
                final phoneCount = <String, int>{};
                for (final l in all) {
                  final n = normPhone(str(l['phone']));
                  if (n.isNotEmpty) phoneCount[n] = (phoneCount[n] ?? 0) + 1;
                }
                final q = _q.trim().toLowerCase();
                final list = all.where((l) {
                  final open = l['status'] != 'converted' && l['status'] != 'lost';
                  final okFilter = switch (_filter) {
                    'all' => true,
                    'unassigned' => l['assigned_to'] == null && open,
                    'hot' => l['priority'] == 'hot' && open,
                    _ => l['status'] == _filter,
                  };
                  if (!okFilter) return false;
                  if (q.isEmpty) return true;
                  return (l['customer_name'] ?? '').toString().toLowerCase().contains(q) ||
                      (l['phone'] ?? '').toString().contains(q) ||
                      (l['tv_brand'] ?? '').toString().toLowerCase().contains(q) ||
                      (l['tv_model'] ?? '').toString().toLowerCase().contains(q) ||
                      (l['issue'] ?? '').toString().toLowerCase().contains(q);
                }).toList();

                if (list.isEmpty) {
                  return const EmptyState('No TV repair leads found matching your search.');
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90, top: 4),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final l = list[i];
                    final dup = (phoneCount[normPhone(str(l['phone']))] ?? 0) > 1;
                    final assignee = names[l['assigned_to']];
                    final phone = str(l['phone']);
                    final tvBrand = str(l['tv_brand']);
                    final tvModel = str(l['tv_model']);
                    final issue = str(l['issue']);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeadDetailPage(leadId: l['id'].toString()),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Customer Name, Duplicate Warning, Status
                              Row(
                                children: [
                                  if (l['priority'] == 'hot') ...[
                                    const Icon(Icons.local_fire_department, size: 18, color: AppColors.brandRed),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      str(l['customer_name']) ?? 'Unnamed Customer',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ),
                                  if (dup) ...[
                                    const Tooltip(
                                      message: 'Possible duplicate phone number',
                                      child: Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Pill(label(str(l['status'])), color: statusColor(str(l['status']))),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // TV Info Badge & Issue
                              Row(
                                children: [
                                  if (tvBrand != null && tvBrand.isNotEmpty) ...[
                                    TvBadge(brand: tvBrand, model: tvModel),
                                    const SizedBox(width: 6),
                                  ],
                                  if (issue != null && issue.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        issue,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Bottom Row: Phone, Area, Assignee & Quick Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${phone ?? 'No phone'}'
                                      '${l['area'] != null ? ' \u00B7 ${l['area']}' : ''}'
                                      '${assignee != null ? ' \u00B7 $assignee' : (admin ? ' \u00B7 Unassigned' : '')}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (phone != null && phone.isNotEmpty) ...[
                                        InkWell(
                                          onTap: () => callNumber(phone),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: AppColors.brandTeal.withAlpha(20),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.call, size: 16, color: AppColors.brandTeal),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => whatsappNumber(phone),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withAlpha(20),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.chat, size: 16, color: Colors.green),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
