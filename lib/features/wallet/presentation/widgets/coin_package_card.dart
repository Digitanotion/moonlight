import 'package:flutter/material.dart';
import '../../domain/models/coin_package.dart';
import 'package:intl/intl.dart';

class CoinPackageCard extends StatelessWidget {
  final CoinPackage pkg;
  final VoidCallback onBuy;

  const CoinPackageCard({Key? key, required this.pkg, required this.onBuy})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFF1B1030),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.monetization_on, color: Colors.amber, size: 28),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${NumberFormat.decimalPattern().format(pkg.coins)} Coins',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  nf.format(pkg.priceUSD),
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onBuy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  child: Text(
                    'Buy Now',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
