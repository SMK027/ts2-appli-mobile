// Issue #15 - [CF-RESA] Étape 1 : Sélection voyageurs et dates
// Issue #16 - [CF-RESA] Étape 2 : Récapitulatif et calcul du montant
// Issue #17 - [CF-RESA] Étape 3 : Formulaire de paiement et création réservation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/property.dart';
import '../config/api_config.dart';
import '../services/reservation_service.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';
import 'booking_success_screen.dart';

class BookingScreen extends StatefulWidget {
  final Property property;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final int? nbPersonnes;

  const BookingScreen({super.key, required this.property, this.dateDebut, this.dateFin, this.nbPersonnes});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _currentStep = 0;
  int _travelers = 1;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loadingData = true;
  bool _submitting = false;
  bool _checkingAvailability = false;
  String? _error;

  List<Map<String, dynamic>> _tarifs = [];
  int? _selectedTarifId;
  double _tarifParSemaine = 0;
  double _fraisService = 0;
  double _montantTotal = 0;
  String? _photoUrl;

  // Champs paiement (Issue #17)
  final _cardHolderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _paymentFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _startDate = widget.dateDebut;
    _endDate = widget.dateFin;
    if (widget.nbPersonnes != null && widget.nbPersonnes! > 0) {
      _travelers = widget.nbPersonnes!;
    }
    _loadBookingData();
  }

  @override
  void dispose() {
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    final service = ReservationService();
    final results = await Future.wait([
      service.getPropertyTarifs(widget.property.id),
      service.getPropertyPhotos(widget.property.id),
    ]);

    if (!mounted) return;
    final photos = results[1] as List<String>;
    setState(() {
      _photoUrl = photos.isNotEmpty ? photos.first : widget.property.photoUrl;
      _tarifs = results[0] as List<Map<String, dynamic>>;
      if (_tarifs.isNotEmpty) {
        _selectedTarifId = _tarifs.first['id_tarif'] is int
            ? _tarifs.first['id_tarif'] as int
            : int.tryParse(_tarifs.first['id_tarif'].toString());
        _tarifParSemaine =
            double.tryParse(_tarifs.first['tarif']?.toString() ?? '0') ?? 0;
      }
      _loadingData = false;
      if (_startDate != null && _endDate != null) {
        _calculateTotal();
      }
    });
  }

  int get _nbNuits {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays;
  }

  int get _nbSemaines {
    final days = _nbNuits;
    if (days <= 0) return 0;
    return (days / 7).ceil();
  }

  void _calculateTotal() {
    // Chercher le tarif correspondant à la période
    if (_tarifs.isNotEmpty && _startDate != null) {
      // Trouver le meilleur tarif pour la période
      for (final tarif in _tarifs) {
        final annee = int.tryParse(tarif['annee_tarif']?.toString() ?? '');
        if (annee == _startDate!.year) {
          _selectedTarifId = tarif['id_tarif'] is int
              ? tarif['id_tarif'] as int
              : int.tryParse(tarif['id_tarif'].toString());
          _tarifParSemaine =
              double.tryParse(tarif['tarif']?.toString() ?? '0') ?? 0;
          break;
        }
      }
    }

    final logement = _nbSemaines * _tarifParSemaine;
    _fraisService = logement * 0.05; // 5% frais de service
    _montantTotal = logement + _fraisService;
  }

  Future<void> _selectDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: 'Sélectionnez la période',
      saveText: 'Valider',
      locale: const Locale('fr', 'FR'),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
      _calculateTotal();
    });
  }

  Future<bool> _checkAvailability() async {
    if (_startDate == null || _endDate == null) return false;
    setState(() {
      _checkingAvailability = true;
      _error = null;
    });
    try {
      final response = await ApiService().client.get(
        '${ApiConfig.biensEndpoint}/${widget.property.id}/disponibilite',
        queryParameters: {
          'date_debut': DateFormat('yyyy-MM-dd').format(_startDate!),
          'date_fin': DateFormat('yyyy-MM-dd').format(_endDate!),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return false;
      setState(() => _checkingAvailability = false);
      if (data['disponible'] == true) return true;
      setState(() => _error =
          'Ce bien n\'est pas disponible sur la période sélectionnée. '
          'Veuillez choisir d\'autres dates.');
      return false;
    } on DioException catch (e) {
      if (!mounted) return false;
      setState(() {
        _checkingAvailability = false;
        _error = ApiService.handleError(e);
      });
      return false;
    }
  }

  void _nextStep() async {
    if (_currentStep == 0) {
      if (_startDate == null || _endDate == null) {
        setState(() => _error = 'Veuillez sélectionner les dates du séjour.');
        return;
      }
      final available = await _checkAvailability();
      if (!available) return;
      setState(() {
        _error = null;
        _calculateTotal();
        _currentStep = 1;
      });
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _error = null;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_paymentFormKey.currentState!.validate()) return;
    if (_selectedTarifId == null) {
      setState(() => _error = 'Aucun tarif disponible pour ce bien.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ReservationService().createReservation(
        dateDebut: DateFormat('yyyy-MM-dd').format(_startDate!),
        dateFin: DateFormat('yyyy-MM-dd').format(_endDate!),
        idBien: widget.property.id,
        idTarif: _selectedTarifId!,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            reservationId: result?['id_reservations']?.toString() ?? '',
            propertyName: widget.property.name,
            montantTotal: _montantTotal,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ApiService.handleError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Erreur lors du paiement. Veuillez réessayer.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
        ),
        title: Text(
          'Réservation – Étape ${_currentStep + 1}/3',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Indicateur de progression
                  _buildProgressIndicator(),
                  const SizedBox(height: 20),

                  // Résumé du bien (toujours visible)
                  _buildPropertySummary(p),
                  const SizedBox(height: 24),

                  // Contenu de l'étape
                  if (_currentStep == 0) _buildStep1(dateFormat),
                  if (_currentStep == 1) _buildStep2(dateFormat),
                  if (_currentStep == 2) _buildStep3(),

                  // Erreur
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!,
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Bouton principal
                  if (_currentStep < 2)
                    ElevatedButton(
                      onPressed: _checkingAvailability ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _checkingAvailability
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStep == 0 ? 'Continuer' : 'Confirmer',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPropertySummary(Property p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (_photoUrl ?? p.photoUrl) != null
                ? CachedNetworkImage(
                    imageUrl: (_photoUrl ?? p.photoUrl)!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.home, color: Colors.grey),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.home, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.home, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(p.commune,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13)),
                if (p.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Colors.amber, size: 14),
                      Text(' ${p.rating!.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ÉTAPE 1 : Voyageurs + Dates (Issue #15) ──
  Widget _buildStep1(DateFormat dateFormat) {
    final maxCouchage = widget.property.nbCouchage ?? 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nombre de voyageurs',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _travelers > 1
                  ? () => setState(() => _travelers--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: Theme.of(context).colorScheme.primary,
              iconSize: 32,
            ),
            const SizedBox(width: 16),
            Text('$_travelers',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            IconButton(
              onPressed: _travelers < maxCouchage
                  ? () => setState(() => _travelers++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              color: Theme.of(context).colorScheme.primary,
              iconSize: 32,
            ),
          ],
        ),
        Text('Maximum : $maxCouchage couchages',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 32),

        // Dates du séjour
        Text('Dates du séjour',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Arrivée',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        _startDate != null
                            ? dateFormat.format(_startDate!)
                            : 'Sélectionner',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Départ',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        _endDate != null
                            ? dateFormat.format(_endDate!)
                            : 'Sélectionner',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_nbNuits > 0)
                Text('$_nbNuits nuits',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _selectDates,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Modifier les dates'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 2 : Récapitulatif (Issue #16) ──
  Widget _buildStep2(DateFormat dateFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Récapitulatif',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 16),

        _buildRecapRow(
          'Logement',
          '$_nbSemaines sem. × ${_tarifParSemaine.toStringAsFixed(0)} €',
          (_nbSemaines * _tarifParSemaine),
        ),
        _buildRecapRow(
          'Frais de service',
          '5%',
          _fraisService,
        ),
        const Divider(height: 24),
        _buildRecapRow(
          'Total',
          '',
          _montantTotal,
          isBold: true,
        ),
        const SizedBox(height: 8),
        Text(
          'Du ${dateFormat.format(_startDate!)} au ${dateFormat.format(_endDate!)} · $_nbNuits nuits · $_travelers voyageur${_travelers > 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Badge paiement sécurisé
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.lock, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text('Paiement sécurisé',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecapRow(String label, String detail, double amount,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontSize: isBold ? 16 : 14,
                  )),
              if (detail.isNotEmpty)
                Text(detail,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Text(
            '${amount.toStringAsFixed(2)} €',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── ÉTAPE 3 : Paiement (Issue #17) ──
  Widget _buildStep3() {
    return Form(
      key: _paymentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations de paiement',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 16),

          // Titulaire
          TextFormField(
            controller: _cardHolderController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'TITULAIRE DE LA CARTE',
              prefixIcon: const Icon(Icons.person_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 16),

          // Numéro de carte
          TextFormField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              _CardNumberFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'NUMÉRO DE CARTE',
              hintText: '1234 5678 9012 3456',
              prefixIcon: const Icon(Icons.credit_card),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) {
              final digits = v?.replaceAll(' ', '') ?? '';
              if (digits.length < 16) return 'Numéro de carte invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Expiration + CVV
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'EXPIRATION',
                    hintText: 'MM/YY',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 5) return 'Invalide';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 3) return 'Invalide';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bouton Payer
          ElevatedButton(
            onPressed: _submitting ? null : _submitPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Payer ${_montantTotal.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Formateur pour le numéro de carte (groupes de 4)
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Formateur pour l'expiration (MM/YY)
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
