import 'package:flutter/material.dart';

/// Intelli-Store carries **general products** — farm equipment, solar,
/// electronics, household and business items — not just agri-equipment.
/// Every product is priced by the buying group's credit rating (see
/// `docs/specs` and the backend's credit-rating contract), regardless of
/// category.
///
/// The backend `category` field is a free string (default `AGRI_EQUIPMENT`
/// from early agri-only catalogues); this maps the known codes to an icon and
/// friendly label, and falls back to a generic bag icon + title-cased label
/// for anything else so new categories never look broken.
class StoreCategoryInfo {
  const StoreCategoryInfo(this.icon, this.label);
  final IconData icon;
  final String label;
}

const Map<String, StoreCategoryInfo> _kKnownCategories = {
  'AGRI_EQUIPMENT': StoreCategoryInfo(Icons.agriculture_outlined, 'Farm Equipment'),
  'SOLAR_ENERGY': StoreCategoryInfo(Icons.solar_power_outlined, 'Solar & Energy'),
  'ELECTRONICS': StoreCategoryInfo(Icons.devices_outlined, 'Electronics'),
  'PHONES': StoreCategoryInfo(Icons.smartphone_outlined, 'Phones'),
  'HOUSEHOLD': StoreCategoryInfo(Icons.chair_outlined, 'Household'),
  'BUSINESS_EQUIPMENT': StoreCategoryInfo(Icons.storefront_outlined, 'Business Equipment'),
  'VEHICLES': StoreCategoryInfo(Icons.two_wheeler_outlined, 'Vehicles & Transport'),
  'HEALTH': StoreCategoryInfo(Icons.health_and_safety_outlined, 'Health'),
  'EDUCATION': StoreCategoryInfo(Icons.school_outlined, 'Education'),
  'CONSTRUCTION': StoreCategoryInfo(Icons.construction_outlined, 'Construction'),
  'WATER_IRRIGATION': StoreCategoryInfo(Icons.water_drop_outlined, 'Water & Irrigation'),
};

const _fallbackIcon = Icons.shopping_bag_outlined;

/// Icon + label for a category code. [fallbackLabel] (typically the model's
/// own title-cased `categoryLabel`) is used when the code isn't recognised.
StoreCategoryInfo storeCategoryInfo(String category, String fallbackLabel) {
  final known = _kKnownCategories[category.toUpperCase()];
  if (known != null) return known;
  return StoreCategoryInfo(
    _fallbackIcon,
    fallbackLabel.isEmpty ? 'General' : fallbackLabel,
  );
}
