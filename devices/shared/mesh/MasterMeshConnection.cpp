#include "mesh/MasterMeshConnection.h"

MasterMeshConnection::MasterMeshConnection()
    : MeshConnection(0)   // Node 0 = master
{}

void MasterMeshConnection::update() {
    if (shouldPerformUpdate()) {
        getMesh().update();
        getMesh().DHCP();   // ← Solo el master asigna direcciones a los nodos leaf
    }
}

uint8_t MasterMeshConnection::getNodeCount() const {
    return (uint8_t)const_cast<MasterMeshConnection*>(this)->getMesh().addrListTop;
}

int MasterMeshConnection::getLogicalNodeId(uint16_t fromNode) {
    return getMesh().getNodeID(fromNode);
}
