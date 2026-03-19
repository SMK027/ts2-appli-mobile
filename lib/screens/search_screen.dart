// Recherche avancée avec filtres : commune, type de bien, nb couchages,
// animaux acceptés, tarif min/max, dates de séjour. Redirige vers MapScreen avec résultats.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/property_service.dart';
import '../services/search_filter_service.dart';
import 'map_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  RangeValues _tarifRange = const RangeValues(0, 2000);
  static const double _tarifMin = 0;
  static const double _tarifMaxLimit = 2000;

  String _selectedCommune = '';
  String _selectedTypeBien = '';
  int? _selectedCommuneId;
  int? _selectedTypeBienId;
  int? _nbCouchages;
  String _animaux = 'Tous';
  bool _searching = false;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _useDistanceFilter = false;
  double _distanceMaxKm = 35;

  // Mappings nom → id pour l'API
  Map<String, int> _communeNameToId = {};
  Map<String, int> _typeBienNameToId = {};

  static const _couchagesOptions = <int?>[null, 1, 2, 3, 4, 5, 6, 8, 10];
  static const _animauxOptions = ['Tous', 'Oui', 'Non'];

  final _filters = SearchFilterService();

  @override
  void initState() {
    super.initState();
    _selectedCommune = _filters.selectedCommune;
    _selectedTypeBien = _filters.selectedTypeBien;
    _selectedCommuneId = _filters.selectedCommuneId;
    _selectedTypeBienId = _filters.selectedTypeBienId;
    _nbCouchages = _filters.nbCouchages;
    _animaux = _filters.animaux;
    _tarifRange = _filters.tarifRange;
    _dateDebut = _filters.dateDebut;
    _dateFin = _filters.dateFin;
    _useDistanceFilter = _filters.useDistanceFilter;
    _distanceMaxKm = _filters.distanceMaxKm;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _saveFilters() {
    _filters.selectedCommune = _selectedCommune;
    _filters.selectedTypeBien = _selectedTypeBien;
    _filters.selectedCommuneId = _selectedCommuneId;
    _filters.selectedTypeBienId = _selectedTypeBienId;
    _filters.nbCouchages = _nbCouchages;
    _filters.animaux = _animaux;
    _filters.tarifRange = _tarifRange;
    _filters.dateDebut = _dateDebut;
    _filters.dateFin = _dateFin;
    _filters.useDistanceFilter = _useDistanceFilter;
    _filters.distanceMaxKm = _distanceMaxKm;
  }

  void _resetFilters() {
    setState(() {
      _selectedCommune = '';
      _selectedTypeBien = '';
      _selectedCommuneId = null;
      _selectedTypeBienId = null;
      _tarifRange = const RangeValues(0, 2000);
      _nbCouchages = null;
      _animaux = 'Tous';
      _dateDebut = null;
      _dateFin = null;
      _useDistanceFilter = false;
      _distanceMaxKm = 35;
    });
    _filters.reset();
  }

  Future<List<String>> _fetchCommunes(String query) async {
    if (query.length < 2) return [];
    try {
      final response = await ApiService().client.get(
        ApiConfig.communesEndpoint,
        queryParameters: {'search': query},
      );
      final List data = response.data as List;
      _communeNameToId = {};
      final names = <String>[];
      for (final e in data) {
        if (e is Map) {
          final name = e['nom_commune']?.toString() ?? '';
          final id = e['id_commune'];
          if (name.isNotEmpty && id != null) {
            final idInt = id is int ? id : int.tryParse(id.toString());
            if (idInt != null) {
              _communeNameToId[name] = idInt;
              names.add(name);
            }
          }
        }
      }
      return names;
    } on DioException catch (_) {
      return [];
    }
  }

  Future<List<String>> _fetchTypesBien(String query) async {
    try {
      final response = await ApiService().client.get(
        ApiConfig.typesBienEndpoint,
      );
      final List data = response.data as List;
      _typeBienNameToId = {};
      final names = <String>[];
      for (final e in data) {
        if (e is Map) {
          final name = e['des_typebien']?.toString() ?? '';
          final id = e['id_typebien'];
          if (name.isNotEmpty && id != null) {
            final idInt = id is int ? id : int.tryParse(id.toString());
            if (idInt != null) {
              _typeBienNameToId[name] = idInt;
              names.add(name);
            }
          }
        }
      }
      if (query.isEmpty) return names;
      final lower = query.toLowerCase();
      return names.where((s) => s.toLowerCase().contains(lower)).toList();
    } on DioException catch (_) {
      return [];
    }
  }

  Future<void> _selectDateDebut() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDebut ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Date d\'arrivée',
    );
    if (picked == null) return;
    setState(() {
      _dateDebut = picked;
      if (_dateFin != null && _dateFin!.isBefore(picked.add(const Duration(days: 1)))) {
        _dateFin = null;
      }
    });
    _saveFilters();
  }

  Future<void> _selectDateFin() async {
    final minDate = _dateDebut?.add(const Duration(days: 1)) ??
        DateTime.now().add(const Duration(days: 2));
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFin ?? minDate.add(const Duration(days: 6)),
      firstDate: minDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Date de départ',
    );
    if (picked == null) return;
    setState(() => _dateFin = picked);
    _saveFilters();
  }

  Future<void> _submitSearch() async {
    setState(() => _searching = true);

    final tarifMin = _tarifRange.start > _tarifMin ? _tarifRange.start : null;
    final tarifMax = _tarifRange.end < _tarifMaxLimit ? _tarifRange.end : null;

    var results = await PropertyService().searchProperties(
      commune: _selectedCommuneId?.toString(),
      typeBien: _selectedTypeBienId?.toString(),
      nbPersonnes: _nbCouchages,
      animaux: _animaux == 'Tous' ? null : (_animaux == 'Oui' ? 'oui' : 'non'),
      tarifMin: tarifMin,
      tarifMax: tarifMax,
    );

    // Filtrer par disponibilité si dates renseignées
    if (_dateDebut != null && _dateFin != null && results.isNotEmpty) {
      results = await PropertyService().filterAvailable(
        properties: results,
        dateDebut: _dateDebut!,
        dateFin: _dateFin!,
      );
    }

    if (_useDistanceFilter && results.isNotEmpty) {
      final position = await LocationService().getCurrentPosition();
      if (position != null) {
        results = results.where((p) {
          if (p.distanceKm != null) {
            return p.distanceKm! <= _distanceMaxKm;
          }
          if (p.latitude == null || p.longitude == null) {
            return false;
          }
          final meters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            p.latitude!,
            p.longitude!,
          );
          return (meters / 1000.0) <= _distanceMaxKm;
        }).toList();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localisation indisponible : filtre de distance ignoré.'),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _searching = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialProperties: results,
          dateDebut: _dateDebut,
          dateFin: _dateFin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche avancée'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Row(
              children: [
                Icon(Icons.search, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Filtrer les biens',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ligne 1 : Commune + Type de bien (autocomplete)
            Row(
              children: [
                Expanded(child: _buildFilterField(
                  label: 'Commune',
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  child: _AutocompleteField(
                    hint: 'Rechercher une commune...',
                    initialValue: _selectedCommune,
                    optionsBuilder: _fetchCommunes,
                    onSelected: (v) {
                      _selectedCommune = v;
                      _selectedCommuneId = _communeNameToId[v];
                      _saveFilters();
                    },
                    onChanged: (v) {
                      _selectedCommune = v;
                      _selectedCommuneId = null;
                      _saveFilters();
                    },
                  ),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildFilterField(
                  label: 'Type de bien',
                  icon: Icons.home,
                  iconColor: Colors.orange,
                  child: _AutocompleteField(
                    hint: 'Rechercher un type de bien...',
                    initialValue: _selectedTypeBien,
                    optionsBuilder: _fetchTypesBien,
                    onSelected: (v) {
                      _selectedTypeBien = v;
                      _selectedTypeBienId = _typeBienNameToId[v];
                      _saveFilters();
                    },
                    onChanged: (v) {
                      _selectedTypeBien = v;
                      _selectedTypeBienId = null;
                      _saveFilters();
                    },
                  ),
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Ligne 2 : Nb couchages + Animaux
            Row(
              children: [
                Expanded(child: _buildFilterField(
                  label: 'Nb couchages min',
                  icon: Icons.bed,
                  iconColor: Colors.indigo,
                  child: _buildDropdown<int?>(
                    value: _nbCouchages,
                    items: _couchagesOptions
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v == null ? 'Tous' : '$v'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _nbCouchages = v);
                      _saveFilters();
                    },
                  ),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildFilterField(
                  label: 'Animaux acceptés',
                  icon: Icons.pets,
                  iconColor: Colors.brown,
                  child: _buildDropdown<String>(
                    value: _animaux,
                    items: _animauxOptions
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _animaux = v ?? 'Tous');
                      _saveFilters();
                    },
                  ),
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Ligne 3 : Fourchette de prix (RangeSlider)
            _buildFilterField(
              label: 'Fourchette de prix (€/semaine)',
              icon: Icons.euro,
              iconColor: Colors.green,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_tarifRange.start.round()} €',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        _tarifRange.end >= _tarifMaxLimit
                            ? '${_tarifRange.end.round()} € +'
                            : '${_tarifRange.end.round()} €',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: const Color(0xFF10B981),
                      overlayColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                    ),
                    child: RangeSlider(
                      values: _tarifRange,
                      min: _tarifMin,
                      max: _tarifMaxLimit,
                      divisions: 40,
                      labels: RangeLabels(
                        '${_tarifRange.start.round()} €',
                        '${_tarifRange.end.round()} €',
                      ),
                      onChanged: (values) {
                        setState(() => _tarifRange = values);
                        _saveFilters();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ligne 4 : Dates de séjour
            Row(
              children: [
                Expanded(child: _buildFilterField(
                  label: 'Date d\'arrivée',
                  icon: Icons.calendar_today,
                  iconColor: const Color(0xFF1A3C5E),
                  child: _buildDateButton(
                    date: _dateDebut,
                    hint: 'Sélectionner',
                    onTap: _selectDateDebut,
                  ),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildFilterField(
                  label: 'Date de départ',
                  icon: Icons.calendar_today,
                  iconColor: const Color(0xFF1A3C5E),
                  child: _buildDateButton(
                    date: _dateFin,
                    hint: 'Sélectionner',
                    onTap: _selectDateFin,
                  ),
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Ligne 5 : Distance (facultative)
            _buildFilterField(
              label: 'Distance maximale (facultatif)',
              icon: Icons.social_distance,
              iconColor: const Color(0xFF10B981),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _useDistanceFilter,
                    title: const Text(
                      'Activer le filtre de distance',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    activeColor: const Color(0xFF10B981),
                    onChanged: (value) {
                      setState(() => _useDistanceFilter = value);
                      _saveFilters();
                    },
                  ),
                  if (_useDistanceFilter)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Rayon',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            Text(
                              '${_distanceMaxKm.round()} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF10B981),
                            inactiveTrackColor: Colors.grey.shade200,
                            thumbColor: const Color(0xFF10B981),
                            overlayColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _distanceMaxKm,
                            min: 1,
                            max: 100,
                            divisions: 99,
                            label: '${_distanceMaxKm.round()} km',
                            onChanged: (value) {
                              setState(() => _distanceMaxKm = value);
                              _saveFilters();
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _searching ? null : _submitSearch,
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_searching
                        ? 'Recherche...'
                        : 'Appliquer les filtres'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3366CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    _resetFilters();
                    // Force rebuild des Autocomplete en changeant la key
                    setState(() {});
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Réinitialiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers de construction ──

  Widget _buildFilterField({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDateButton({
    required DateTime? date,
    required String hint,
    required VoidCallback onTap,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? dateFormat.format(date) : hint,
                style: TextStyle(
                  fontSize: 14,
                  color: date != null ? Theme.of(context).colorScheme.onSurface : Colors.grey.shade400,
                ),
              ),
            ),
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
          dropdownColor: Theme.of(context).cardColor,
        ),
      ),
    );
  }
}

/// Widget d'auto-complétion réutilisable avec debounce
class _AutocompleteField extends StatefulWidget {
  final String hint;
  final String initialValue;
  final Future<List<String>> Function(String query) optionsBuilder;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onChanged;

  const _AutocompleteField({
    required this.hint,
    required this.initialValue,
    required this.optionsBuilder,
    required this.onSelected,
    required this.onChanged,
  });

  @override
  State<_AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<_AutocompleteField> {
  late TextEditingController _controller;
  List<String> _options = [];
  bool _showOptions = false;
  Timer? _debounce;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _AutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Délai pour laisser le onTap de l'overlay s'exécuter avant de le fermer
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hideOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    widget.onChanged(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await widget.optionsBuilder(value);
      if (!mounted) return;
      setState(() {
        _options = results;
        _showOptions = results.isNotEmpty;
      });
      if (_showOptions) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
  }

  void _selectOption(String value) {
    _debounce?.cancel();
    _controller.text = value;
    widget.onSelected(value);
    _hideOverlay();
    _focusNode.unfocus();
  }

  void _showOverlay() {
    _hideOverlay();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _options.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () => _selectOption(_options[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Text(
                      _options[i],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onTextChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            suffixIcon: Icon(Icons.arrow_drop_down,
                color: Colors.grey.shade400, size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
  }
}
