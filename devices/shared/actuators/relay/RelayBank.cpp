#include "actuators/relay/RelayBank.h"

RelayBank::RelayBank() : _count(0) {}

void RelayBank::init(uint8_t count, const uint8_t* pins, bool activeLow) {
    // Limitar al máximo soportado
    _count = (count > MAX_RELAYS) ? MAX_RELAYS : count;

    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].init(pins[i], activeLow);
    }
}

void RelayBank::setState(uint8_t index, bool on) {
    if (!isValid(index)) return;
    _relays[index].setState(on);
}

bool RelayBank::getState(uint8_t index) const {
    if (!isValid(index)) return false;
    return _relays[index].getState();
}

void RelayBank::toggle(uint8_t index) {
    if (!isValid(index)) return;
    _relays[index].toggle();
}

void RelayBank::setAll(bool on) {
    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].setState(on);
    }
}

void RelayBank::toggleAll() {
    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].toggle();
    }
}

void RelayBank::setMask(uint16_t mask) {
    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].setState((mask >> i) & 0x01);
    }
}

uint16_t RelayBank::getMask() const {
    uint16_t mask = 0;
    for (uint8_t i = 0; i < _count; i++) {
        if (_relays[i].getState()) {
            mask |= (uint16_t)(1 << i);
        }
    }
    return mask;
}

IActuator* RelayBank::get(uint8_t index) {
    if (!isValid(index)) return nullptr;
    return &_relays[index];
}
