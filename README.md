# TVBGoneAudio

Aplicación iOS para usar un adaptador IR conectado como salida de audio estéreo (incluidos adaptadores Lightning que se presentan al sistema como audio) con comportamiento tipo **TV-B-Gone**.

## Objetivo de hardware

- iPhone XS
- iOS 16.3
- TrollStore 2
- Emisor IR que funcione mediante audio estéreo diferencial
- Volumen multimedia alto/máximo

## Cómo funciona

La señal IR se sintetiza en PCM estéreo. Durante cada tramo `MARK`, el canal derecho es la fase inversa del izquierdo. La frecuencia de audio es la mitad de la portadora IR deseada; con un adaptador de dos LED IR en antiparalelo/rectificación, ambos semiciclos producen la portadora completa.

La app solicita 96 kHz al sistema para representar mejor las portadoras altas de la base TV-B-Gone. Si el adaptador Lightning solo negocia 48 kHz, las portadoras que excedan el ancho de banda se limitan al máximo reproducible.

Los códigos cuya fuente original usa salida IR no modulada (`carrier = 0`) se transmiten a 38 kHz, ya que una ruta de audio acoplada en AC no puede mantener una componente DC útil.

## Base de códigos

El workflow descarga `WORLD_IR_CODES.h` de `shirriff/Arduino-TV-B-Gone` y lo convierte a Swift antes de compilar:

- 137 códigos en la lista NA
- 145 códigos en la lista EU

La región **Europa** está seleccionada por defecto.

## Compilar una IPA para TrollStore

La acción de GitHub `Build unsigned IPA`:

1. descarga y convierte la base TV-B-Gone;
2. genera el proyecto con XcodeGen;
3. compila para `iphoneos` con `CODE_SIGNING_ALLOWED=NO`;
4. empaqueta `Payload/TVBGoneAudio.app` como `TVBGoneAudio.ipa`;
5. sube la IPA como artefacto.

TrollStore puede instalar IPAs y volver a firmar la aplicación al instalarla.

## Prueba inicial

1. Conecta el emisor IR Lightning.
2. Sube el volumen multimedia al máximo.
3. Abre la app.
4. Comprueba que la ruta mostrada corresponde al accesorio y que indica dos canales si el dispositivo los expone.
5. Pulsa **Probar portadora 38 kHz durante 1 s**.
6. Si el hardware responde correctamente, usa **APAGAR TELEVISORES** apuntando al televisor durante toda la secuencia.

## Licencia y atribución

El código de esta aplicación es original de este proyecto. La base de códigos se deriva del proyecto Arduino-TV-B-Gone, que atribuye los datos/firmware originales a Mitch Altman y Limor Fried y los distribuye bajo Creative Commons Attribution-ShareAlike 2.5. Consulta `THIRD_PARTY.md`.
