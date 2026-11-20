import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../categories/domain/entities/category.dart';
import '../../domain/entities/transaction.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final TransactionType initialType;
  final String? initialWalletId;

  const AddTransactionSheet({
    super.key,
    this.initialType = TransactionType.expense,
    this.initialWalletId,
  });

  static Future<bool?> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.expense,
    String? initialWalletId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        initialType: initialType,
        initialWalletId: initialWalletId,
      ),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late TransactionType _type;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Transfer eksternal (ke bank / e-wallet / orang lain)
  bool _isExternalTransfer = false;
  String _selectedInstitution = 'Bank BCA';
  final TextEditingController _customInstitutionController = TextEditingController();
  final TextEditingController _recipientNameController = TextEditingController();
  final TextEditingController _recipientAccountController = TextEditingController();

  static const List<String> transferInstitutions = [
    'Bank BCA',
    'Bank Mandiri',
    'Bank BRI',
    'Bank BNI',
    'Bank Syariah Indonesia (BSI)',
    'Bank CIMB Niaga',
    'Bank Permata',
    'Bank Danamon',
    'Bank Jago',
    'SeaBank',
    'Jenius / BTPN',
    'Blu by BCA',
    'GoPay',
    'OVO',
    'DANA',
    'ShopeePay',
    'LinkAja',
    'AstraPay',
    'Bank / E-Wallet Lainnya',
  ];

  int _amount = 0;
  String? _selectedWalletId;
  String? _selectedDestWalletId;
  String? _selectedCategoryId;
  DateTime _occurredAt = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedWalletId = widget.initialWalletId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    _customInstitutionController.dispose();
    _recipientNameController.dispose();
    _recipientAccountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    final num = int.tryParse(clean) ?? 0;
    _amount = num;
    final formatted = num > 0 ? CurrencyFormatter.formatRupiah(num) : '';
    if (_amountController.text != formatted) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_occurredAt),
      );
      setState(() {
        _occurredAt = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? _occurredAt.hour,
          pickedTime?.minute ?? _occurredAt.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transaksi harus lebih dari 0.')),
      );
      return;
    }

    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet sumber terlebih dahulu.')),
      );
      return;
    }

    if (_type == TransactionType.transfer) {
      if (_isExternalTransfer) {
        final recipient = _recipientNameController.text.trim();
        if (recipient.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Masukkan nama orang atau penerima transfer.')),
          );
          return;
        }
      } else {
        if (_selectedDestWalletId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pilih dompet tujuan transfer.')),
          );
          return;
        }
        if (_selectedDestWalletId == _selectedWalletId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dompet tujuan tidak boleh sama dengan dompet asal.')),
          );
          return;
        }
      }
    } else {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih kategori transaksi.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    String? destWalletId;
    String? merchant;
    String? description;
    String? notes;

    if (_type == TransactionType.transfer) {
      if (_isExternalTransfer) {
        final recipient = _recipientNameController.text.trim();
        final institution = _selectedInstitution == 'Bank / E-Wallet Lainnya' &&
                _customInstitutionController.text.trim().isNotEmpty
            ? _customInstitutionController.text.trim()
            : _selectedInstitution;
        destWalletId = null;
        merchant = '$institution - $recipient';
        description = 'Transfer ke $institution ($recipient)';
        final accNo = _recipientAccountController.text.trim();
        final userNotes = _notesController.text.trim();
        if (accNo.isNotEmpty && userNotes.isNotEmpty) {
          notes = 'No. Rek: $accNo • $userNotes';
        } else if (accNo.isNotEmpty) {
          notes = 'No. Rek: $accNo';
        } else {
          notes = userNotes.isNotEmpty ? userNotes : null;
        }
      } else {
        destWalletId = _selectedDestWalletId;
        merchant = null;
        description = _merchantController.text.trim().isNotEmpty ? _merchantController.text.trim() : null;
        notes = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;
      }
    } else {
      destWalletId = null;
      merchant = _merchantController.text.trim().isNotEmpty ? _merchantController.text.trim() : null;
      description = _merchantController.text.trim().isNotEmpty ? _merchantController.text.trim() : null;
      notes = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;
    }

    final success = await ref.read(transactionsControllerProvider.notifier).createTransaction(
          type: _type,
          amount: _amount,
          occurredAt: _occurredAt,
          walletId: _selectedWalletId!,
          destinationWalletId: destWalletId,
          categoryId: _type != TransactionType.transfer ? _selectedCategoryId : null,
          merchant: merchant,
          description: description,
          notes: notes,
        );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        await HapticFeedback.lightImpact();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan transaksi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletsAsync = ref.watch(walletsWithBalanceStreamProvider);
    final categoryType = _type == TransactionType.income ? CategoryType.income : CategoryType.expense;
    final categoriesAsync = ref.watch(activeCategoriesStreamProvider(categoryType));

    // Default select first wallet if not yet selected
    walletsAsync.whenData((wallets) {
      if (_selectedWalletId == null && wallets.isNotEmpty) {
        _selectedWalletId = wallets.first.wallet.id;
      }
      if (_type == TransactionType.transfer && _selectedDestWalletId == null && wallets.length > 1) {
        _selectedDestWalletId = wallets.firstWhere((w) => w.wallet.id != _selectedWalletId).wallet.id;
      }
    });

    // Default select first category if not yet selected
    categoriesAsync.whenData((cats) {
      if (_selectedCategoryId == null && cats.isNotEmpty) {
        _selectedCategoryId = cats.first.id;
      }
    });

    final typeColor = _type == TransactionType.expense
        ? (isDark ? AppColors.expenseDark : AppColors.expenseLight)
        : _type == TransactionType.income
            ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
            : (isDark ? AppColors.transferDark : AppColors.transferLight);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // iOS Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 10),

          // Modal Navigation Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Text(
                  'Catat Transaksi',
                  style: AppTypography.headline.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Transaction Type Segmented Control
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildTypeSegment(TransactionType.expense, 'Pengeluaran', isDark),
                      _buildTypeSegment(TransactionType.income, 'Pemasukan', isDark),
                      _buildTypeSegment(TransactionType.transfer, 'Transfer', isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Large Amount Input Display
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Nominal',
                        style: AppTypography.caption1.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Rp 0',
                          hintStyle: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: (isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight)
                                .withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: _onAmountChanged,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Wallets Selection (Source & Destination for Transfer)
                walletsAsync.when(
                  data: (wallets) {
                    if (wallets.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Belum ada dompet. Tambahkan dompet terlebih dahulu pada menu Dompet.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (_type == TransactionType.transfer) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Dari Dompet Asal
                            Row(
                              children: [
                                const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                const Text('Dari', style: AppTypography.callout),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: DropdownButton<String>(
                                      value: _selectedWalletId,
                                      isDense: true,
                                      underline: const SizedBox(),
                                      items: wallets.map((w) {
                                        return DropdownMenuItem<String>(
                                          value: w.wallet.id,
                                          child: Text(
                                            '${w.wallet.name} (${CurrencyFormatter.formatRupiah(w.currentBalance)})',
                                            style: AppTypography.subhead,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedWalletId = val;
                                          if (_selectedDestWalletId == val) {
                                            final rem = wallets.where((w) => w.wallet.id != val);
                                            _selectedDestWalletId = rem.isNotEmpty ? rem.first.wallet.id : null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 20),

                            // 2. Tujuan Transfer: Segmented Toggle
                            Text(
                              'Tujuan Transfer (Ke)',
                              style: AppTypography.caption1.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : AppColors.surfaceCardLight,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _isExternalTransfer = false);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 7),
                                        decoration: BoxDecoration(
                                          color: !_isExternalTransfer
                                              ? (isDark ? AppColors.surfaceElevatedDark : Colors.white)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(7),
                                          boxShadow: !_isExternalTransfer
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.06),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Dompet Sendiri',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: !_isExternalTransfer ? FontWeight.w600 : FontWeight.normal,
                                            color: !_isExternalTransfer
                                                ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                                : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _isExternalTransfer = true);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 7),
                                        decoration: BoxDecoration(
                                          color: _isExternalTransfer
                                              ? (isDark ? AppColors.surfaceElevatedDark : Colors.white)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(7),
                                          boxShadow: _isExternalTransfer
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.06),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Rekening / Orang Lain',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _isExternalTransfer ? FontWeight.w600 : FontWeight.normal,
                                            color: _isExternalTransfer
                                                ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                                : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // 3. Konten Pilihan Berdasarkan Mode Tujuan
                            if (!_isExternalTransfer) ...[
                              // Pilihan Dompet Internal
                              if (wallets.length <= 1)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Hanya ada 1 dompet aktif. Pilih tab "Rekening / Orang Lain" untuk transfer ke bank/e-wallet luar.',
                                          style: AppTypography.caption2.copyWith(
                                            color: isDark ? Colors.amber[200] : Colors.amber[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    const Icon(Icons.arrow_downward_rounded, size: 20, color: Colors.green),
                                    const SizedBox(width: 8),
                                    const Text('Ke Dompet', style: AppTypography.callout),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: DropdownButton<String>(
                                          value: _selectedDestWalletId,
                                          isDense: true,
                                          underline: const SizedBox(),
                                          items: wallets
                                              .where((w) => w.wallet.id != _selectedWalletId)
                                              .map((w) {
                                            return DropdownMenuItem<String>(
                                              value: w.wallet.id,
                                              child: Text(
                                                '${w.wallet.name} (${CurrencyFormatter.formatRupiah(w.currentBalance)})',
                                                style: AppTypography.subhead,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() => _selectedDestWalletId = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ] else ...[
                              // Pilihan Bank / E-Wallet & Orang Lain (Eksternal)
                              // Dropdown Bank / E-Wallet
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedInstitution.startsWith('Bank')
                                          ? Icons.account_balance_rounded
                                          : Icons.account_balance_wallet_rounded,
                                      size: 18,
                                      color: isDark ? AppColors.transferDark : AppColors.transferLight,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedInstitution,
                                          isExpanded: true,
                                          style: AppTypography.subhead.copyWith(
                                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                          ),
                                          dropdownColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                          items: transferInstitutions.map((inst) {
                                            final isBank = inst.startsWith('Bank');
                                            final isOther = inst.contains('Lainnya');
                                            return DropdownMenuItem<String>(
                                              value: inst,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isOther
                                                        ? Icons.edit_note_rounded
                                                        : (isBank
                                                            ? Icons.account_balance_outlined
                                                            : Icons.account_balance_wallet_outlined),
                                                    size: 16,
                                                    color: isDark
                                                        ? AppColors.textTertiaryDark
                                                        : AppColors.textTertiaryLight,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      inst,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _selectedInstitution = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_selectedInstitution == 'Bank / E-Wallet Lainnya') ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _customInstitutionController,
                                  decoration: InputDecoration(
                                    hintText: 'Tulis Nama Bank atau E-Wallet...',
                                    hintStyle: AppTypography.caption1.copyWith(
                                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    filled: true,
                                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),

                              // Nama Penerima / Orang yang Ditransfer
                              TextField(
                                controller: _recipientNameController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                  hintText: 'Nama Penerima (misal: Budi, Ibu, Bayar Kos)',
                                  hintStyle: AppTypography.subhead.copyWith(
                                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Nomor Rekening / No. HP Penerima (Opsional)
                              TextField(
                                controller: _recipientAccountController,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                                  hintText: 'No. Rekening / No. HP Tujuan (opsional)',
                                  hintStyle: AppTypography.subhead.copyWith(
                                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    // Single Wallet Picker for Income/Expense
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 20),
                          const SizedBox(width: 12),
                          const Text('Dompet', style: AppTypography.callout),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: DropdownButton<String>(
                                value: _selectedWalletId,
                                isDense: true,
                                underline: const SizedBox(),
                                items: wallets.map((w) {
                                  return DropdownMenuItem<String>(
                                    value: w.wallet.id,
                                    child: Text(
                                      '${w.wallet.name} (${CurrencyFormatter.formatRupiah(w.currentBalance)})',
                                      style: AppTypography.subhead,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedWalletId = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Text('Gagal memuat dompet', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),

                const SizedBox(height: 16),

                // 4. Category Selector (Only for Income and Expense)
                if (_type != TransactionType.transfer) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kategori',
                        style: AppTypography.footnote.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) {
                      if (categories.isEmpty) {
                        return const Text('Tidak ada kategori tersedia.');
                      }
                      return SizedBox(
                        height: 85,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = _selectedCategoryId == cat.id;
                            final catColor = AppIcons.parseColor(cat.colorHex);
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategoryId = cat.id);
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? catColor
                                          : (isDark
                                              ? AppColors.surfaceElevatedDark
                                              : AppColors.backgroundLight),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? catColor : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      AppIcons.getIcon(cat.iconKey),
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 64,
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected
                                            ? catColor
                                            : (isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => const Text('Gagal memuat kategori', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Merchant / Toko / Penerima (hanya jika bukan transfer eksternal)
                if (_type != TransactionType.transfer || !_isExternalTransfer) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _merchantController,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.storefront_rounded, size: 20),
                        hintText: _type == TransactionType.transfer
                            ? 'Keterangan transfer (opsional)'
                            : 'Merchant / Toko / Sumber (opsional)',
                        border: InputBorder.none,
                        hintStyle: AppTypography.subhead.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 6. Tanggal & Waktu
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 20),
                        const SizedBox(width: 12),
                        const Text('Waktu Transaksi', style: AppTypography.callout),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormatter.formatDateAndTime(_occurredAt.toIso8601String()),
                            textAlign: TextAlign.end,
                            style: AppTypography.subhead.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 7. Catatan / Notes
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      icon: const Icon(Icons.notes_rounded, size: 20),
                      hintText: 'Catatan tambahan (opsional)',
                      border: InputBorder.none,
                      hintStyle: AppTypography.subhead.copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tombol Simpan Utama di Bawah
                AppButton(
                  label: 'Simpan Transaksi',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _save,
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSegment(TransactionType type, String title, bool isDark) {
    final isSelected = _type == type;
    Color activeColor;
    switch (type) {
      case TransactionType.expense:
        activeColor = isDark ? AppColors.expenseDark : AppColors.expenseLight;
        break;
      case TransactionType.income:
        activeColor = isDark ? AppColors.incomeDark : AppColors.incomeLight;
        break;
      case TransactionType.transfer:
        activeColor = isDark ? AppColors.transferDark : AppColors.transferLight;
        break;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = type;
            _selectedCategoryId = null; // Reset category when switching type
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceCardDark : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? activeColor
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }
}
