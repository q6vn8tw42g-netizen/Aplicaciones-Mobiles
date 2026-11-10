import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;
  bool _mostrarPassword = false;
  String? _error;

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final client = Supabase.instance.client;

    try {
      await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirRegistro() async {
    final registroCompletado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const RegisterScreen()),
    );
    if (registroCompletado == true &&
        mounted &&
        Supabase.instance.client.auth.currentSession != null &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.local_parking_rounded,
                                size: 32, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('EstacionaYa',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 6),
                        Text(
                          'Encuentra tu espacio en UPEC',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (valor) =>
                              (valor == null || !valor.contains('@'))
                                  ? 'Ingresa un correo válido'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_mostrarPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) {
                            if (!_cargando) _enviar();
                          },
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _mostrarPassword
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () => setState(
                                  () => _mostrarPassword = !_mostrarPassword),
                              icon: Icon(_mostrarPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            ),
                          ),
                          validator: (valor) =>
                              (valor == null || valor.length < 8)
                                  ? 'Mínimo 8 caracteres'
                                  : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                          onPressed: _cargando ? null : _enviar,
                          child: _cargando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Iniciar sesión'),
                        ),
                        TextButton(
                          onPressed: _cargando ? null : _abrirRegistro,
                          child: const Text('¿No tienes cuenta? Regístrate'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
