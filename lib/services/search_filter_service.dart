import 'package:flutter/material.dart';

class SearchFilterService {
  SearchFilterService._();
  static final SearchFilterService _instance = SearchFilterService._();
  factory SearchFilterService() => _instance;

  String selectedCommune = '';
  String selectedTypeBien = '';
  int? selectedCommuneId;
  int? selectedTypeBienId;
  int? nbCouchages;
  String animaux = 'Tous';
  RangeValues tarifRange = const RangeValues(0, 2000);
  DateTime? dateDebut;
  DateTime? dateFin;
  bool useDistanceFilter = false;
  double distanceMaxKm = 35;

  void reset() {
    selectedCommune = '';
    selectedTypeBien = '';
    selectedCommuneId = null;
    selectedTypeBienId = null;
    nbCouchages = null;
    animaux = 'Tous';
    tarifRange = const RangeValues(0, 2000);
    dateDebut = null;
    dateFin = null;
    useDistanceFilter = false;
    distanceMaxKm = 35;
  }
}
