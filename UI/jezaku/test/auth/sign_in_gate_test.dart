import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_rules_mode.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_providers.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/screens/sign_in_screen.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/auth/states/sign_in_requirement.dart';
import 'package:jejaku/features/auth/widgets/account_settings_tile.dart';
import 'package:jejaku/features/auth/widgets/sign_in_gate.dart';
import 'package:material_ui/material_ui.dart';

class _FakeGateway implements AuthGateway {
  _FakeGateway({this.available = true});

  final bool available;
  AuthFailure? failWith;
  Completer<AuthSession>? hold;
  Object? signOutError;
  final signIns = <({String identifier, String password})>[];
  final signedOut = <AuthSession>[];

  @override
  bool get isAvailable => available;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    signIns.add((identifier: identifier, password: password));
    if (hold != null) {
      return hold!.future;
    }
    if (failWith != null) {
      throw failWith!;
    }
    return _session;
  }

  @override
  Future<void> signOut(AuthSession session) async {
    signedOut.add(session);
    if (signOutError != null) {
      throw signOutError!;
    }
  }
}

final _session = AuthSession(
  sessionId: 'sess-1',
  userId: 'user-1',
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  expiresAt: DateTime.utc(2999),
);

ProviderContainer _container(
  _FakeGateway gateway, {
  FrameRulesMode mode = FrameRulesMode.strict,
}) {
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(gateway),
      frameRulesModeProvider.overrideWithValue(mode),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpGate(WidgetTester tester, ProviderContainer container) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => SignInGate(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const Text('the app'),
              const AccountSettingsTile(),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _enter(WidgetTester tester, String who, String password) async {
  await tester.enterText(find.byKey(const ValueKey('sign_in_identifier')), who);
  await tester.enterText(find.byKey(const ValueKey('sign_in_password')), password);
}

void main() {
  group('when sign-in is required', () {
    test('only for strict builds that have an identity service', () {
      bool required(_FakeGateway gateway, FrameRulesMode mode) =>
          _container(gateway, mode: mode).read(signInRequiredProvider);

      expect(required(_FakeGateway(), FrameRulesMode.strict), isTrue);
      expect(required(_FakeGateway(), FrameRulesMode.demo), isFalse);
      expect(
        required(_FakeGateway(available: false), FrameRulesMode.strict),
        isFalse,
      );
    });
  });

  group('AuthController', () {
    test('signing in stores the session and feeds the current user id',
        () async {
      final gateway = _FakeGateway();
      final container = _container(gateway);
      expect(container.read(currentUserIdProvider), isNull);

      await container
          .read(authControllerProvider.notifier)
          .signIn(identifier: '  ibuk@example.com ', password: 'secret');

      final state = container.read(authControllerProvider);
      expect(state.isSignedIn, isTrue);
      expect(state.failure, isNull);
      expect(container.read(currentUserIdProvider), 'user-1');
      // The identifier is trimmed; the password is sent untouched.
      expect(gateway.signIns.single.identifier, 'ibuk@example.com');
      expect(gateway.signIns.single.password, 'secret');
    });

    test('a failed sign-in keeps the user signed out and says why', () async {
      final gateway = _FakeGateway()
        ..failWith = const AuthFailure(AuthFailureReason.invalidCredentials);
      final container = _container(gateway);

      await container
          .read(authControllerProvider.notifier)
          .signIn(identifier: 'a', password: 'b');

      final state = container.read(authControllerProvider);
      expect(state.isSignedIn, isFalse);
      expect(state.busy, isFalse);
      expect(state.failure?.reason, AuthFailureReason.invalidCredentials);
      expect(container.read(currentUserIdProvider), isNull);
    });

    test('an unexpected error becomes a server failure', () async {
      final container = ProviderContainer(
        overrides: [authGatewayProvider.overrideWithValue(_ThrowingGateway())],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signIn(identifier: 'a', password: 'b');

      expect(
        container.read(authControllerProvider).failure?.reason,
        AuthFailureReason.server,
      );
    });

    test('a second sign-in while one is running is ignored', () async {
      final gateway = _FakeGateway()..hold = Completer<AuthSession>();
      final container = _container(gateway);
      final controller = container.read(authControllerProvider.notifier);

      final first = controller.signIn(identifier: 'a', password: 'b');
      expect(container.read(authControllerProvider).busy, isTrue);
      await controller.signIn(identifier: 'a', password: 'b');
      expect(gateway.signIns, hasLength(1));

      gateway.hold!.complete(_session);
      await first;
      expect(container.read(authControllerProvider).isSignedIn, isTrue);
    });

    test('sign out clears the session even if the service fails', () async {
      final gateway = _FakeGateway()..signOutError = StateError('offline');
      final container = _container(gateway);
      final controller = container.read(authControllerProvider.notifier);
      await controller.signIn(identifier: 'a', password: 'b');

      await controller.signOut();

      expect(container.read(authControllerProvider).isSignedIn, isFalse);
      expect(container.read(currentUserIdProvider), isNull);
      expect(gateway.signedOut.single.sessionId, 'sess-1');
    });
  });

  group('SignInGate', () {
    testWidgets('a demo build goes straight to the app', (tester) async {
      final container = _container(_FakeGateway(), mode: FrameRulesMode.demo);
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsOneWidget);
      expect(find.byKey(const ValueKey('sign_in_submit')), findsNothing);
    });

    testWidgets('a build without an identity service goes straight to the app',
        (tester) async {
      final container = _container(_FakeGateway(available: false));
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsOneWidget);
    });

    testWidgets('a strict build shows sign-in first, then the app',
        (tester) async {
      final gateway = _FakeGateway();
      final container = _container(gateway);
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsNothing);
      expect(find.text('Sign in to Jezaku'), findsOneWidget);

      await _enter(tester, 'ibuk@example.com', 'secret');
      await tester.tap(find.byKey(const ValueKey('sign_in_submit')));
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsOneWidget);
      expect(find.byKey(const ValueKey('sign_in_submit')), findsNothing);
    });

    testWidgets('empty fields are caught before any request', (tester) async {
      final gateway = _FakeGateway();
      final container = _container(gateway);
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sign_in_submit')));
      await tester.pump();

      expect(find.byKey(const ValueKey('sign_in_error')), findsOneWidget);
      expect(gateway.signIns, isEmpty);
    });

    testWidgets('a refused sign-in explains itself without naming the field',
        (tester) async {
      final gateway = _FakeGateway()
        ..failWith = const AuthFailure(AuthFailureReason.invalidCredentials);
      final container = _container(gateway);
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      await _enter(tester, 'ibuk@example.com', 'wrong');
      await tester.tap(find.byKey(const ValueKey('sign_in_submit')));
      await tester.pumpAndSettle();

      expect(
        find.text(authFailureMessage(AuthFailureReason.invalidCredentials)),
        findsOneWidget,
      );
      expect(find.text('the app'), findsNothing);
    });

    testWidgets('shows progress and disables the button while signing in',
        (tester) async {
      final gateway = _FakeGateway()..hold = Completer<AuthSession>();
      final container = _container(gateway);
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      await _enter(tester, 'a', 'b');
      await tester.tap(find.byKey(const ValueKey('sign_in_submit')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('sign_in_submit')),
      );
      expect(button.onPressed, isNull);

      gateway.hold!.complete(_session);
      await tester.pumpAndSettle();
      expect(find.text('the app'), findsOneWidget);
    });

    testWidgets('the password is hidden until the user asks to see it',
        (tester) async {
      final container = _container(_FakeGateway());
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      TextField password() => tester.widget<TextField>(
            find.byKey(const ValueKey('sign_in_password')),
          );
      expect(password().obscureText, isTrue);
      await tester.tap(find.byKey(const ValueKey('sign_in_show_password')));
      await tester.pump();
      expect(password().obscureText, isFalse);
    });

    testWidgets('signing out from the account tile returns to sign-in',
        (tester) async {
      final gateway = _FakeGateway();
      final container = _container(gateway);
      await container
          .read(authControllerProvider.notifier)
          .signIn(identifier: 'a', password: 'b');
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('account_tile')), findsOneWidget);
      expect(find.text('user-1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign_out_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('the app'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign_out_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsNothing);
      expect(find.text('Sign in to Jezaku'), findsOneWidget);
    });

    testWidgets('the account tile is absent when nobody is signed in',
        (tester) async {
      final container = _container(_FakeGateway(), mode: FrameRulesMode.demo);
      await _pumpGate(tester, container);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('account_tile')), findsNothing);
    });
  });
}

class _ThrowingGateway implements AuthGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) {
    throw StateError('boom');
  }

  @override
  Future<void> signOut(AuthSession session) async {}
}
