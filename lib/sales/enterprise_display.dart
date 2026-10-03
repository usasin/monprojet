class EnterpriseDisplaySettings {
  const EnterpriseDisplaySettings({
    this.showContracts = true,
    this.showRevenue = true,
  });
  final bool showContracts, showRevenue;
  factory EnterpriseDisplaySettings.fromMap(dynamic data) {
    if (data is! Map) return const EnterpriseDisplaySettings();
    final contracts = data['showContracts'] != false;
    final revenue = data['showRevenue'] != false;
    return EnterpriseDisplaySettings(
      showContracts: contracts || !revenue,
      showRevenue: revenue,
    );
  }
}
