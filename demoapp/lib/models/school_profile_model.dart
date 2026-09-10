/// Public school profile — the info shown on dashboards and settings:
/// name, motto, logo, and contact details (email / number / address / website).
/// Editable by the school admin; served by `sc_auth.api.data.school_profile`.
class SchoolProfileModel {
  final String schoolName;
  final String? motto;
  final String? logoUrl;
  final String? contactEmail;
  final String? contactNumber;
  final String? website;
  final String? address;

  const SchoolProfileModel({
    required this.schoolName,
    this.motto,
    this.logoUrl,
    this.contactEmail,
    this.contactNumber,
    this.website,
    this.address,
  });

  factory SchoolProfileModel.fromJson(Map<String, dynamic> json) {
    return SchoolProfileModel(
      schoolName: json['school_name'] as String? ?? 'School',
      motto: json['motto'] as String?,
      logoUrl: json['logo_url'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactNumber: json['contact_number'] as String?,
      website: json['website'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_name': schoolName,
      'motto': motto,
      'logo_url': logoUrl,
      'contact_email': contactEmail,
      'contact_number': contactNumber,
      'website': website,
      'address': address,
    };
  }

  /// Absolute URL for a logo path like `/files/logo.png` (Frappe serves
  /// public files from its own origin).
  String? logoUrlFor(String baseUrl) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }
}
