#include "actuators/relay/RelayBank.h"

RelayBank::RelayBank() : _count(0) {}

void RelayBank::init(uint8_t count, const uint8_t* pins, bool activeLow) {
    // Limitar al máximo soportado
    _count = (count > MAX_RELAYS) ? MAX_RELAYS : count;
    _stateBits.init(_count);

    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].init(pins[i], activeLow);
    }
}

void RelayBank::setState(uint8_t index, bool on) {
    if (!isValid(index)) return;
    _stateBits.set(index, on);
    _relays[index].setState(on);
}

bool RelayBank::getState(uint8_t index) const {
    if (!isValid(index)) return false;
    return _stateBits.get(index);
}

void RelayBank::toggle(uint8_t index) {
    if (!isValid(index)) return;
    _stateBits.toggle(index);
    _relays[index].setState(_stateBits.get(index));
}

void RelayBank::setAll(bool on) {
    _stateBits.setAll(on);
    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].setState(on);
    }
}

void RelayBank::toggleAll() {
    _stateBits.toggleAll();
    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].setState(_stateBits.get(i));
    }
}

void RelayBank::setMask(uint16_t mask) {
    _stateBits.setMask16(mask);
    for (uint8_t i = 0; i < _count; i++) {
        _relays[i].setState(_stateBits.get(i));
    }
}

uint16_t RelayBank::getMask() const {
    return _stateBits.getMask16();
}

IActuator* RelayBank::get(uint8_t index) {
    if (!isValid(index)) return nullptr;
    return &_relays[index];
}
