
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color couponOrange = Color(0xFFFF7900);
const Color couponBackground = Color(0xFFFFFAF5);

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _search = TextEditingController();

  String _filter = 'All';
  String _query = '';

  CollectionReference<Map<String, dynamic>> get _coupons =>
      _db.collection('coupons');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _dateText(dynamic value) {
    final d = _date(value);
    if (d == null) return 'Not set';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _status(Map<String, dynamic> data) {
    if (data['isActive'] != true) return 'Inactive';

    final now = DateTime.now();
    final start = _date(data['startAt']);
    final expiry = _date(data['expiresAt']);
    final limit = data['usageLimit'];
    final used = data['redeemedCount'];

    if (start != null && now.isBefore(start)) return 'Scheduled';
    if (expiry != null && now.isAfter(expiry)) return 'Expired';

    if (limit is num && used is num && used >= limit) {
      return 'Limit reached';
    }

    return 'Active';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _editCoupon({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data = document?.data() ?? <String, dynamic>{};

    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(
      text: data['code']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: data['description']?.toString() ?? '',
    );
    final discount = TextEditingController(
      text: data['discountValue']?.toString() ?? '',
    );
    final minimum = TextEditingController(
      text: data['minBookingAmount']?.toString() ?? '0',
    );
    final usage = TextEditingController(
      text: data['usageLimit']?.toString() ?? '100',
    );
    final perCustomer = TextEditingController(
      text: data['perCustomerLimit']?.toString() ?? '1',
    );

    String type = data['discountType']?.toString() ?? 'percentage';
    bool active = data['isActive'] as bool? ?? true;
    DateTime start = _date(data['startAt']) ?? DateTime.now();
    DateTime expiry = _date(data['expiresAt']) ??
        DateTime.now().add(const Duration(days: 30));
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                document == null ? 'Create Coupon' : 'Edit Coupon',
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: code,
                          enabled: document == null,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Coupon Code *',
                            hintText: 'WELCOME50',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (!RegExp(r'^[A-Za-z0-9_-]{3,24}$')
                                .hasMatch(v)) {
                              return 'Enter 3–24 letters or numbers';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: description,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(
                            labelText: 'Discount Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'percentage',
                              child: Text('Percentage (%)'),
                            ),
                            DropdownMenuItem(
                              value: 'fixed',
                              child: Text('Fixed Amount (₹)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => type = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: discount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: type == 'percentage'
                                ? 'Discount Percentage *'
                                : 'Discount Amount (₹) *',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final v = double.tryParse(value ?? '');
                            if (v == null || v <= 0) {
                              return 'Enter a value greater than zero';
                            }
                            if (type == 'percentage' && v > 100) {
                              return 'Maximum percentage is 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _numberField(
                          minimum,
                          'Minimum Booking Amount (₹)',
                          allowZero: true,
                        ),
                        const SizedBox(height: 12),
                        _numberField(usage, 'Total Usage Limit'),
                        const SizedBox(height: 12),
                        _numberField(
                          perCustomer,
                          'Per Customer Usage Limit',
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start Date'),
                          subtitle: Text(_dateText(start)),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () async {
                            final picked = await _pickDate(start);
                            if (picked != null) {
                              setDialogState(() {
                                start = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                );
                                if (expiry.isBefore(start)) {
                                  expiry = start.add(
                                    const Duration(days: 1),
                                  );
                                }
                              });
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Expiry Date'),
                          subtitle: Text(_dateText(expiry)),
                          trailing: const Icon(Icons.event),
                          onTap: () async {
                            final picked = await _pickDate(expiry);
                            if (picked != null) {
                              setDialogState(() {
                                expiry = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  23,
                                  59,
                                  59,
                                );
                              });
                            }
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Coupon Active'),
                          value: active,
                          activeThumbColor: couponOrange,
                          onChanged: (value) {
                            setDialogState(() => active = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: couponOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          if (expiry.isBefore(start)) {
                            _message('Expiry must be after start date.');
                            return;
                          }

                          setDialogState(() => saving = true);

                          try {
                            final normalized =
                                code.text.trim().toUpperCase();

                            final duplicates = await _coupons
                                .where('code', isEqualTo: normalized)
                                .limit(2)
                                .get();

                            if (duplicates.docs.any(
                              (d) => d.id != document?.id,
                            )) {
                              _message('Coupon code already exists.');
                              setDialogState(() => saving = false);
                              return;
                            }

                            final userId =
                                FirebaseAuth.instance.currentUser?.uid;

                            final payload = <String, dynamic>{
                              'code': normalized,
                              'description': description.text.trim(),
                              'discountType': type,
                              'discountValue':
                                  double.parse(discount.text.trim()),
                              'minBookingAmount':
                                  double.parse(minimum.text.trim()),
                              'usageLimit': int.parse(usage.text.trim()),
                              'perCustomerLimit':
                                  int.parse(perCustomer.text.trim()),
                              'startAt': Timestamp.fromDate(start),
                              'expiresAt': Timestamp.fromDate(expiry),
                              'isActive': active,
                              'updatedAt': FieldValue.serverTimestamp(),
                              'updatedBy': userId,
                            };

                            if (document == null) {
                              payload['createdAt'] =
                                  FieldValue.serverTimestamp();
                              payload['createdBy'] = userId;
                              payload['redeemedCount'] = 0;

                              await _coupons.doc(normalized).set(payload);
                            } else {
                              await document.reference.update(payload);
                            }

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            _message(
                              document == null
                                  ? 'Coupon created successfully.'
                                  : 'Coupon updated successfully.',
                            );
                          } on FirebaseException catch (e) {
                            setDialogState(() => saving = false);
                            _message(
                              'Firebase error: ${e.code}. Check Firestore rules.',
                            );
                          } catch (e) {
                            setDialogState(() => saving = false);
                            _message('Could not save coupon: $e');
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Coupon'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      code.dispose();
      description.dispose();
      discount.dispose();
      minimum.dispose();
      usage.dispose();
      perCustomer.dispose();
    }
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool allowZero = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final n = double.tryParse(value ?? '');
        if (n == null || n < 0 || (!allowZero && n < 1)) {
          return allowZero ? 'Enter zero or more' : 'Enter at least 1';
        }
        if (!allowZero && n != n.roundToDouble()) {
          return 'Enter a whole number';
        }
        return null;
      },
    );
  }

  Future<void> _toggle(
    DocumentSnapshot<Map<String, dynamic>> document,
    bool active,
  ) async {
    try {
      await document.reference.update({
        'isActive': !active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } on FirebaseException catch (e) {
      _message('Could not update coupon: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: couponBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coupons & Offers',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Manage customer promotions',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _editCoupon(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Coupon'),
                    style: FilledButton.styleFrom(
                      backgroundColor: couponOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search coupon code...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  'All',
                  'Active',
                  'Inactive',
                  'Scheduled',
                  'Expired',
                  'Limit reached',
                ].map((item) {
                  return ChoiceChip(
                    label: Text(item),
                    selected: _filter == item,
                    selectedColor: const Color(0xFFFFE0C7),
                    onSelected: (_) => setState(() => _filter = item),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _coupons
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 42),
                              const SizedBox(height: 12),
                              const Text(
                                'Coupons could not be loaded. Check Firestore rules.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => setState(() {}),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final filtered = docs.where((doc) {
                      final data = doc.data();
                      final code = data['code']?.toString() ?? doc.id;
                      return code.toLowerCase().contains(
                            _query.toLowerCase(),
                          ) &&
                          (_filter == 'All' || _status(data) == _filter);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_offer_outlined,
                              size: 52,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No coupons found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Create a coupon to get started.'),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();
                        final active = data['isActive'] == true;
                        final type = data['discountType'];
                        final value = data['discountValue'] ?? 0;
                        final discount = type == 'percentage'
                            ? '$value% OFF'
                            : '₹$value OFF';
                        final status = _status(data);

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: Color(0xFFEAEAEA),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0E3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.local_offer_outlined,
                                        color: couponOrange,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['code']?.toString() ?? doc.id,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            data['description']?.toString() ??
                                                'No description',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            discount,
                                            style: const TextStyle(
                                              color: couponOrange,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _editCoupon(document: doc);
                                        } else {
                                          _toggle(doc, active);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit Coupon'),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(
                                            active ? 'Deactivate' : 'Activate',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      'Minimum: ₹${data['minBookingAmount'] ?? 0}',
                                    ),
                                    Text(
                                      'Start: ${_dateText(data['startAt'])}',
                                    ),
                                    Text(
                                      'Expiry: ${_dateText(data['expiresAt'])}',
                                    ),
                                    Text(
                                      'Uses: ${data['redeemedCount'] ?? 0}/'
                                      '${data['usageLimit'] ?? '∞'}',
                                    ),
                                    Text(
                                      'Per customer: '
                                      '${data['perCustomerLimit'] ?? 1}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status == 'Active'
                                        ? const Color(0xFFE5F5E9)
                                        : const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: status == 'Active'
                                          ? const Color(0xFF26743A)
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
