#ifndef RGB_INDICATOR_H
#define RGB_INDICATOR_H

/**
 * @file RGBIndicator.h — lights
 * @brief Controlador no bloqueante para el LED RGB NeoPixel (WS2812B) del YD-RP2040.
 *
 * Maneja animaciones en tiempo real y sin retardos (non-blocking) durante el modo vinculación:
 *   - Modo Vinculación (30 seg): Efecto ola de colores arcoíris fluida a 60 FPS + re-anuncio periódico.
 *   - Vinculación Exitosa: Alumbra VERDE brillante y se apaga.
 *   - Fallo / Timeout (30 seg sin respuesta): Alumbra ROJO brillante por 5 segundos y se apaga.
 */

#include <Arduino.h>
#include "colmena/ColmenaNode.h"

#if defined(IS_RP2040)
#include <Adafruit_NeoPixel.h>

#define NEOPIXEL_PIN    23      // Pin GP23 del WS2812 integrado en YD-RP2040
#define NEOPIXEL_COUNT  1

class RGBIndicator {
public:
    enum State {
        STATE_IDLE,
        STATE_PAIRING,
        STATE_SUCCESS,
        STATE_TIMEOUT
    };

    RGBIndicator() : _strip(NEOPIXEL_COUNT, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800),
                     _state(STATE_IDLE), _startMs(0), _lastWaveMs(0), _lastAnnounceMs(0), _statusStartMs(0), _hue(0) {}

    void init() {
        _strip.begin();
        _strip.setBrightness(130); // Brillo elegante y potente sin cegar
        _strip.clear();
        _strip.show();
    }

    void startPairing() {
        _state = STATE_PAIRING;
        _startMs = millis();
        _lastWaveMs = millis();
        _lastAnnounceMs = millis();
        _hue = 0;
    }

    void onPacketReceived() {
        // Si recibimos cualquier paquete válido del master mientras estamos en modo vinculación,
        // significa que el master nos detectó y nos respondió. ¡Vinculación Exitosa!
        if (_state == STATE_PAIRING) {
            _state = STATE_SUCCESS;
            _statusStartMs = millis();
            _strip.setPixelColor(0, _strip.Color(0, 255, 0)); // Verde brillante
            _strip.show();
        }
    }

    void update(ColmenaNode& colmena, const char* nodeName) {
        unsigned long now = millis();

        switch (_state) {
            case STATE_IDLE:
                break;

            case STATE_PAIRING:
                // 1. Verificar timeout de 30 segundos
                if (now - _startMs >= 30000UL) {
                    _state = STATE_TIMEOUT;
                    _statusStartMs = now;
                    _strip.setPixelColor(0, _strip.Color(255, 0, 0)); // Rojo brillante
                    _strip.show();
                    break;
                }

                // 2. Re-anunciar automáticamente cada 4 segundos para asegurar que el master escuche
                if (now - _lastAnnounceMs >= 4000UL) {
                    _lastAnnounceMs = now;
                    colmena.announce(nodeName);
                }

                // 3. Animación "Ola de Colores" en tiempo real (arcoíris fluido ~60 FPS)
                if (now - _lastWaveMs >= 16UL) {
                    _lastWaveMs = now;
                    _hue += 450; // Avanza el tono por toda la rueda de color (0 a 65535)
                    _strip.setPixelColor(0, _strip.ColorHSV(_hue, 255, 255));
                    _strip.show();
                }
                break;

            case STATE_SUCCESS:
                // Mantener verde por 5 segundos y luego apagar
                if (now - _statusStartMs >= 5000UL) {
                    _strip.clear();
                    _strip.show();
                    _state = STATE_IDLE;
                }
                break;

            case STATE_TIMEOUT:
                // Mantener rojo por 5 segundos (según requerimiento) y luego apagar
                if (now - _statusStartMs >= 5000UL) {
                    _strip.clear();
                    _strip.show();
                    _state = STATE_IDLE;
                }
                break;
        }
    }

private:
    Adafruit_NeoPixel _strip;
    State             _state;
    unsigned long     _startMs;
    unsigned long     _lastWaveMs;
    unsigned long     _lastAnnounceMs;
    unsigned long     _statusStartMs;
    uint16_t          _hue;
};

#else
// Clase dummy vacía para arquitecturas que no sean YD-RP2040 (ESP8266, Arduino, etc.)
class RGBIndicator {
public:
    void init() {}
    void startPairing() {}
    void onPacketReceived() {}
    void update(ColmenaNode& colmena, const char* nodeName) {}
};
#endif

#endif // RGB_INDICATOR_H
