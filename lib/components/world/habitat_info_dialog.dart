import 'package:flutter/material.dart';
import '../../models/habitat_model.dart';
import '../../models/habitat_catalog.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class HabitatInfoDialog extends StatelessWidget {
  final HabitatModel habitat;
  final Function(HabitatModel) onOpenCare;

  const HabitatInfoDialog({
    super.key,
    required this.habitat,
    required this.onOpenCare,
  });

  @override
  Widget build(BuildContext context) {
    final catItem = HabitatCatalog.findById(habitat.habitatId);

    return GenericModal(
      title: habitat.name.toUpperCase(),
      maxWidth: 540,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card with habitat artwork
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD97706), width: 1.5),
            ),
            child: Row(
              children: [
                if (catItem != null)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(catItem.assetImage, fit: BoxFit.contain),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habitat.name,
                        style: const TextStyle(
                          color: Color(0xFF3B1404),
                          fontFamily: 'Lilita One',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        habitat.type == 'habitat'
                            ? '${habitat.dogs.length} / 4 Dogs Resident'
                            : 'Care & Resource Facility',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontFamily: 'Fredoka',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        catItem?.element ?? 'Island Facility',
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontFamily: 'Fredoka',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Resident Dogs Section
          if (habitat.type == 'habitat') ...[
            const Text(
              'RESIDENT COMPANIONS',
              style: TextStyle(
                color: Color(0xFF78350F),
                fontFamily: 'Lilita One',
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            if (habitat.dogs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8D8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD97706), style: BorderStyle.solid),
                ),
                child: const Text(
                  'No dogs resident here yet. Adopt a pup from the Build Store!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF78350F),
                    fontFamily: 'Fredoka',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: habitat.dogs.map((dog) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pets, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          dog.name,
                          style: const TextStyle(
                            color: Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lvl ${dog.level}',
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontFamily: 'Fredoka',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
          const Spacer(),

          // Care Button at bottom
          if (habitat.type == 'habitat')
            Center(
              child: HoverScale(
                scale: 1.05,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenCare(habitat);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'OPEN CARE SANCTUARY',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
