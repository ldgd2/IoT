#ifndef RELAY_H
#define RELAY_H

/**
 * @file Relay.h
 * @brief Control de un solo relay físico — sub-módulo de actuators/relay/.
 *
 * Encapsula un único canal de relay. Implementa IActuator.
 * Para múltiples relays usar RelayBank.
 *
 * Soporte de lógica activa-baja (active LOW):
 *   Muchos módulos de relay de bajo costo invierten la lógica:
 *   HIGH = apagado, LOW = encendido. Usar activeLow=true para estos.
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "../IActuator.h"
#include <Arduino.h>

class Relay : public IActuator {
public:
    Relay();

    /**
     * @brief Inicializa el relay.
     * @param pin        GPIO del relay
     * @param activeLow  true si el módulo usa lógica invertida (LOW = ON)
     *                   false para lógica normal (HIGH = ON)
     */
    void init(uint8_t pin, bool activeLow = false);

    // ── IActuator ────────────────────────────────────────────────────────────
    void setState(bool on)    override;
    bool getState() const     override;
    void toggle()             override;

    // ── Acceso extra ─────────────────────────────────────────────────────────
    uint8_t getPin() const { return _pin; }

private:
    uint8_t _pin;
    bool    _state;
    bool    _activeLow;

    // Traduce el estado lógico (true=ON) al nivel físico de GPIO
    inline int _physicalLevel(bool on) const {
        return (_activeLow ? !on : on) ? HIGH : LOW;
    }
};

#endif // RELAY_H
