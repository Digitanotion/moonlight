import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/withdrawal/domain/repositories/withdrawal_repository.dart';
import 'package:moonlight/features/withdrawal/presentation/cubit/withdrawal_cubit.dart';
import 'package:moonlight/features/withdrawal/presentation/pages/withdrawal_page.dart';

const _evm = '0x52908400098527886E0F7030069857D2E4169EE7';

class _FakeRepo implements WithdrawalRepository {
  Map<String, dynamic>? lastCrypto;

  @override
  Future<int> getWithdrawableBalance() async => 10000; // $50

  @override
  Future<List<Map<String, dynamic>>> fetchBanks(String country) async => [];

  @override
  Future<Map<String, dynamic>> fetchCryptoOptions() async => {
    'enabled': true,
    'min_usd': 5,
    'networks': [
      {
        'code': 'POLYGON',
        'label': 'Polygon',
        'coins': ['USDT', 'USDC'],
      },
      {
        'code': 'BASE',
        'label': 'Base',
        'coins': ['USDC'],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> createCryptoWithdrawal({
    required double amountUsd,
    required String coin,
    required String network,
    required String walletAddress,
    required String walletAddressConfirm,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    lastCrypto = {
      'amountUsd': amountUsd,
      'coin': coin,
      'network': network,
      'walletAddress': walletAddress,
      'pin': pin,
    };
    return {'reference': 'moonlight_wd_test'};
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('submitCryptoWithdrawal sends crypto details and goes pending', () async {
    final repo = _FakeRepo();
    final cubit = WithdrawalCubit(repository: repo);

    await cubit.submitCryptoWithdrawal(
      amountUsd: 10,
      coin: 'USDT',
      network: 'POLYGON',
      walletAddress: _evm,
      walletAddressConfirm: _evm,
      pin: '1234',
    );

    expect(repo.lastCrypto, {
      'amountUsd': 10.0,
      'coin': 'USDT',
      'network': 'POLYGON',
      'walletAddress': _evm,
      'pin': '1234',
    });
    final state = cubit.state as WithdrawalPending;
    expect(state.method, 'crypto');
    expect(state.reference, 'moonlight_wd_test');
  });

  testWidgets('Crypto method shows networks, coins and validates address', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => WithdrawalCubit(repository: _FakeRepo()),
          child: const WithdrawalPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crypto'));
    await tester.pumpAndSettle();

    expect(find.text('Polygon'), findsOneWidget);
    expect(find.text('USDT'), findsOneWidget);
    expect(find.text('Polygon wallet address'), findsOneWidget);

    // Base only supports USDC — the coin choice follows the network.
    await tester.tap(find.text('Base'));
    await tester.pumpAndSettle();
    expect(find.text('USDT'), findsNothing);
    expect(find.text('USDC'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '3'); // below $5 crypto minimum
    await tester.enterText(fields.at(1), '0x123'); // bad address
    await tester.pump();

    await tester.ensureVisible(find.text('Proceed to Withdraw'));
    await tester.tap(find.text('Proceed to Withdraw'));
    await tester.pumpAndSettle();

    expect(find.text('Minimum crypto withdrawal is \$5.00'), findsOneWidget);
    expect(find.text('Not a valid Base address'), findsOneWidget);

    await tester.enterText(fields.at(1), _evm);
    await tester.enterText(fields.at(2), '${_evm.substring(0, 41)}0');
    await tester.tap(find.text('Proceed to Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Not a valid Base address'), findsNothing);
    expect(find.text('Addresses do not match'), findsOneWidget);
  });
}
