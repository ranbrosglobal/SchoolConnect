class SchoolModel {
  final String id;
  final String name;
  final String? city;
  final String? state;
  final String? country;
  final String? address;
  final String? phone;
  final String? email;
  final bool isEnabled;

  SchoolModel({
    required this.id,
    required this.name,
    this.city,
    this.state,
    this.country,
    this.address,
    this.phone,
    this.email,
    this.isEnabled = true,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['name'] ?? '',
      name: json['school_name'] ?? json['name'] ?? '',
      city: json['city'],
      state: json['state'],
      country: json['country'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      isEnabled: json['disabled'] != true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'school_name': name,
      'city': city,
      'state': state,
      'country': country,
      'address': address,
      'phone': phone,
      'email': email,
    };
  }
}
