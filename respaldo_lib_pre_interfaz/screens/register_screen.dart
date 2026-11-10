import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  bool _cargando = false;
  bool _mostrarPassword = false;
  String? _mensaje;
  String? _error;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _mensaje = null;
      _error = null;
    });

    try {
      final resultado = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (resultado.session != null) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _mensaje =
              'Cuenta creada. Revisa tu correo para confirmarla y luego inicia sesión.';
        });
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Regístrate en EstacionaYa',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Usa tu correo y crea una contraseña de al menos 8 caracteres.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newUsername],
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) => value == null ||
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value.trim())
                              ? 'Ingresa un correo válido'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_mostrarPassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
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
                          validator: (value) =>
                              value == null || value.length < 8
                                  ? 'Usa al menos 8 caracteres'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmarPasswordController,
                          obscureText: !_mostrarPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_cargando) _registrar();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.lock_reset_rounded),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                                  ? 'Las contraseñas no coinciden'
                                  : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        if (_mensaje != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _mensaje!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _cargando ? null : _registrar,
                          child: _cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Crear cuenta'),
                        ),
                        TextButton(
                          onPressed: _cargando
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Volver a iniciar sesión'),
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
