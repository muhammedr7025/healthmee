import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health/app.dart';
import 'package:health/core/api/auth_storage.dart';
import 'package:health/features/auth/data/auth_repository.dart';
import 'package:health/features/auth/domain/user.dart';
import 'package:health/features/auth/presentation/login_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio(), AuthStorage());

  @override
  Future<AppUser?> currentUser() async => null;
}

void main() {
  testWidgets('shows the login screen when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
        child: const HealthApp(),
      ),
    );
    // Not pumpAndSettle: KunjanMascot's idle/thinking states loop
    // indefinitely by design, so it never "settles".
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
