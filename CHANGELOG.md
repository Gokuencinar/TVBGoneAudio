# Changelog — TVBGoneAudio

Historial de cambios de **TVBGoneAudio**.

**Compatibilidad:** iOS 16.0 o posterior. Las IPA publicadas están destinadas principalmente a instalación mediante TrollStore.

> Nota: las versiones recientes están respaldadas por Releases de GitHub. Las etapas anteriores se reconstruyen a partir de la documentación histórica y del historial del repositorio.

## 5.6 — Build 1021 — 2026-09-23

### Novedades y cambios

- Añadido selector de transmisión **Compatible / Máximo alcance**.
- El modo Máximo alcance aumenta la energía media de la portadora manteniendo el pico digital dentro de ±1.
- Cada ráfaga IR comienza en el pico de la senoide en lugar del cruce por cero.
- Las portadoras de hasta 40 kHz dejan de descartarse innecesariamente con salidas de 44,1 kHz cuando siguen por debajo de Nyquist.
- Diagnóstico mejorado:
  - muestra el volumen multimedia real;
  - avisa cuando el accesorio negocia una frecuencia inferior a 48 kHz;
  - explica la posible pérdida de alcance cerca de 40 kHz.
- La prueba de portadora ahora incluye **36, 37, 38, 39 y 40 kHz** para facilitar la calibración del dongle.
- Se mantiene el modo Compatible para priorizar fidelidad y compatibilidad con accesorios sensibles.
- Nombre visible unificado como **TVBGoneAudio** en la app, el actualizador, las releases y el archivo IPA.

## 5.5 — Build 1017 — 2026-09-22

### Novedades y cambios

- Rediseño final del navegador local en modo **Lista**.
- Eliminado el bloque de códigos duplicado que aparecía debajo de «Explorar marcas».
- En modo Lista, la navegación ocurre dentro de un único panel:
  - letra;
  - marca;
  - códigos de esa marca.
- Botón para volver desde los códigos a la lista de marcas.
- Los detalles y acciones **PROBAR / GUARDAR** permanecen debajo del código seleccionado.
- El modo **Ruleta** conserva la navegación clásica.

## 5.4 — Build 1016 — 2026-09-22

### Novedades y cambios

- Separación inicial del comportamiento entre **Lista** y **Ruleta**.
- En Lista se muestran códigos en formato de lista.
- En Ruleta se mantiene el picker de rueda.
- Integración adicional del selector de códigos con el tema OLED.

## 5.3 — Build 1015 — 2026-09-22

### Novedades y cambios

- El índice A–Z muestra únicamente letras que realmente contienen marcas.
- Añadido selector persistente **Lista / Ruleta**.
- La preferencia de navegación se recuerda entre aperturas.
- Aplicado el mismo comportamiento a la biblioteca IR online y al selector local.
- Mejoras OLED:
  - barras de navegación y pestañas en negro puro;
  - controles segmentados adaptados;
  - campos de texto OLED;
  - superficies y bordes más discretos.

## 5.2 — Build 1014 — 2026-09-22

### Novedades y cambios

- Navegación A–Z añadida al selector local de **Códigos**.
- Compatible con los filtros:
  - Todos;
  - Universal;
  - TV-B-Gone;
  - IRDB.
- La selección de una marca filtra los códigos disponibles.
- TV-B-Gone usa el nombre disponible cuando no existe una marca real en los metadatos.

## 5.1 — Build 1013 — 2026-09-22

### Novedades y cambios

- Navegador de marcas A–Z para la biblioteca IR online.
- Índice de marcas generado dinámicamente desde las bases online.
- Conservada la ruleta de marcas.
- Nuevo **modo OLED**:
  - negro puro;
  - superficies oscuras;
  - acento rojo;
  - opción para activarlo/desactivarlo desde Diagnóstico.

## 5.0 — Build 1012 — 2026-09-22

### Novedades y cambios

Gran actualización de experiencia de uso.

- Estado del emisor visible desde la pantalla principal.
- Visualización de ruta de audio, canales, frecuencia y volumen.
- Animación de ondas IR al transmitir.
- Feedback háptico en acciones importantes.
- Barrido mejorado con:
  - código actual;
  - portadora;
  - porcentaje;
  - tiempo restante aproximado.
- Historial persistente de códigos que funcionaron.
- Rediseño completo de **Mis equipos**.
- Copia de seguridad completa en JSON.
- Restauración de:
  - equipos;
  - señales aprendidas;
  - mandos;
  - historial.
- Nuevo onboarding visual.
- Mejor diagnóstico del accesorio y del volumen.
- Se mantiene intacto el motor de transmisión IR ya validado.

## 4.2 — Build 1010 — 2026-09-22

### Novedades y cambios

- Eliminada la función de cambio dinámico de icono.
- Retirados los iconos alternativos.
- Eliminado el uso de `setAlternateIconName`.
- Cambio realizado por incompatibilidad práctica con instalaciones mediante TrollStore que producía `OSStatus -54`.
- La app vuelve a utilizar un único icono estable.

## 4.1 — Build 1009 — 2026-09-22

### Novedades y cambios

- Añadido actualizador integrado.
- Comprobación automática de nuevas versiones al abrir la app.
- Botón **Buscar actualización** en Diagnóstico.
- Instalación entregada a TrollStore mediante su URL Scheme.
- GitHub Actions publica automáticamente una Release con la IPA.
- Comparación de versión y build para detectar actualizaciones.

## 4.0 — Build 10

### Novedades y cambios

- Biblioteca IR online con búsqueda por marca y modelo.
- Fuentes:
  - Flipper-IRDB comunitaria;
  - catálogo oficial de Flipper Devices;
  - IRDB.
- Búsqueda profunda para marcas y modelos poco comunes.
- Importación directa desde URL HTTPS de archivos `.ir` y CSV IRDB.
- Prueba de botones antes de guardar.
- Guardado de mandos completos para uso offline.
- Comprobador de compatibilidad del accesorio.
- «Aprender» bloquea capturas cuando iOS solo detecta el micrófono interno.
- Se añadieron iconos alternativos y selector de icono; esta función fue retirada posteriormente en 4.2.
- Conservado el motor IR y el orden de barrido conocido.

## 3.1 — Build 9

### Novedades y cambios

- Corregido el icono de la pestaña Aprender en iOS 16 usando `mic.fill`.
- Nuevo icono Power + ondas IR.
- Añadido modo de portadora **Auto**.
- Inferencia de portadora según protocolo:
  - RC5 / RC6 → 36 kHz;
  - NEC / Samsung / JVC / RCA / Kaseikyo → 38 kHz;
  - Sony SIRC / Pioneer → 40 kHz;
  - desconocido → 38 kHz.
- Diagnóstico ampliado para explicar volumen, balance y Audio mono.

## 3.0 — Build 8 — «IR Studio»

### Novedades y cambios

- Flujo avanzado de aprendizaje IR.
- Captura normal y captura validada x3.
- Cálculo de consistencia entre capturas.
- Generación de waveform RAW de consenso.
- Visualizador MARK/SPACE.
- Reconocimiento heurístico de:
  - NEC / NEC Extended;
  - Samsung32;
  - JVC;
  - Sony SIRC12/15/20;
  - Kaseikyo / Panasonic;
  - RCA;
  - Pioneer;
  - RC5 / RC6 probables.
- Comparación de señales aprendidas contra la base incluida.
- Importación y exportación Flipper `.ir`.
- Mandos personalizados multibotón.
- Aprendizaje guiado para TV, aire acondicionado y proyectores.
- RAW se mantiene como fuente de verdad cuando el reconocimiento no es seguro.

## v7 — Learn IR

### Novedades y cambios

- Primera implementación del flujo de aprendizaje IR.
- Captura PCM desde una entrada de audio compatible.
- Detección de bordes y reconstrucción de timings RAW.
- Selección manual de portadora 36 / 38 / 40 / 56 kHz.
- Prueba de la señal aprendida con el transmisor existente.
- Guardado persistente de señales aprendidas.
- Se documenta que el emisor estéreo por sí solo es de salida y no puede aprender.

## v6

### Novedades y cambios

- Nueva interfaz principal con:
  - Control;
  - Códigos;
  - Mis equipos;
  - Diagnóstico.
- Selector manual de códigos mediante ruleta.
- Búsqueda por marca, modelo, ID y fuente.
- Escaneo rápido y modo Identificar.
- Pausa, reanudar, anterior y siguiente durante barridos.
- Flujo **FUNCIONÓ** para conservar candidatos recientes.
- Equipos favoritos persistentes.
- POWER con un toque para dispositivos guardados.
- Diagnóstico de 36 / 38 / 40 kHz.
- Protocolos Flipper adicionales:
  - Kaseikyo;
  - RCA;
  - Pioneer.
- Conservado el orden de escaneo TV:
  **Universal → TV-B-Gone → Flipper-IRDB**.

## Historial temprano

### Base funcional

Antes de v6, el proyecto ya incluía la base funcional del transmisor IR por audio:

- salida estéreo con canal derecho invertido;
- adaptación a emisores IR con LEDs en oposición;
- frecuencia de audio a la mitad de la portadora IR deseada;
- reinicio de fase en cada MARK;
- solicitud de salida a 96 kHz usando siempre la frecuencia realmente negociada;
- descarte de códigos cuya portadora no puede representarse de forma segura;
- barridos independientes para:
  - TV;
  - aire acondicionado;
  - proyectores;
- integración de TV-B-Gone y Flipper-IRDB;
- requisitos de audio:
  - volumen multimedia al 100 %;
  - Audio mono desactivado;
  - balance centrado.

---

Las Releases recientes de TVBGoneAudio se generan automáticamente mediante GitHub Actions y contienen la IPA destinada a instalación/actualización mediante TrollStore.
