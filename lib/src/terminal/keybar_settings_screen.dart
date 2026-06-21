import 'package:flutter/material.dart';
import 'keybar_config.dart';

/// Pantalla de configuración del teclado: activar/desactivar teclas y
/// reordenarlas con flechas ↑↓. Guarda los cambios al instante.
class KeybarSettingsScreen extends StatefulWidget {
  final List<KeyConfigItem> initial;
  final void Function(List<KeyConfigItem>) onChanged;

  const KeybarSettingsScreen({super.key, required this.initial, required this.onChanged});

  @override
  State<KeybarSettingsScreen> createState() => _KeybarSettingsScreenState();
}

class _KeybarSettingsScreenState extends State<KeybarSettingsScreen> {
  late List<KeyConfigItem> _config;

  @override
  void initState() {
    super.initState();
    _config = List.from(widget.initial);
  }

  void _persist() {
    KeybarConfig.save(_config);
    widget.onChanged(_config);
  }

  void _toggle(int i) {
    setState(() => _config[i] = KeyConfigItem(_config[i].id, !_config[i].visible));
    _persist();
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _config.length) return;
    setState(() {
      final tmp = _config[i];
      _config[i] = _config[j];
      _config[j] = tmp;
    });
    _persist();
  }

  Future<void> _reset() async {
    await KeybarConfig.reset();
    setState(() => _config = List.from(KeyCatalog.defaultConfig));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = _config.where((e) => e.visible).length;
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Configurar teclado', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restore, color: Colors.amberAccent, size: 18),
            label: const Text('Restaurar', style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              '$visibleCount teclas visibles · activa/desactiva con el interruptor, ordena con ↑↓',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _config.length,
              itemBuilder: (ctx, i) {
                final item = _config[i];
                final def = KeyCatalog.byId(item.id);
                if (def == null) return const SizedBox.shrink();
                return Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      width: 44,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.visible ? (def.accent ? const Color(0xFF2A3F5F) : const Color(0xFF333333)) : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        def.label,
                        style: TextStyle(
                          color: item.visible ? (def.accent ? Colors.lightBlueAccent : Colors.greenAccent) : Colors.white24,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      _describe(item.id),
                      style: TextStyle(color: item.visible ? Colors.white : Colors.white38, fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white54),
                          visualDensity: VisualDensity.compact,
                          onPressed: i > 0 ? () => _move(i, -1) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                          visualDensity: VisualDensity.compact,
                          onPressed: i < _config.length - 1 ? () => _move(i, 1) : null,
                        ),
                        Switch(
                          value: item.visible,
                          activeThumbColor: Colors.greenAccent,
                          onChanged: (_) => _toggle(i),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _describe(String id) {
    if (id.startsWith('ctrl') && id.length > 4) return 'Control + ${id.substring(4).toUpperCase()}';
    if (id.startsWith('f') && int.tryParse(id.substring(1)) != null) return 'Tecla de función ${id.toUpperCase()}';
    const names = {
      'esc': 'Escape', 'tab': 'Tabulador', 'ctrl': 'Ctrl (modificador)',
      'up': 'Flecha arriba', 'down': 'Flecha abajo', 'left': 'Flecha izquierda', 'right': 'Flecha derecha',
      'home': 'Inicio', 'end': 'Fin', 'pgup': 'Página arriba', 'pgdn': 'Página abajo',
      'del': 'Suprimir', 'ins': 'Insertar',
      'pipe': 'Barra vertical', 'slash': 'Barra', 'dash': 'Guion', 'tilde': 'Virgulilla',
      'backslash': 'Contrabarra', 'star': 'Asterisco', 'amp': 'Ampersand', 'dollar': 'Dólar',
      'hash': 'Almohadilla', 'grave': 'Acento grave',
      'fontInc': 'Aumentar fuente', 'fontDec': 'Reducir fuente',
    };
    return names[id] ?? id;
  }
}
