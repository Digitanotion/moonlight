// lib/core/constants/flutterwave_countries.dart
//
// All Flutterwave-supported payout countries with their currency codes.
// Kept here so no API call is needed to populate a country dropdown.
// Source: Flutterwave payout documentation (April 2026).
//
// Shared by the main wallet withdrawal screen and the offerwall
// withdrawal sheet — both use the same Flutterwave bank-transfer rails,
// so both need the same country list.

class FlutterwaveCountryInfo {
  final String name;
  final String currency;
  const FlutterwaveCountryInfo(this.name, this.currency);
}

const List<FlutterwaveCountryInfo> kFlutterwaveCountries = [
  // Africa
  FlutterwaveCountryInfo('Nigeria', 'NGN'),
  FlutterwaveCountryInfo('Ghana', 'GHS'),
  FlutterwaveCountryInfo('Kenya', 'KES'),
  FlutterwaveCountryInfo('South Africa', 'ZAR'),
  FlutterwaveCountryInfo('Uganda', 'UGX'),
  FlutterwaveCountryInfo('Tanzania', 'TZS'),
  FlutterwaveCountryInfo('Rwanda', 'RWF'),
  FlutterwaveCountryInfo('Zambia', 'ZMW'),
  FlutterwaveCountryInfo('Cameroon', 'XAF'),
  FlutterwaveCountryInfo('Chad', 'XAF'),
  FlutterwaveCountryInfo('Congo', 'XAF'),
  FlutterwaveCountryInfo('Gabon', 'XAF'),
  FlutterwaveCountryInfo('Senegal', 'XOF'),
  FlutterwaveCountryInfo('Ivory Coast', 'XOF'),
  FlutterwaveCountryInfo('Malawi', 'MWK'),
  FlutterwaveCountryInfo('Sierra Leone', 'SLL'),
  FlutterwaveCountryInfo('Ethiopia', 'ETB'),
  // Europe — EUR bloc
  FlutterwaveCountryInfo('Austria', 'EUR'),
  FlutterwaveCountryInfo('Belgium', 'EUR'),
  FlutterwaveCountryInfo('Bulgaria', 'EUR'),
  FlutterwaveCountryInfo('Croatia', 'EUR'),
  FlutterwaveCountryInfo('Cyprus', 'EUR'),
  FlutterwaveCountryInfo('Czech Republic', 'EUR'),
  FlutterwaveCountryInfo('Denmark', 'EUR'),
  FlutterwaveCountryInfo('Estonia', 'EUR'),
  FlutterwaveCountryInfo('Finland', 'EUR'),
  FlutterwaveCountryInfo('Germany', 'EUR'),
  FlutterwaveCountryInfo('Greece', 'EUR'),
  FlutterwaveCountryInfo('Hungary', 'EUR'),
  FlutterwaveCountryInfo('Ireland', 'EUR'),
  FlutterwaveCountryInfo('Italy', 'EUR'),
  FlutterwaveCountryInfo('Latvia', 'EUR'),
  FlutterwaveCountryInfo('Lithuania', 'EUR'),
  FlutterwaveCountryInfo('Luxembourg', 'EUR'),
  FlutterwaveCountryInfo('Malta', 'EUR'),
  FlutterwaveCountryInfo('Netherlands', 'EUR'),
  FlutterwaveCountryInfo('Poland', 'EUR'),
  FlutterwaveCountryInfo('Slovakia', 'EUR'),
  FlutterwaveCountryInfo('Slovenia', 'EUR'),
  FlutterwaveCountryInfo('Spain', 'EUR'),
  FlutterwaveCountryInfo('Sweden', 'EUR'),
  // Europe — non-EUR
  FlutterwaveCountryInfo('UK', 'GBP'),
  // Americas
  FlutterwaveCountryInfo('US', 'USD'),
  // Asia-Pacific
  FlutterwaveCountryInfo('Australia', 'AUD'),
  FlutterwaveCountryInfo('India', 'INR'),
  // Middle East
  FlutterwaveCountryInfo('UAE', 'AED'),
];

/// Quick lookup: country name -> currency code.
String flutterwaveCurrencyFor(String country) => kFlutterwaveCountries
    .firstWhere(
      (c) => c.name == country,
      orElse: () => const FlutterwaveCountryInfo('', 'USD'),
    )
    .currency;
