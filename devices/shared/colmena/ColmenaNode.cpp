#include "colmena/ColmenaNode.h"
#include <Arduino.h>

ColmenaNode::ColmenaNode(IConnection& conn, IParamStore& store)
    : ColmenaBase(conn, store),
      _lastHeartbeatMs(0),
      _pairPin(255),
      _pairActiveLow(true),
      _pairLastState(false),
      _pairDebounceMs(0),
      _pairLastAnnounce(0),
      _isPairingMode(false),
      _pairingStartMs(0),
      _lastPairingRetryMs(0)
{
    _pairingNodeName[0] = '\0';
}

void ColmenaNode::startPairingWindow(const char* nodeName) {
    _isPairingMode = true;
    _pairingStartMs = millis();
    _lastPairingRetryMs = 0; // Para que tickPairing dispare el primer anuncio inmediatamente en el siguiente ciclo del loop
    if (nodeName) {
        strncpy(_pairingNodeName, nodeName, sizeof(_pairingNodeName) - 1);
        _pairingNodeName[sizeof(_pairingNodeName) - 1] = '\0';
    } else {
        _pairingNodeName[0] = '\0';
    }
    Serial.println("\n=================================================");
    Serial.println("🔍 [VINCULACIÓN NODO] Ventana de búsqueda activa por 50 segundos...");
    Serial.println("=================================================");
}

void ColmenaNode::tickPairing() {
    if (!_isPairingMode) return;
    
    unsigned long now = millis();
    if (now - _pairingStartMs > 50000UL) {
        _isPairingMode = false;
        Serial.println("\n⏱️ [VINCULACIÓN NODO] Tiempo agotado (50s) sin respuesta del Gateway. Deteniendo búsqueda.\n");
        return;
    }
    
    if (now - _lastPairingRetryMs > 2500UL) {
        _lastPairingRetryMs = now;
        unsigned long quedan = (50000UL - (now - _pairingStartMs)) / 1000UL;
        Serial.printf("\n🔄 [VINCULACIÓN 50s] Buscando Gateway (Quedan %lu seg)...\r\n", quedan);
        announce(_pairingNodeName);
    }
}

void ColmenaNode::announce(const char* nodeName) {
    if (nodeName && nodeName != _pairingNodeName) {
        strncpy(_pairingNodeName, nodeName, sizeof(_pairingNodeName) - 1);
        _pairingNodeName[sizeof(_pairingNodeName) - 1] = '\0';
    }
    if (!_conn.isConnected()) {
        Serial.println("🔄 [TX RF] Verificando enlace RF y conectividad con el Gateway...");
        _conn.reconnect();
    }
    RFPacket pkt;
    Protocol_initPacket(&pkt, _p.nodeId, ADDR_MASTER, _p.deviceType, CMD_DISCOVER);
    LightPayload::setDiscovery(pkt, _pairingNodeName, _p.features, _p.fwVersion);
    Protocol_seal(&pkt);
    
    Serial.printf("📤 [TX RF] Enviando CMD_DISCOVER (Anuncio) al Master [ID Orig: %u -> Dest: 0]\r\n", _p.nodeId);
    bool ok = _conn.send(&pkt, sizeof(pkt), ADDR_MASTER);
    if (ok) {
        Serial.println("✔️ [TX RF] ¡CMD_DISCOVER entregado y confirmado por el Gateway!");
        _isPairingMode = false;
    } else {
        Serial.println("❌ [TX RF] Falló envío. (Se reintentará automáticamente sin bloquear el botón/LED).");
    }
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
    Serial.printf("📤 [TX RF] Enviando CMD_HEARTBEAT al Master [ID Orig: %u]\r\n", _p.nodeId);
    bool ok = _conn.send(&pkt, sizeof(pkt), ADDR_MASTER);
    if (!ok) {
        ok = _conn.send(&pkt, sizeof(pkt), ADDR_MASTER);
    }
    if (ok) {
        Serial.println("✔️ [TX RF] Heartbeat enviado OK.");
    } else {
        Serial.println("❌ [TX RF] Falló envío de Heartbeat.");
    }
    _lastHeartbeatMs = millis();
}

void ColmenaNode::tickHeartbeat(uint16_t relayMask, uint8_t brightness) {
    tickPairing();
    unsigned long interval = (unsigned long)_p.heartbeatInterval * 1000UL;
    if (millis() - _lastHeartbeatMs >= interval) {
        sendHeartbeat(relayMask, brightness);
    }
}

void ColmenaNode::applySync(const RFPacket& pkt) {
    _isPairingMode = false;
    Serial.printf("📥 [RX RF] Recibido CONFIG_SYNC del Gateway (CH: %u, Rate: %u)\r\n", GatewayPayload::getConfigChannel(pkt), GatewayPayload::getConfigDataRate(pkt));
    _p.rfChannel         = GatewayPayload::getConfigChannel(pkt);
    _p.rfDataRate        = GatewayPayload::getConfigDataRate(pkt);
    _p.heartbeatInterval = GatewayPayload::getConfigHeartbeat(pkt);
    GatewayPayload::getConfigName(pkt, _p.colmenaName, sizeof(_p.colmenaName));
    save();
    Serial.println("✔️ [RX RF] Configuración de red sincronizada y guardada.");
}

void ColmenaNode::unpair() {
    _isPairingMode = true;
    _pairingStartMs = millis();
    _p.rfChannel = 76;
    save();
    Serial.println("🔄 [ColmenaNode] Desvinculado por orden remota del Gateway. Volviendo a modo emparejamiento...");
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

    // Cooldown de 2 segundos entre pulsaciones exitosas de vinculación
    if ((now - _pairLastAnnounce) < 2000UL) {
        return false;
    }

    // ✔ ¡Botón mantenido por 1.2 segundos! Disparar modo vinculación
    _pairLastAnnounce = now;
    Serial.println("\n[BOTÓN] ¡Modo vinculación activado! Disparando ventana de búsqueda por 50s...");
    startPairingWindow(nodeName);
    return true;
}
