#include "colmena/ColmenaNode.h"
#include <Arduino.h>

ColmenaNode::ColmenaNode(IConnection& conn, IParamStore& store)
    : ColmenaBase(conn, store),
      _lastHeartbeatMs(0),
      _pairPin(255),
      _pairActiveLow(true),
      _pairLastState(false),
      _pairDebounceMs(0),
      _pairLastAnnounce(0)
{}

void ColmenaNode::announce(const char* nodeName) {
    RFPacket pkt;
    Protocol_initPacket(&pkt, _p.nodeId, ADDR_MASTER, _p.deviceType, CMD_DISCOVER);
    LightPayload::setDiscovery(pkt, nodeName, _p.features, _p.fwVersion);
    Protocol_seal(&pkt);
    _conn.send(&pkt, sizeof(pkt), ADDR_MASTER);
}

void ColmenaNode::sendHeartbeat(uint16_t relayMask, uint8_t brightness) {
    RFPacket pkt;
    Protocol_initPacket(&pkt, _p.nodeId, ADDR_MASTER, _p.deviceType, CMD_HEARTBEAT);
    // data[0] = estado relay 0 (bit 0 del mask), data[1] = brillo
    // data[2..3] = relay mask completo (hasta 16 relays en 2 bytes)
    pkt.data[0] = (relayMask & 0x01) ? 1 : 0;
    pkt.data[1] = brightness;
    pkt.data[2] = (uint8_t)(relayMask & 0xFF);
    pkt.data[3] = (uint8_t)((relayMask >> 8) & 0xFF);
    Protocol_seal(&pkt);
    _conn.send(&pkt, sizeof(pkt), ADDR_MASTER);
    _lastHeartbeatMs = millis();
}

void ColmenaNode::tickHeartbeat(uint16_t relayMask, uint8_t brightness) {
    unsigned long interval = (unsigned long)_p.heartbeatInterval * 1000UL;
    if (millis() - _lastHeartbeatMs >= interval) {
        sendHeartbeat(relayMask, brightness);
    }
}

void ColmenaNode::applySync(const RFPacket& pkt) {
    _p.rfChannel         = GatewayPayload::getConfigChannel(pkt);
    _p.rfDataRate        = GatewayPayload::getConfigDataRate(pkt);
    _p.heartbeatInterval = GatewayPayload::getConfigHeartbeat(pkt);
    GatewayPayload::getConfigName(pkt, _p.colmenaName, sizeof(_p.colmenaName));
    save();
}

// ── Botón de vinculación ──────────────────────────────────────────────────

void ColmenaNode::initPairButton(uint8_t pin, bool activeLow) {
    _pairPin        = pin;
    _pairActiveLow  = activeLow;
    _pairLastAnnounce = 0;
    _pairDebounceMs   = 0;
    // Configurar pull-up interno si es active-low (botón a GND).
    // Si es active-high (botón táctil TTP223 a VCC), usar INPUT_PULLDOWN donde exista o INPUT.
#if defined(IS_RP2040) || defined(ARDUINO_ARCH_RP2040)
    pinMode(pin, activeLow ? INPUT_PULLUP : INPUT_PULLDOWN);
    pinMode(24, INPUT_PULLUP); // Botón físico integrado KEY/USR en YD-RP2040 (GP24)
#elif defined(IS_ESP32) || defined(ARDUINO_ARCH_ESP32)
    pinMode(pin, activeLow ? INPUT_PULLUP : INPUT_PULLDOWN);
#else
    pinMode(pin, activeLow ? INPUT_PULLUP : INPUT);
#endif
    // Leer estado inicial para no disparar en el arranque
    _pairLastState = false;
}

bool ColmenaNode::tickPairButton(const char* nodeName) {
    unsigned long now       = millis();
    bool rawPressed         = false;

    if (_pairPin != 255) {
        rawPressed = (digitalRead(_pairPin) == LOW) == _pairActiveLow;
    }

#if defined(IS_RP2040) || defined(ARDUINO_ARCH_RP2040)
    // En YD-RP2040, el botón físico integrado (KEY/USR) está conectado a tierra en GP24
    if (digitalRead(24) == LOW) {
        rawPressed = true;
    }
#endif

    if (!rawPressed) {
        _pairLastState  = false;
        _pairDebounceMs = 0;
        return false;
    }

    // Si acaba de presionar el botón, registrar el instante inicial
    if (!_pairLastState) {
        _pairLastState  = true;
        _pairDebounceMs = now;
        Serial.println("\n[BOTÓN] ¡Contacto detectado! Mantén presionado ~1 segundo para entrar en modo vinculación...");
        return false;
    }

    // Calcular cuánto tiempo continuo lleva presionado el botón
    unsigned long heldMs = now - _pairDebounceMs;

    // Requisito: mantener presionado mínimo 1.2 segundos (1200 ms) para evitar rebotes o toques accidentales
    if (heldMs < 1200UL) {
        return false;
    }

    // Cooldown de 30 segundos mientras el modo vinculación está en curso
    if ((now - _pairLastAnnounce) < 30000UL) {
        return false;
    }

    // ✔ ¡Botón mantenido por 1.2 segundos! Disparar modo vinculación
    _pairLastAnnounce = now;
    Serial.println("\n[BOTÓN] ¡Modo vinculación activado! Disparando anuncio por RF (CMD_DISCOVER)...");
    announce(nodeName);
    return true;
}
