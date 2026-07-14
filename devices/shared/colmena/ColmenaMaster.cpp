#include "colmena/ColmenaMaster.h"
#include <Arduino.h>
#include <string.h>

ColmenaMaster::ColmenaMaster(IConnection& conn, IParamStore& store)
    : ColmenaBase(conn, store), _nodeCount(0)
{
    memset(_nodes, 0, sizeof(_nodes));
    // El master siempre es Node 0
    _p.nodeId     = 0;
    _p.deviceType = DEV_TYPE_GATEWAY;
    _p.features   = 0;
}

void ColmenaMaster::onPacketReceived(const RFPacket& pkt) {
    Serial.printf("[RX RF] Paquete recibido de Nodo %u | CMD: 0x%02X | Tipo: 0x%02X\r\n", pkt.originId, pkt.command, pkt.deviceType);
    NodeInfo* node = _findOrCreate(pkt.originId);
    if (!node) return;

    node->lastHeartbeatMs = millis();
    node->online          = true;
    node->deviceType      = pkt.deviceType;

    switch (pkt.command) {
        case CMD_DISCOVER:
            Serial.printf("[RX RF] Anuncio CMD_DISCOVER recibido del Nodo %u! Procesando vinculacion...\r\n", pkt.originId);
            node->features = GatewayPayload::getDiscoverFeatures(pkt);
            GatewayPayload::getDiscoverName(pkt, node->name, sizeof(node->name));
            // Responder con CONFIG_SYNC para que el nodo conozca la config de red
            sendSync(pkt.originId);
            break;

        case CMD_HEARTBEAT:
            // Actualizar bitmask de relays del nodo
            node->relayMask = (uint16_t)pkt.data[2] | ((uint16_t)pkt.data[3] << 8);
            break;

        default:
            break;
    }
}

void ColmenaMaster::_buildSyncPacket(RFPacket& pkt, uint8_t destId) {
    Protocol_initPacket(&pkt, ADDR_MASTER, destId, DEV_TYPE_GATEWAY, CMD_CONFIG_SYNC);
    GatewayPayload::setConfigSync(pkt, _p.rfChannel, _p.rfDataRate,
                                   _p.heartbeatInterval, _p.colmenaName);
    Protocol_seal(&pkt);
}

void ColmenaMaster::broadcastSync() {
    RFPacket pkt;
    _buildSyncPacket(pkt, ADDR_BROADCAST);
    Serial.println("[TX RF] Enviando CONFIG_SYNC Broadcast...");
    _conn.send(&pkt, sizeof(pkt), ADDR_BROADCAST);
    for (uint8_t id = 1; id <= 5; id++) {
        _conn.send(&pkt, sizeof(pkt), id);
    }
}

void ColmenaMaster::broadcastPing() {
    // Envía CMD_REPORT broadcast: los nodos que ya estaban corriendo
    // lo reciben en su loop() y responden con un CMD_DISCOVER (announce).
    RFPacket pkt;
    Protocol_initPacket(&pkt, ADDR_MASTER, ADDR_BROADCAST, DEV_TYPE_GATEWAY, CMD_REPORT);
    Protocol_seal(&pkt);
    Serial.println("[TX RF] Enviando CMD_REPORT (Ping) Broadcast...");
    _conn.send(&pkt, sizeof(pkt), ADDR_BROADCAST);
    for (uint8_t id = 1; id <= 5; id++) {
        _conn.send(&pkt, sizeof(pkt), id);
    }
}


void ColmenaMaster::sendSync(uint8_t destId) {
    RFPacket pkt;
    _buildSyncPacket(pkt, destId);
    Serial.printf("[TX RF] Enviando CONFIG_SYNC al Nodo %u...\r\n", destId);
    bool ok = _conn.send(&pkt, sizeof(pkt), destId);
    if (ok) {
        Serial.printf("[TX RF] CONFIG_SYNC entregado exitosamente al Nodo %u.\r\n", destId);
    } else {
        Serial.printf("[TX RF] Fallo entrega de CONFIG_SYNC al Nodo %u.\r\n", destId);
    }
}

void ColmenaMaster::checkHeartbeatTimeouts(uint32_t timeoutMs) {
    uint32_t now = millis();
    for (uint8_t i = 0; i < _nodeCount; i++) {
        if (_nodes[i].online && (now - _nodes[i].lastHeartbeatMs) > timeoutMs) {
            _nodes[i].online = false;
        }
    }
}

uint8_t ColmenaMaster::getOnlineCount() const {
    uint8_t count = 0;
    for (uint8_t i = 0; i < _nodeCount; i++) {
        if (_nodes[i].online) count++;
    }
    return count;
}

const NodeInfo* ColmenaMaster::getNode(uint8_t idx) const {
    if (idx >= _nodeCount) return nullptr;
    return &_nodes[idx];
}

const NodeInfo* ColmenaMaster::findNode(uint8_t nodeId) const {
    for (uint8_t i = 0; i < _nodeCount; i++) {
        if (_nodes[i].nodeId == nodeId) return &_nodes[i];
    }
    return nullptr;
}

void ColmenaMaster::removeNode(uint8_t nodeId) {
    for (uint8_t i = 0; i < _nodeCount; i++) {
        if (_nodes[i].nodeId == nodeId) {
            for (uint8_t j = i; j < _nodeCount - 1; j++) {
                _nodes[j] = _nodes[j + 1];
            }
            _nodeCount--;
            Serial.printf("[ColmenaMaster] Nodo %u eliminado y desvinculado de tabla interna.\r\n", nodeId);
            return;
        }
    }
}

NodeInfo* ColmenaMaster::_findOrCreate(uint8_t nodeId) {
    for (uint8_t i = 0; i < _nodeCount; i++) {
        if (_nodes[i].nodeId == nodeId) return &_nodes[i];
    }
    if (_nodeCount < COLMENA_MAX_NODES) {
        NodeInfo& n = _nodes[_nodeCount++];
        memset(&n, 0, sizeof(NodeInfo));
        n.nodeId = nodeId;
        return &n;
    }
    return nullptr;
}
