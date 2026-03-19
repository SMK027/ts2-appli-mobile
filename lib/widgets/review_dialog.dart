// Issue #21 - [CF-NOTIFS] : Formulaire de dépôt d'avis (étoiles + commentaire)
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';

class ReviewDialog extends StatefulWidget {
  final int idReservation;
  final VoidCallback? onReviewSubmitted;

  const ReviewDialog({
    super.key,
    required this.idReservation,
    this.onReviewSubmitted,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  // On récupère le détail de la réservation pour avoir id_bien
  int? _idBien;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _loadReservationDetail();
  }

  Future<void> _loadReservationDetail() async {
    final detail =
        await ProfileService().getReservationDetail(widget.idReservation);
    if (!mounted) return;
    setState(() {
      _idBien = detail?['id_bien'] is int
          ? detail!['id_bien'] as int
          : int.tryParse(detail?['id_bien']?.toString() ?? '');
      _loadingDetail = false;
    });
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Veuillez sélectionner une note (1-5 étoiles).');
      return;
    }
    if (_idBien == null) {
      setState(() => _error = 'Impossible de récupérer le bien associé.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await NotificationService().createReview(
        idBien: _idBien!,
        idReservation: widget.idReservation,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      widget.onReviewSubmitted?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci pour votre avis !'),
          backgroundColor: Colors.green,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ApiService.handleError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Erreur lors de l\'envoi de l\'avis.';
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _loadingDetail
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rate_review,
                        size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text(
                      'Laisser un avis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comment s\'est passé votre séjour ?',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),

                    // Étoiles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              i < _rating ? Icons.star : Icons.star_border,
                              size: 40,
                              color: Colors.orange,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (_rating > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _ratingLabel(),
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Commentaire
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Votre commentaire (optionnel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ],

                    const SizedBox(height: 20),

                    // Boutons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Plus tard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Envoyer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1:
        return 'Décevant';
      case 2:
        return 'Moyen';
      case 3:
        return 'Bien';
      case 4:
        return 'Très bien';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
