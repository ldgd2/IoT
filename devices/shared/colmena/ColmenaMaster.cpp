#include "colmena/ColmenaMaster.h"
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
    NodeInfo* node = _findOrCreate(pkt.originId);
    if (!node) return;

    node->lastHeartbeatMs = millis();
    node->online          = true;
    node->deviceType      = pkt.deviceType;

    switch (pkt.command) {
        case CMD_DISCOVER:
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
    _conn.send(&pkt, sizeof(pkt), ADDR_BROADCAST);
}

void ColmenaMaster::sendSync(uint8_t destId) {
    RFPacket pkt;
    _buildSyncPacket(pkt, destId);
    _conn.send(&pkt, sizeof(pkt), destId);
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
