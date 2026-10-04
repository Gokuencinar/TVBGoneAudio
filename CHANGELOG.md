# Changelog — TVBGoneAudio

**TVBGoneAudio** es una aplicación para iOS que permite enviar señales infrarrojas a televisores y otros equipos compatibles mediante un adaptador IR conectado a la salida de audio.

Historial de cambios de **TVBGoneAudio**.

**Compatibilidad:** iOS 16.0 o posterior. Las IPA publicadas están destinadas principalmente a instalación mediante TrollStore.

> Nota: las versiones recientes están respaldadas por Releases de GitHub. Las etapas anteriores se reconstruyen a partir de la documentación histórica y del historial del repositorio.

## 6.2 — 2026-10-04

### Marcas A–Z estilo Mi Remote

- La lista de marcas de **Mando** ahora está agrupada por letra inicial.
- Añadido un índice lateral A–Z para saltar directamente a la inicial deseada, al estilo Mi Remote.
- Solo aparecen en el índice las letras que realmente tienen marcas disponibles; `#` agrupa nombres que no empiezan por A–Z.
- Las marcas con acentos se clasifican por su letra equivalente para mantener una navegación natural.
- El buscador de marcas se mantiene: al escribir, el índice se oculta y la lista muestra únicamente las coincidencias.
- Se conserva sin cambios el asistente tipo → marca → prueba Sí/No y el motor físico de transmisión IR.

## 6.1 — 2026-10-04

### Asistente Mi Remote y rendimiento

- Rehecho el alta de mandos para seguir un flujo tipo Mi Remote:
  - elegir tipo de dispositivo;
  - abrir una lista dedicada de marcas con búsqueda;
  - seleccionar la marca;
  - probar encendido/apagado;
  - responder **Sí funciona** / **No funciona**;
  - si falla, probar otro código POWER del mismo perfil y después el siguiente perfil;
  - si funciona, validar otras funciones representativas del aparato;
  - guardar automáticamente el mando completo al terminar.
- Las pruebas secundarias cambian según el dispositivo: volumen/entrada en TV y audio, temperatura/modo en aire, canal/OK en decodificadores, velocidad/oscilación en ventiladores, Play/Eject en DVD, etc.
- Cámara empieza por disparador/zoom cuando el perfil no tiene un concepto de POWER útil.
- La búsqueda profunda ya no puede mezclar perfiles de otras categorías.
- Eliminado el fallback antiguo que podía tratar los primeros botones de un archivo como si fueran POWER.
- Mejor reconocimiento de nombres Flipper habituales como `Ch_next`, `Ch_prev` y `Vol_dn`.
- Importante mejora de fluidez en **Mando**:
  - los controles que solo transmiten ya no observan todos los cambios internos de `IRTransmitter`;
  - se evita redibujar toda la superficie varias veces por cada pulsación;
  - el matcher de nombres se precalcula una sola vez por mando;
  - la recencia deja de reserializar todas las señales IR al pulsar cada botón;
  - los cambios de biblioteca observan conteos en lugar de comparar arrays completos de waveforms;
  - los listados online largos usan carga lazy;
  - los grandes índices GitHub se decodifican fuera del hilo principal y se cachean ya procesados.
- El motor físico `IRTransmitter` y la generación L/R en antifase permanecen sin cambios.

## 6.0 — 2026-10-04

### Mando tipo Mi Remote

- Corregido el icono ausente de la pestaña **Mando** en iOS 16 usando `av.remote.fill`, disponible en SF Symbols 4.
- Mando pasa a funcionar como una biblioteca de dispositivos, con:
  - botón `+` para añadir equipo;
  - selector visual por tipo de dispositivo;
  - navegación por marcas y modelos/mandos disponibles;
  - prueba de señales antes de guardar;
  - guardado del mando completo y selección automática al terminar;
  - estantería de mandos en la pantalla principal;
  - **Favoritos y Recientes** persistentes.
- Se conserva ahora la metadata disponible del mando online: marca, modelo, fuente y ruta de origen.
- Nuevos tipos de dispositivo en Mando, Biblioteca online y Aprender:
  - TV;
  - aire acondicionado;
  - decodificador / set-top box;
  - ventilador;
  - streaming / Smart Box;
  - DVD / Blu-ray;
  - proyector;
  - receptor A/V;
  - cámara;
  - barra de sonido.
- Nuevas superficies de control adaptadas al tipo de aparato:
  - decodificador/streaming con D-pad, Home, Guide, Info, canales, volumen, multimedia y teclado numérico;
  - ventilador con velocidad, modo, oscilación, temporizador y luz;
  - DVD/Blu-ray con Eject, navegación, multimedia y teclado;
  - A/V/soundbar con fuente, volumen, mute, modos y navegación cuando existe;
  - cámara con disparador, zoom y navegación cuando existe.
- El reconocimiento de nombres de botones entiende ahora también `Eject`, `Speed +/-`, `Light`, `Shutter`, `Zoom +/-`, `Guide` e `Info` y conserva el resto en **Más controles**.
- La biblioteca sigue combinando Flipper-IRDB, Flipper IRDB oficial, IRDB Web e importación HTTPS; no depende de una base propietaria.
- El parser CSV IRDB acepta además perfiles Samsung y Pioneer compatibles con el codificador existente.
- `Control` y `Códigos` mantienen intencionadamente su barrido POWER offline en TV, aire y proyector; las categorías nuevas se añaden mediante mando online, importación o aprendizaje.
- Los datos de mandos 5.9 siguen siendo compatibles: favoritos, recencia y metadata nueva se cargan con valores por defecto cuando no existen.
- El motor físico `IRTransmitter` no se ha modificado.

## 5.9 — 2026-10-04

### Novedades y cambios

- Nueva pestaña **Mando**, inspirada en la experiencia de Mi Remote / Uni TV Remote.
- Se mantienen cinco pestañas principales para evitar que iOS convierta la sexta en «Más»:
  - Control;
  - Códigos;
  - Mando;
  - Aprender;
  - Ajustes/Info.
- La antigua pestaña **Mis equipos** queda integrada dentro de Mando como biblioteca de equipos, mandos e historial.
- Nuevo selector unificado para alternar entre:
  - mandos completos importados/aprendidos;
  - equipos con código POWER guardado.
- Los mandos completos organizan automáticamente por función todas las señales compatibles, sin alterar sus códigos IR.
- Diseño específico para TV con:
  - POWER;
  - Input/Source;
  - Mute;
  - volumen y canales;
  - D-pad con OK;
  - Atrás, Inicio y Menú;
  - reproducción multimedia;
  - teclado numérico cuando el mando lo incluye.
- Diseño específico para aire acondicionado con:
  - POWER;
  - temperatura + / −;
  - Mode, Fan, Swing;
  - Cool, Heat, Dry, Sleep, Timer y Auto cuando están disponibles.
- Diseño específico para proyector con POWER, Source, Mute, D-pad, Menú, Atrás y Freeze.
- Sección **Más controles** para conservar cualquier botón compatible que no se reconozca automáticamente por nombre.
- Añadido **POWER rápido** para usar los equipos guardados sin cambiar de mando completo.
- El mando seleccionado se recuerda entre aperturas.
- El mapeo reconoce variantes habituales de nombres en inglés/español y formatos Flipper (`VOL_UP`, `Channel -`, `Source`, `Return`, etc.).
- Se evita confundir señales específicas como `Power On`, `Power Off`, `Input HDMI1` o `Backward` con controles genéricos; permanecen accesibles en Más controles si no representan un toggle genérico.
- La distribución TV se adapta al ancho disponible mediante una variante compacta para iPhone.
- La pestaña **Diagnóstico** pasa a llamarse **Ajustes/Info**; mantiene diagnóstico técnico, apariencia, backups y actualizaciones.
- Se mantiene intacto el motor físico de generación/transmisión IR.

## 5.8 — 2026-10-04

### Novedades y cambios

- Nuevo modo visual **Cyberpunk / IR Ops** activado por defecto:
  - negro OLED real;
  - paneles técnicos casi negros;
  - acentos cian y magenta;
  - rojo reservado para transmisión y POWER;
  - verde para estados correctos y ámbar para avisos;
  - bordes neon y rejilla HUD sutil.
- Nuevo HUD en Control con estado del enlace IR, categoría, modo de transmisión y telemetría más clara.
- Nuevas barras de progreso neon para barridos universal y por marca.
- Botones principales de transmisión con estilo cyberpunk y feedback visual más claro.
- Diagnóstico, Aprender, backups, actualizaciones, mandos y analizador IR usan ahora el mismo sistema de paneles OLED.
- Añadido selector en Diagnóstico para activar/desactivar la apariencia Cyberpunk.
- Nueva opción **Mantener pantalla activa** durante barridos y capturas para evitar que el iPhone se bloquee a mitad de una prueba.
- Mejoras de accesibilidad:
  - animaciones respetan Reducir movimiento;
  - el tema respeta Reducir transparencia y Aumentar contraste;
  - botones A–Z aumentados a 44×44 pt;
  - soporte para marcas que empiezan por números/símbolos mediante `#`;
  - etiquetas VoiceOver en varios botones solo-icono.
- El barrido por marca ahora registra correctamente el código confirmado en el historial de aciertos.
- Corregido un fallo de estado por el que probar manualmente un código o una portadora durante un barrido podía detener el audio dejando la interfaz marcada como «barrido activo».
- Mejorada la biblioteca online:
  - se descartan resultados de carga de marcas obsoletos cuando cambia rápidamente categoría/fuente;
  - caché en memoria limitada para evitar crecimiento indefinido.
- El centro de actualizaciones muestra ahora las notas de la nueva versión antes de enviarla a TrollStore.
- Las capturas de aprendizaje eliminan siempre el archivo temporal, incluso cuando el análisis termina pronto por error o señal inválida.
- El motor físico de generación de señal IR no cambia.

## 5.7 — 2026-09-25

### Novedades y cambios

- Añadido **barrido automático por marca** en el selector local de Códigos.
- Disponible para:
  - televisores;
  - aires acondicionados;
  - proyectores.
- El botón aparece cuando la marca seleccionada dispone de **2 o más códigos/mandos**.
- El barrido recorre exclusivamente los códigos de la marca seleccionada, sin probar el resto de la base.
- Se mantienen las pruebas manuales uno a uno.
- Selector de velocidad:
  - Rápido;
  - Identificar.
- Controles durante el barrido:
  - progreso;
  - pausa/reanudar;
  - anterior;
  - siguiente;
  - «FUNCIONÓ».
- Al pulsar «FUNCIONÓ» se conservan los candidatos recientes y puede guardarse el mando/equipo.
- El motor físico de transmisión IR no cambia; la nueva función reutiliza el escáner existente con un subconjunto de códigos.

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
