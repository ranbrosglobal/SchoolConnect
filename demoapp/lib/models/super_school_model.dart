/// A school as registered on the super-admin site. Each school runs on its
/// own Frappe site + database; this model mirrors `sc_auth.api.superadmin`
/// registry documents (the `School` doctype on the super site).
class SuperSchoolModel {
  final String name;
  final String schoolName;
  final String site;
  final int port;
  final String? dbName;
  final String status;
  final String? logoUrl;
  final String? contactEmail;
  final String? contactNumber;
  final String? website;
  final String? motto;
  final String? address;
  final String? adminName;
  final String? adminEmail;
  final bool hasPassword;

  const SuperSchoolModel({
    required this.name,
    required this.schoolName,
    required this.site,
    required this.port,
    this.dbName,
    this.status = 'Active',
    this.logoUrl,
    this.contactEmail,
    this.contactNumber,
    this.website,
    this.motto,
    this.address,
    this.adminName,
    this.adminEmail,
    this.hasPassword = false,
  });

  factory SuperSchoolModel.fromJson(Map<String, dynamic> json) {
    return SuperSchoolModel(
      name: json['name']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 8000,
      dbName: json['db_name']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      logoUrl: json['logo_url']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      contactNumber: json['contact_number']?.toString(),
      website: json['website']?.toString(),
      motto: json['motto']?.toString(),
      address: json['address']?.toString(),
      adminName: json['school_admin_name']?.toString(),
      adminEmail: json['school_admin_email']?.toString(),
      hasPassword: json['has_password'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'school_name': schoolName,
        'site': site,
        'port': port,
        'db_name': dbName,
        'status': status,
        'logo_url': logoUrl,
        'contact_email': contactEmail,
        'contact_number': contactNumber,
        'website': website,
        'motto': motto,
        'address': address,
        'school_admin_name': adminName,
        'school_admin_email': adminEmail,
        'has_password': hasPassword,
      };
}

/// One row of the guest `public_schools` selector (login screen picker).
class PublicSchoolEntry {
  final String name;
  final String schoolName;
  final String site;
  final int port;
  final String? logoUrl;
  final String? motto;
  final String? contactEmail;

  const PublicSchoolEntry({
    required this.name,
    required this.schoolName,
    required this.site,
    required this.port,
    this.logoUrl,
    this.motto,
    this.contactEmail,
  });

  factory PublicSchoolEntry.fromJson(Map<String, dynamic> json) {
    return PublicSchoolEntry(
      name: json['name']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 8000,
      logoUrl: json['logo_url']?.toString(),
      motto: json['motto']?.toString(),
      contactEmail: json['contact_email']?.toString(),
    );
  }

  String get baseUrl => 'http://localhost:$port';
}
