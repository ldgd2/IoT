#ifndef IACTUATOR_H
#define IACTUATOR_H

/**
 * @file IActuator.h
 * @brief Interfaz pura para cualquier tipo de actuador controlable.
 *
 * Define el contrato mínimo que todo actuador debe implementar,
 * sea un relay, un canal PWM, un servo, una válvula, etc.
 *
 * Esta interfaz es el punto de extensión del sistema de actuadores.
 * Los módulos de lógica (ColmenaNode, main.cpp) trabajan con IActuator*
 * sin conocer el tipo físico del actuador.
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include <stdint.h>

class IActuator {
public:
    virtual ~IActuator() {}

    /**
     * @brief Establece el estado del actuador.
     * @param on  true = activado, false = desactivado
     */
    virtual void setState(bool on) = 0;

    /**
     * @brief Retorna el estado actual del actuador.
     * @return true si el actuador está activado
     */
    virtual bool getState() const = 0;

    /**
     * @brief Invierte el estado actual del actuador.
     */
    virtual void toggle() = 0;
};

#endif // IACTUATOR_H
