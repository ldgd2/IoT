#include "actuators/relay/Relay.h"

Relay::Relay() : _pin(0), _state(false), _activeLow(false) {}

void Relay::init(uint8_t pin, bool activeLow) {
    _pin       = pin;
    _activeLow = activeLow;
    _state     = false;
    digitalWrite(_pin, _physicalLevel(false));  // Escribir nivel apagado antes de habilitar el buffer de salida
    pinMode(_pin, OUTPUT);                      // Ahora al pasar a salida, el pin se mantiene en apagado (sin click de encendido)
}

void Relay::setState(bool on) {
    _state = on;
    digitalWrite(_pin, _physicalLevel(on));
}

bool Relay::getState() const {
    return _state;
}

void Relay::toggle() {
    setState(!_state);
}
