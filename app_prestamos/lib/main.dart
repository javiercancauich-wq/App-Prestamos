import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Préstamos',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  // Función para iniciar sesión conectándose a Python
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Reemplaza con tu IP local actual
      final url = Uri.parse('http://192.168.0.33:8000/login/');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String role = data['role'];
        String fullName = data['full_name'];
        int userId = data['user_id'];

        // Redirigimos según el rol recibido desde Python
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(role: role, fullName: fullName, userId: userId),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['detail'] ?? 'Credenciales incorrectas';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo conectar al servidor: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión - Préstamos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Ingresar', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla temporal de bienvenida según el rol


class DashboardScreen extends StatefulWidget {
  final String role;
  final String fullName;
  final int userId; // añadimos el id del usuario para hacer consultas

  const DashboardScreen({
    super.key,
    required this.role,
    required this.fullName,
    required this.userId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _loans = [];
  bool _isLoadingLoans = true;

  @override
  void initState() {
    super.initState();
    if(widget.role == 'client') {
      _fetchClientLoans();
    } else {
      setState(() {
        _isLoadingLoans = false;
      });
    }
  }

  // Funcion para obtner los prestamos desde python
  Future<void> _fetchClientLoans() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.33:8000/loans/users/${widget.userId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _loans = jsonDecode(response.body);
          _isLoadingLoans = false;
        });
      } else {
        setState(() {
          _isLoadingLoans = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLoans = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.role == 'admin';

    /*return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Panel de Administrador' : 'Mi Panel Financiero', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
        backgroundColor: isAdmin ? Colors.indigo : Color(0xFFF8F9FA),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¡Bienvenido, ${widget.fullName}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Chip(
              label: Text('Rol: ${widget.role.toUpperCase()}'),
              backgroundColor: isAdmin ? Colors.indigo[100] : Colors.green[100],
            ),
            const Divider(height: 40),
            
            // Contenido dinámico según el rol
            isAdmin
                ? const Expanded(
                    child: Center(
                      child: Text(
                        'Vista de Administrador:\nAquí gestionaremos los préstamos de todos los clientes próximamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                : Expanded(
                    child: _isLoadingLoans
                        ? const Center(child: CircularProgressIndicator())
                        : _loans.isEmpty
                            ? const Center(child: Text('No tienes préstamos registrados.'))
                            : ListView.builder(
  itemCount: _loans.length,
  itemBuilder: (context, index) {
    final loan = _loans[index];
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell( // <-- Hacemos la tarjeta interactiva al presionarla
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoanDetailScreen(loanData: loan),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 40),
            title: Text('Préstamo ID: ${loan['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Monto inicial: \$${loan['amount']}\nSaldo pendiente: \$${loan['balance_remaining']}',
            ),
            trailing: Chip(
              label: Text(loan['status']),
              backgroundColor: Colors.orange[100],
            ),
          ),
        ),
      ),
    );
  },
),
                             /*ListView.builder(
                                itemCount: _loans.length,
                                itemBuilder: (context, index) {
                                  final loan = _loans[index];
                                  return Card(
                                    elevation: 3,
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    child: InkWell(

                                    )

                                    /*child: ListTile(
                                      leading: const Icon(Icons.money, color: Colors.green, size: 40),
                                      title: Text('Préstamo ID: ${loan['id']}'),
                                      subtitle: Text(
                                        'Monto inicial: \$${loan['amount']}\nSaldo pendiente: \$${loan['balance_remaining']}',
                                      ),
                                      trailing: Chip(
                                        label: Text(loan['status']),
                                        backgroundColor: Colors.orange[100],
                                      ),
                                    ),*/
                                  );
                                },
                              ),*/
                  ),
          ],
        ),
      ),
    );
  }//Fin escandofff*/

  return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fondo gris fintech muy limpio
      appBar: AppBar(
        title: const Text(
          'Mi Panel Financiero',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B), // Azul pizarra corporativo
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: _isLoadingLoans
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Tarjeta de Resumen Ejecutivo ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ESTADO DE CUENTA ACTUAL',
                          style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _loans.isNotEmpty ? 'Préstamo Activo' : 'Sin Préstamos Activos',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Recuerde liquidar su saldo para ser elegible a nuevas líneas de crédito.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  const Text(
                    'Mis Créditos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // --- Lista de Préstamos Minimalista ---
                  Expanded(
                    child: _loans.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.folder_open, size: 60, color: Colors.grey),
                                SizedBox(height: 10),
                                Text('No hay registros de créditos activos.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _loans.length,
                            itemBuilder: (context, index) {
                              final loan = _loans[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200, width: 1),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoanDetailScreen(loanData: loan),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E293B).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1E293B)),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Crédito #${loan['id']}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Saldo pendiente: \$${loan['balance_remaining']}',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

}

/*class LoanDetailScreen extends StatelessWidget {
  final dynamic loanData;

  const LoanDetailScreen({super.key, required this.loanData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fondo gris fintech limpio
      appBar: AppBar(
        title: Text(
          'Detalle del Crédito #${loanData['id']}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B), // Azul pizarra corporativo
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            // --- Tarjeta Superior Resumen del Saldo ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SALDO PENDIENTE ACTUAL',
                    style: TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${loanData['balance_remaining']}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      'Estado: ${(loanData['status'] ?? 'active').toUpperCase()}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            const Text(
              'Información del Crédito',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            // --- Bloque de Datos Detallados ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.attach_money, 'Monto Solicitado', '\$${loanData['amount']}'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.calendar_today_outlined, 'Fecha de Solicitud del prestamo', loanData['requested_date'] ?? 'No registrada'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.event_available_outlined, 'Fecha de Entrega de dinero', loanData['disbursement_date'] ?? 'No registrada'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.play_circle_outline, 'Inicio de Pagos', loanData['start_payment_date'] ?? 'No registrada'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.schedule_outlined, 'Plazos Acordados', loanData['term'] ?? 'No especificado'),
                ],
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),

      
      // --- Botón inferior fijo para realizar pagos ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          onPressed: () => _showPaymentMethods(context),
          child: const Text(
            'Realizar Pago',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        
      ),
      
    );

    
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),

      
    );
    
  }

  // --- Método para mostrar las opciones de pago en un BottomSheet ---
  void _showPaymentMethods(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccione método de pago',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Elija cómo desea abonar a su saldo pendiente.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Opción 1: OXXO Pay
              _buildPaymentOptionTile(
                context,
                icon: Icons.storefront_outlined,
                title: 'Efectivo en OXXO Pay',
                subtitle: 'Genera un código de barras para pagar en tienda',
                onTap: () {
                  Navigator.pop(context);
                  _showOxxoCodeDialog(context);
                },
              ),
              const Divider(height: 20),

              // Opción 2: Transferencia SPEI
              _buildPaymentOptionTile(
                context,
                icon: Icons.account_balance_outlined,
                title: 'Transferencia Bancaria (SPEI)',
                subtitle: 'CLABE interbancaria única',
                onTap: () {
                  Navigator.pop(context);
                  _showSpeiDialog(context);
                },
              ),
              const Divider(height: 20),

              // Opción 3: Tarjeta Débito / Crédito
              _buildPaymentOptionTile(
                context,
                icon: Icons.credit_card_outlined,
                title: 'Tarjeta de Débito o Crédito',
                subtitle: 'Pago inmediato en línea',
                onTap: () {
                  Navigator.pop(context);
                  _showCardPaymentDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOptionTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- Diálogos de simulación de pago ---
  void _showOxxoCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referencia OXXO Pay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Presenta este código en cualquier tienda OXXO del país para realizar tu pago:'),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Text('9823 4910 2384 1928', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
            ),
            const SizedBox(height: 15),
            Text('Monto a pagar: \$${loanData['balance_remaining']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))
        ],
      ),
    );
  }

  void _showSpeiDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transferencia SPEI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Realiza una transferencia interbancaria con los siguientes datos:'),
            const SizedBox(height: 10),
            const Text('Banco: STP / Fintech'),
            const Text('CLABE: 646180157000000012'),
            const SizedBox(height: 10),
            Text('Monto exacto: \$${loanData['balance_remaining']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))
        ],
      ),
    );
  }

  void _showCardPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pago con Tarjeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Número de Tarjeta', hintText: '4532 •••• •••• ••••')),
            const SizedBox(height: 10),
            Row(
              children: const [
                Expanded(child: TextField(decoration: InputDecoration(labelText: 'MM/AA'))),
                SizedBox(width: 10),
                Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV'))),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Pago procesado con éxito! (Simulación)')),
              );
            },
            child: const Text('Pagar Ahora', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

    Future<List<dynamic>> _fetchPayments(int loanId) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.33:8000/loans/$loanId/payments'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error al cargar pagos: $e");
    }
    return [];
  }
}
*/


class LoanDetailScreen extends StatelessWidget {
  final dynamic loanData;

  const LoanDetailScreen({super.key, required this.loanData});

  Future<List<dynamic>> _fetchPayments(int loanId) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.33:8000/loans/$loanId/payments'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error al cargar pagos: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Detalle del Crédito #${loanData['id']}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SALDO PENDIENTE ACTUAL',
                    style: TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${loanData['balance_remaining']}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      'Estado: ${(loanData['status'] ?? 'active').toUpperCase()}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Información del Crédito',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.attach_money, 'Monto Solicitado', '\$${loanData['amount']}'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.calendar_today_outlined, 'Fecha de Solicitud', loanData['requested_date'] ?? 'No registrada'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.event_available_outlined, 'Fecha de Entrega', loanData['disbursement_date'] ?? 'No registrada'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.play_circle_outline, 'Inicio de Pagos', loanData['start_payment_date'] ?? 'No registrada'),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDetailRow(Icons.schedule_outlined, 'Plazos Acordados', loanData['term'] ?? 'No especificado'),
                ],
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF1E293B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showPaymentHistory(context, loanData['id']),
                child: const Text('Historial', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => _showPaymentMethods(context),
                child: const Text('Realizar Pago', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethods(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccione método de pago',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Elija cómo desea abonar a su saldo pendiente.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildPaymentOptionTile(
                context,
                icon: Icons.storefront_outlined,
                title: 'Efectivo en OXXO Pay',
                subtitle: 'Genera un código de barras para pagar en tienda',
                onTap: () {
                  Navigator.pop(context);
                  _showOxxoCodeDialog(context);
                },
              ),
              const Divider(height: 20),
              _buildPaymentOptionTile(
                context,
                icon: Icons.account_balance_outlined,
                title: 'Transferencia Bancaria (SPEI)',
                subtitle: 'CLABE interbancaria única',
                onTap: () {
                  Navigator.pop(context);
                  _showSpeiDialog(context);
                },
              ),
              const Divider(height: 20),
              _buildPaymentOptionTile(
                context,
                icon: Icons.credit_card_outlined,
                title: 'Tarjeta de Débito o Crédito',
                subtitle: 'Pago inmediato en línea',
                onTap: () {
                  Navigator.pop(context);
                  _showCardPaymentDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOptionTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showPaymentHistory(BuildContext context, int loanId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historial de Abonos y Pagos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _fetchPayments(loanId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)));
                    }
                    final payments = snapshot.data ?? [];
                    if (payments.isEmpty) {
                      return const Center(
                        child: Text('No hay pagos registrados para este crédito.', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return ListView.builder(
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final p = payments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Método: ${p['payment_method'].toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(p['created_at'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('\$${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 2),
                                  Text(
                                    p['payment_status'] == 'approved' ? 'Aprobado' : 'En Revisión',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: p['payment_status'] == 'approved' ? Colors.green : Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOxxoCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referencia OXXO Pay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Presenta este código en cualquier tienda OXXO del país para realizar tu pago:'),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Text('9823 4910 2384 1928', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
            ),
            const SizedBox(height: 15),
            Text('Monto a pagar: \$${loanData['balance_remaining']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))
        ],
      ),
    );
  }

  void _showSpeiDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transferencia SPEI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Realiza una transferencia interbancaria con los siguientes datos:'),
            const SizedBox(height: 10),
            const Text('Banco: STP / Fintech'),
            const Text('CLABE: 646180157000000012'),
            const SizedBox(height: 10),
            Text('Monto exacto: \$${loanData['balance_remaining']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))
        ],
      ),
    );
  }

  void _showCardPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pago con Tarjeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Corregido: Sin 'const' en TextField
            TextField(decoration: const InputDecoration(labelText: 'Número de Tarjeta', hintText: '4532 •••• •••• ••••')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(labelText: 'MM/AA'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(decoration: const InputDecoration(labelText: 'CVV'))),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Pago procesado con éxito! (Simulación)')),
              );
            },
            child: const Text('Pagar Ahora', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/*class DashboardScreen extends StatelessWidget {
  final String role;
  final String fullName;
  final int userId; // añadimos el id del usuario para hacer consultas 

  const DashboardScreen({
    super.key, 
    required this.role, 
    required this.fullName,
    required this.userId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();}

  class _DashboardScreenState extends State<DashboardScreen> {
    List<dynamic> _loans = [];
    bool _isLoadingLoans = true;

    @override
    void initState() {
      super.initState();
      if (widget.role == 'client') {
        _fetchClientLoans();
      }
  }

  // Funcion para obtener los prestamos de un usuario especifico
  Future<void> _fetchClientLoans() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.33:8000/loans/user/${widget.userId}'),
      );
      if (response.statusCode == 200){
        setState(() {
          _loans = jsonDecode(response.body);
          _isLoadingLoans = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLoans = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Panel de Administrador (Dueño)' : 'Panel de Cliente'),
        backgroundColor: isAdmin ? Colors.indigo : Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¡Bienvenido, $fullName!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Chip(
              label: Text('Rol: ${role.toUpperCase()}'),
              backgroundColor: isAdmin ? Colors.indigo[100] : Colors.green[100],
            ),
            const Divider(height: 40),
            isAdmin
                ? const Text('Aquí verás el control de morosos, préstamos activos y aprobaciones de pagos.')
                : const Text('Aquí verás tu saldo pendiente, tus cuotas y la opción de pagar o subir tu comprobante.'),
          ],
        ),
      ),
    );
  }
}*/