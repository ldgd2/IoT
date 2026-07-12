#ifndef RELAY_STATE_H
#define RELAY_STATE_H

/**
 * @file RelayState.h
 * @brief Almacenamiento bitwise de estados para Relays ultra-eficiente en memoria.
 *
 * Permite gestionar desde 1 hasta miles de relays guardando todos sus estados lógico-digitales
 * de forma comprimida en variables escaladas de 32 bits (`uint32_t`).
 * Cada relay ocupa exactamente 1 BIT de memoria RAM (p. ej. 32 relays = 4 bytes, 1024 relays = 128 bytes).
 *
 * Ejemplo de uso:
 *   RelayState<16> estados;        // 16 relays en un solo entero uint32_t
 *   estados.set(0, true);          // Enciende el relay 0 (bit 0 = 1)
 *   estados.toggle(3);             // Alterna el relay 3 (bit 3 ^ 1)
 *   uint16_t mask = estados.getMask16(); // Máscara para paquetes RF / Heartbeat
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include <stdint.h>
#include <string.h>

template <uint16_t MAX_COUNT = 32>
class RelayState {
public:
    static const uint16_t WORDS_COUNT = (MAX_COUNT + 31) / 32;

    RelayState() : _count(MAX_COUNT) {
        clearAll();
    }

    /**
     * @brief Inicializa el número activo de relays y limpia los estados.
     * @param count Número de relays activos (máximo MAX_COUNT)
     */
    void init(uint16_t count = MAX_COUNT) {
        _count = (count > MAX_COUNT) ? MAX_COUNT : count;
        clearAll();
    }

    /**
     * @brief Establece el estado de un relay individual por su índice de bit.
     * @param index Índice del relay (0 a MAX_COUNT - 1)
     * @param on    true = encendido (bit 1), false = apagado (bit 0)
     */
    void set(uint16_t index, bool on) {
        if (index >= _count) return;
        uint16_t wordIdx = index >> 5;          // index / 32
        uint32_t bitMask = 1UL << (index & 31); // bit en el word
        if (on) {
            _words[wordIdx] |= bitMask;
        } else {
            _words[wordIdx] &= ~bitMask;
        }
    }

    /**
     * @brief Retorna el estado lógico actual de un relay.
     * @param index Índice del relay (0 a MAX_COUNT - 1)
     * @return true si el bit está activo (1), false si está inactivo (0) o fuera de rango
     */
    bool get(uint16_t index) const {
        if (index >= _count) return false;
        return (_words[index >> 5] & (1UL << (index & 31))) != 0;
    }

    /**
     * @brief Alterna (Invertir / Toggle) el estado de un relay mediante XOR bitwise.
     * @param index Índice del relay (0 a MAX_COUNT - 1)
     */
    void toggle(uint16_t index) {
        if (index >= _count) return;
        _words[index >> 5] ^= (1UL << (index & 31));
    }

    /**
     * @brief Enciende o apaga todos los relays activos simultáneamente con operaciones bitwise rápidas.
     * @param on true = todos en 1, false = todos en 0
     */
    void setAll(bool on) {
        memset(_words, on ? 0xFF : 0x00, sizeof(_words));
    }

    /**
     * @brief Apaga (limpia) todos los relays poniendo todos los bits a 0.
     */
    void clearAll() {
        memset(_words, 0, sizeof(_words));
    }

    /**
     * @brief Alterna el estado de absolutamente TODOS los relays activos con una sola operación XOR por palabra de 32 bits.
     */
    void toggleAll() {
        for (uint16_t i = 0; i < WORDS_COUNT; i++) {
            _words[i] = ~_words[i];
        }
    }

    /**
     * @brief Retorna la máscara de 16 bits inferior (relays 0 al 15) ideal para los paquetes de red Colmena / Heartbeat.
     */
    uint16_t getMask16() const {
        return (uint16_t)(_words[0] & 0xFFFFUL);
    }

    /**
     * @brief Asigna una máscara de 16 bits inferior sin alterar los bits superiores.
     */
    void setMask16(uint16_t mask) {
        _words[0] = (_words[0] & ~0xFFFFUL) | (uint32_t)mask;
    }

    /**
     * @brief Retorna una palabra entera de 32 bits por su índice de palabra.
     * @param wordIdx Índice del bloque de 32 bits (0 = relays 0-31, 1 = relays 32-63, etc.)
     */
    uint32_t getWord(uint16_t wordIdx = 0) const {
        if (wordIdx >= WORDS_COUNT) return 0;
        return _words[wordIdx];
    }

    /**
     * @brief Sobrescribe una palabra entera de 32 bits.
     */
    void setWord(uint32_t mask, uint16_t wordIdx = 0) {
        if (wordIdx < WORDS_COUNT) {
            _words[wordIdx] = mask;
        }
    }

    /** @brief Cantidad de relays activos configurados en esta instancia. */
    uint16_t getCount() const { return _count; }

private:
    uint16_t _count;
    uint32_t _words[WORDS_COUNT];
};

#endif // RELAY_STATE_H
