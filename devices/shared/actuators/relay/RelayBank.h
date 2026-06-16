#ifndef RELAY_BANK_H
#define RELAY_BANK_H

/**
 * @file RelayBank.h
 * @brief Banco de N relays con inicialización dinámica — sub-módulo de actuators/relay/.
 *
 * Soporta de 1 a MAX_RELAYS relays. En la inicialización el dispositivo
 * declara CUÁNTOS relays necesita y en QUÉ pines. Solo se configuran esos.
 *
 * Ejemplo de uso:
 * ─────────────────────────────────────────────────────────────────────────────
 * // Dispositivo con 1 relay:
 * uint8_t pins[] = { RELAY_PIN };
 * RelayBank relays;
 * relays.init(1, pins);
 *
 * // Dispositivo con 4 relays (tablero de enchufes):
 * uint8_t pins[] = { 5, 6, 7, 8 };
 * RelayBank relays;
 * relays.init(4, pins);
 *
 * // Dispositivo con 8 relays en módulo active-LOW:
 * uint8_t pins[] = { 2, 3, 4, 5, 14, 16, 17, 18 };
 * RelayBank relays;
 * relays.init(8, pins, true);  // activeLow=true
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Solo los N relays especificados se inicializan. La memoria (arrays internos)
 * se reserva compile-time hasta MAX_RELAYS pero solo los N activos consumen pines.
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "../IActuator.h"
#include "Relay.h"
#include <stdint.h>

class RelayBank {
public:
    // Límite compile-time. No cuesta memoria extra si solo se usan 2 de 16.
    static const uint8_t MAX_RELAYS = 16;

    RelayBank();

    /**
     * @brief Inicializa el banco con N relays en los pines dados.
     *
     * Solo se configuran los N primeros pines del array. El resto se ignora.
     * Llamar una sola vez en setup(). No re-llamar en runtime.
     *
     * @param count      Número de relays a activar (1 a MAX_RELAYS)
     * @param pins       Array con los GPIO de cada relay (tamaño mínimo = count)
     * @param activeLow  true si el módulo usa lógica invertida (LOW = ON)
     */
    void init(uint8_t count, const uint8_t* pins, bool activeLow = false);

    // ── Operaciones por relay individual ────────────────────────────────────

    /**
     * @brief Establece el estado de un relay específico.
     * @param index  Índice del relay (0-based)
     * @param on     true = encendido, false = apagado
     */
    void setState(uint8_t index, bool on);

    /**
     * @brief Retorna el estado de un relay específico.
     * @param index  Índice del relay (0-based)
     * @return true si el relay está encendido; false si index inválido
     */
    bool getState(uint8_t index) const;

    /**
     * @brief Invierte el estado de un relay específico.
     * @param index  Índice del relay (0-based)
     */
    void toggle(uint8_t index);

    // ── Operaciones globales ─────────────────────────────────────────────────

    /**
     * @brief Establece el mismo estado en TODOS los relays del banco.
     * @param on  true = todos encendidos, false = todos apagados
     */
    void setAll(bool on);

    /**
     * @brief Invierte el estado de TODOS los relays del banco.
     */
    void toggleAll();

    /**
     * @brief Aplica un patrón de estados desde un bitmask.
     * Bit 0 = relay 0, bit 1 = relay 1, ..., bit N-1 = relay N-1.
     * @param mask  Bitmask de estados (1=ON, 0=OFF)
     */
    void setMask(uint16_t mask);

    /**
     * @brief Retorna el bitmask actual de estados de todos los relays.
     * Bit 0 = relay 0, bit N-1 = relay N-1.
     * @return uint16_t con los estados actuales
     */
    uint16_t getMask() const;

    // ── Info ─────────────────────────────────────────────────────────────────

    /** @brief Número de relays inicializados. */
    uint8_t getCount() const { return _count; }

    /** @brief Verifica si un índice es válido. */
    bool isValid(uint8_t index) const { return index < _count; }

    /**
     * @brief Acceso directo a un relay individual como IActuator*.
     * Permite pasar un relay específico a funciones que aceptan IActuator*.
     * @return nullptr si el índice es inválido
     */
    IActuator* get(uint8_t index);

private:
    uint8_t _count;
    Relay   _relays[MAX_RELAYS];
};

#endif // RELAY_BANK_H
