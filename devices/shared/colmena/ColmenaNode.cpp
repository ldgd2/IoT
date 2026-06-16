#include "colmena/ColmenaNode.h"
#include <Arduino.h>

ColmenaNode::ColmenaNode(IConnection& conn, IParamStore& store)
    : ColmenaBase(conn, store), _lastHeartbeatMs(0)
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
