import 'package:estacionaya/screens/login_screen.dart';
import 'package:estacionaya/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pantalla de inicio de sesión', () {
    testWidgets('valida correo y contraseña antes de enviar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    });

    testWidgets('permite mostrar y ocultar la contraseña', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      final password = find.byType(EditableText).last;
      expect(tester.widget<EditableText>(password).obscureText, isTrue);

      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(password).obscureText, isFalse);
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });
  });

  group('Pantalla de registro', () {
    testWidgets('valida que las contraseñas coincidan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RegisterScreen()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'estudiante@upec.edu.ec',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'clave-segura-123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'otra-clave-456',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('muestra navegación para volver al inicio de sesión',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RegisterScreen()),
      );

      expect(find.widgetWithText(FilledButton, 'Crear cuenta'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Crear cuenta'), findsOneWidget);
      expect(find.text('Volver a iniciar sesión'), findsOneWidget);
    });
  });
}
