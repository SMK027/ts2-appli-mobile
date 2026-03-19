import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/profile_service.dart';

class _CommuneOption {
  final int id;
  final String name;

  const _CommuneOption({required this.id, required this.name});
}

class PersonalInfoScreen extends StatefulWidget {
  final String initialLastName;
  final String initialFirstName;
  final String initialStreet;
  final String initialAddressComplement;
  final String initialCommuneName;
  final int? initialCommuneId;

  const PersonalInfoScreen({
    super.key,
    required this.initialLastName,
    required this.initialFirstName,
    required this.initialStreet,
    required this.initialAddressComplement,
    required this.initialCommuneName,
    required this.initialCommuneId,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lastNameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _streetController;
  late final TextEditingController _addressComplementController;
  late final TextEditingController _communeController;
  late final FocusNode _communeFocusNode;
  int? _selectedCommuneId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lastNameController = TextEditingController(text: widget.initialLastName);
    _firstNameController =
        TextEditingController(text: widget.initialFirstName);
    _streetController = TextEditingController(text: widget.initialStreet);
    _addressComplementController =
      TextEditingController(text: widget.initialAddressComplement);
    _communeController = TextEditingController(text: widget.initialCommuneName);
    _communeFocusNode = FocusNode();
    _selectedCommuneId = widget.initialCommuneId;

    if (_communeController.text.trim().isEmpty && _selectedCommuneId != null) {
      _loadInitialCommuneName();
    }
  }

  Future<void> _loadInitialCommuneName() async {
    final id = _selectedCommuneId;
    if (id == null) return;

    try {
      final response = await ApiService().client.get(
        '${ApiConfig.communesEndpoint}/$id',
      );
      final data = response.data;
      if (data is Map) {
        final name = data['nom_commune']?.toString().trim() ?? '';
        if (name.isNotEmpty && mounted) {
          _communeController.text = name;
        }
      }
    } on DioException catch (_) {
      // Fallback si l'API ne supporte pas /communes/:id.
      try {
        final response = await ApiService().client.get(
          ApiConfig.communesEndpoint,
          queryParameters: {'id_commune': id},
        );
        final data = response.data;
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) {
            final name = first['nom_commune']?.toString().trim() ?? '';
            if (name.isNotEmpty && mounted) {
              _communeController.text = name;
            }
          }
        }
      } on DioException catch (_) {
        // Le champ reste vide en cas d'echec reseau.
      }
    }
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _streetController.dispose();
    _addressComplementController.dispose();
    _communeController.dispose();
    _communeFocusNode.dispose();
    super.dispose();
  }

  Future<int?> _resolveCommuneId(String communeName) async {
    final query = communeName.trim();
    if (query.isEmpty) return null;

    try {
      final response = await ApiService().client.get(
        ApiConfig.communesEndpoint,
        queryParameters: {'search': query},
      );

      final data = response.data;
      if (data is! List) return null;

      for (final item in data) {
        if (item is! Map) continue;
        final name = item['nom_commune']?.toString() ?? '';
        final id = item['id_commune'];
        if (name.toLowerCase() == query.toLowerCase()) {
          if (id is int) return id;
          return int.tryParse(id?.toString() ?? '');
        }
      }

      final first = data.isNotEmpty ? data.first : null;
      if (first is Map) {
        final id = first['id_commune'];
        if (id is int) return id;
        return int.tryParse(id?.toString() ?? '');
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  Future<List<_CommuneOption>> _fetchCommuneSuggestions(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return [];

    try {
      final response = await ApiService().client.get(
        ApiConfig.communesEndpoint,
        queryParameters: {'search': normalizedQuery},
      );

      final data = response.data;
      if (data is! List) return [];

      final options = <_CommuneOption>[];
      for (final item in data) {
        if (item is! Map) continue;
        final name = item['nom_commune']?.toString() ?? '';
        final idValue = item['id_commune'];
        final id = idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '');
        if (name.isNotEmpty && id != null) {
          options.add(_CommuneOption(id: id, name: name));
        }
      }
      return options;
    } on DioException catch (_) {
      return [];
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final communeName = _communeController.text.trim();
    int? communeId = _selectedCommuneId;
    if (communeName.isNotEmpty) {
      communeId = await _resolveCommuneId(communeName);
      if (communeId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commune introuvable. Verifiez la saisie.'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ProfileService().updateProfile({
        'nom_locataire': _lastNameController.text.trim(),
        'prenom_locataire': _firstNameController.text.trim(),
        'rue_locataire': _streetController.text.trim(),
        'comp_locataire': _addressComplementController.text.trim(),
        if (communeId != null) 'id_commune': communeId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informations mises a jour.')),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de mettre a jour vos informations.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une erreur inattendue est survenue.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ce champ est obligatoire.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informations personnelles'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Mettez a jour vos informations personnelles et votre adresse postale.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Prenom',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 20),
              Text(
                'Adresse postale',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Autocomplete<_CommuneOption>(
                textEditingController: _communeController,
                focusNode: _communeFocusNode,
                displayStringForOption: (option) => option.name,
                optionsBuilder: (textEditingValue) async {
                  if (_saving) return const <_CommuneOption>[];
                  return _fetchCommuneSuggestions(textEditingValue.text);
                },
                onSelected: (option) {
                  _selectedCommuneId = option.id;
                },
                fieldViewBuilder:
                    (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Commune',
                      hintText: 'Ex: Bordeaux',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _selectedCommuneId = null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(option.name),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _streetController,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Rue',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressComplementController,
                textInputAction: TextInputAction.done,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Complement d\'adresse',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
