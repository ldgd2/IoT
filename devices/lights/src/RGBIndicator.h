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
        STATE_TIMEOUT,
        STATE_RF_ERROR
    };

    RGBIndicator() : _strip(NEOPIXEL_COUNT, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800),
                     _state(STATE_IDLE), _startMs(0), _lastWaveMs(0), _lastAnnounceMs(0), _statusStartMs(0), _hue(0) {}

    void init() {
        _strip.begin();
        _strip.setBrightness(130); // Brillo elegante y potente sin cegar
        _strip.clear();
        _strip.show();
    }

    void showRfError() {
        if (_state != STATE_RF_ERROR) {
            _state = STATE_RF_ERROR;
            _strip.setBrightness(130);
            _strip.setPixelColor(0, _strip.Color(255, 0, 0)); // Rojo mantenido / fijo por error de RF
            _strip.show();
        }
    }

    void startPairing() {
        _state = STATE_PAIRING;
        _startMs = millis();
        _lastWaveMs = millis();
        _lastAnnounceMs = millis();
        _hue = 0;
    }

    void onPacketReceived() {
        // Si recibimos un paquete del master mientras estamos en modo vinculación o en reposo,
        // significa que el master nos detectó y nos respondió. ¡Vinculación Exitosa!
        if (_state == STATE_PAIRING || _state == STATE_IDLE) {
            _state = STATE_SUCCESS;
            _statusStartMs = millis();
            _lastWaveMs = millis();
            _strip.setBrightness(130);
            _strip.setPixelColor(0, _strip.Color(0, 255, 0)); // Verde brillante inicial
            _strip.show();
        }
    }

    void update() {
        unsigned long now = millis();

        switch (_state) {
            case STATE_IDLE:
            case STATE_RF_ERROR:
                // En error de radiofrecuencia (rojo mantenido) o en reposo, no animar
                break;

            case STATE_PAIRING:
                // 1. Verificar timeout de 50 segundos (Igualado con la ventana del traductor)
                if (now - _startMs >= 50000UL) {
                    _state = STATE_TIMEOUT;
                    _statusStartMs = now;
                    _lastWaveMs = now;
                    _strip.setBrightness(130);
                    _strip.setPixelColor(0, _strip.Color(255, 0, 0)); // Rojo brillante inicial
                    _strip.show();
                    break;
                }

                // 2. Animación "Ola de Colores" fluida y visible (arcoíris continuo ~60 FPS)
                if (now - _lastWaveMs >= 16UL) {
                    _lastWaveMs = now;
                    _hue += 600; // Avanza rápidamente por toda la rueda de color (0 a 65535) en ~1.8s

                    // Pulsaciones suaves (breathing): el brillo oscila suavemente entre 140 y 255 en ciclos de 2s
                    // Al mantener mínimo 140, los colores oscuros como azul, violeta y rosado se ven espectaculares y brillantes
                    uint32_t cycle = now % 2000;
                    uint8_t val;
                    if (cycle < 1000) {
                        val = 140 + (cycle * 115) / 1000;
                    } else {
                        val = 255 - ((cycle - 1000) * 115) / 1000;
                    }

                    _strip.setPixelColor(0, _strip.ColorHSV(_hue, 255, val));
                    _strip.show();
                }
                break;

            case STATE_SUCCESS: {
                // Si se vincula: muestra color verde y desaparece lentamente (3 segundos)
                unsigned long elapsed = now - _statusStartMs;
                if (elapsed >= 3000UL) {
                    _strip.clear();
                    _strip.show();
                    _state = STATE_IDLE;
                } else if (now - _lastWaveMs >= 30UL) {
                    _lastWaveMs = now;
                    uint8_t green = 255 - (uint8_t)((elapsed * 255UL) / 3000UL);
                    _strip.setPixelColor(0, _strip.Color(0, green, 0));
                    _strip.show();
                }
                break;
            }

            case STATE_TIMEOUT: {
                // Si no se conecta: muestra rojo y desaparece lentamente (3 segundos)
                unsigned long elapsed = now - _statusStartMs;
                if (elapsed >= 3000UL) {
                    _strip.clear();
                    _strip.show();
                    _state = STATE_IDLE;
                } else if (now - _lastWaveMs >= 30UL) {
                    _lastWaveMs = now;
                    uint8_t red = 255 - (uint8_t)((elapsed * 255UL) / 3000UL);
                    _strip.setPixelColor(0, _strip.Color(red, 0, 0));
                    _strip.show();
                }
                break;
            }
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
    void showRfError() {}
    void update() {}
};
#endif

#endif // RGB_INDICATOR_H
