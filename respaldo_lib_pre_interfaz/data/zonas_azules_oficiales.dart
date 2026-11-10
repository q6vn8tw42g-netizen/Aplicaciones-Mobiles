/// Catálogo histórico de tramos regulados, NO plazas individuales ni estados en vivo.
/// Revisar vigencia y señalización actual antes de uso en vía pública.
class TramoZonaAzul {
  final String calle;
  final String desde;
  final String hasta;
  final String localidad;
  const TramoZonaAzul(this.calle, this.desde, this.hasta, this.localidad);

  String get titulo => '$calle · $desde — $hasta';
  String get busqueda => '$calle entre $desde y $hasta, $localidad, Carchi, Ecuador';
}

abstract final class CatalogoZonasAzules {
  static const tulcan = <TramoZonaAzul>[
    TramoZonaAzul('Avenida Brasil', 'Avenida Coral', 'Avenida Manabí', 'Tulcán'),
    TramoZonaAzul('Venezuela', 'Manabí', 'Coral', 'Tulcán'),
    TramoZonaAzul('Venezuela', 'Avenida Coral', 'Sucre', 'Tulcán'),
    TramoZonaAzul('Avenida Manabí', 'Panamá', 'Venezuela', 'Tulcán'),
    TramoZonaAzul('Avenida Coral', 'Venezuela', 'Panamá', 'Tulcán'),
    TramoZonaAzul('Calderón', 'Venezuela', 'Avenida Brasil', 'Tulcán'),
    TramoZonaAzul('Bolivia', 'Avenida Coral', 'Avenida Manabí', 'Tulcán'),
    TramoZonaAzul('Panamá', 'Manabí', 'Sucre', 'Tulcán'),
    TramoZonaAzul('Panamá', 'Sucre', 'Olmedo', 'Tulcán'),
    TramoZonaAzul('Roberto Sierra', 'Rafael Arellano', 'Bolívar', 'Tulcán'),
    TramoZonaAzul('Chimborazo', 'Sucre', 'Colón', 'Tulcán'),
    TramoZonaAzul('García Moreno', 'Rafael Arellano', 'Bolívar', 'Tulcán'),
    TramoZonaAzul('Boyacá', 'Rafael Arellano', 'Bolívar', 'Tulcán'),
    TramoZonaAzul('Boyacá', 'Bolívar', 'Sucre', 'Tulcán'),
    TramoZonaAzul('Boyacá', 'Sucre', 'Olmedo', 'Tulcán'),
    TramoZonaAzul('Junín', 'Rafael Arellano', 'Colón', 'Tulcán'),
    TramoZonaAzul('Ayacucho', 'Rafael Arellano', 'Colón', 'Tulcán'),
    TramoZonaAzul('10 de Agosto', 'Rafael Arellano', 'Colón', 'Tulcán'),
    TramoZonaAzul('Pichincha', 'Rafael Arellano', 'Colón', 'Tulcán'),
    TramoZonaAzul('Rocafuerte', 'Olmedo', 'Bolívar', 'Tulcán'),
    TramoZonaAzul('Olmedo', 'Rocafuerte', 'Chimborazo', 'Tulcán'),
    TramoZonaAzul('Sucre', 'Pichincha', 'Venezuela', 'Tulcán'),
  ];

  static const montufar = <TramoZonaAzul>[
    TramoZonaAzul('Pichincha', 'Montúfar', 'Bolívar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Pichincha', 'Bolívar', 'Los Andes', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Sebastián Aldás', 'Pichincha', 'Los Andes', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Los Andes', 'Pichincha', 'Calderón', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Calderón', 'Bolívar', 'Los Andes', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Los Andes', 'Calderón', 'Sucre', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Sucre', 'Rocafuerte', 'Montúfar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Sucre', 'Montúfar', 'Bolívar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Sucre', 'Bolívar', 'Los Andes', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Montúfar', 'Sucre', 'Colón', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Bolívar', 'Sucre', 'Colón', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Los Andes', 'Sucre', 'Colón', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Colón', 'Rocafuerte', 'Montúfar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Colón', 'Montúfar', 'Bolívar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('García Moreno', 'Rocafuerte', 'Montúfar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('García Moreno', 'Montúfar', 'Bolívar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Los Andes', 'Colón', 'García Moreno', 'San Gabriel, Montúfar'),
    TramoZonaAzul('García Moreno', 'Bolívar', 'Los Andes', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Olmedo', 'Rocafuerte', 'Montúfar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Olmedo', 'Montúfar', 'Bolívar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Los Andes', 'García Moreno', 'Olmedo', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Olmedo', 'Bolívar', 'Los Andes', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Olmedo', 'Los Andes', 'Río San Gabriel', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Montalvo', 'Rocafuerte', 'Montúfar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Montalvo', 'Montúfar', 'Bolívar', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Montalvo', 'Bolívar', 'Los Andes', 'San Gabriel, Montúfar'),
    TramoZonaAzul('Los Andes', 'Olmedo', 'Montalvo', 'San Gabriel, Montúfar'),
  ];
}
