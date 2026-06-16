#include "mesh/MeshConnection.h"

volatile bool MeshConnection::rfDataReady = false;

void ISR_PREFIX MeshConnection::rfInterruptHandler() {
    rfDataReady = true;
}

MeshConnection::MeshConnection(uint8_t nodeId, int8_t irqPin)
    : _irqPin(irqPin),
      _nodeId(nodeId),
      _radio(CE_PIN, CSN_PIN),
      _network(_radio),
      _mesh(_radio, _network)
{}

bool MeshConnection::begin() {
    _mesh.setNodeID(_nodeId);
    if (!_mesh.begin(RF_CHANNEL, RF_DATARATE)) return false;
    _radio.setPALevel(RF24_PA_MAX);

    if (_irqPin != -1) {
        pinMode(_irqPin, INPUT_PULLUP);
        // maskIRQ(tx_ok, tx_fail, rx_ready)
        // Solo queremos que RX_READY baje el pin IRQ
        _radio.maskIRQ(1, 1, 0);
        attachInterrupt(digitalPinToInterrupt(_irqPin), rfInterruptHandler, FALLING);
    }

    return true;
}

bool MeshConnection::shouldPerformUpdate() {
    bool doUpdate = true;
    if (_irqPin != -1) {
        static unsigned long lastMaintenance = 0;
        unsigned long now = millis();
        
        // Verificamos si bajó la bandera IRQ o leemos el pin directamente por si se perdió la IRQ
        if (rfDataReady || digitalRead(_irqPin) == LOW) {
            rfDataReady = false;
            doUpdate = true;
        } else if (now - lastMaintenance > 1000) {
            // Cada segundo forzamos update para mantenimiento de RF24Mesh
            doUpdate = true;
        } else {
            doUpdate = false;
        }

        if (doUpdate) {
            lastMaintenance = now;
        }
    }
    return doUpdate;
}

void MeshConnection::update() {
    if (shouldPerformUpdate()) {
        _mesh.update();
        if (!_mesh.checkConnection()) {
            _mesh.renewAddress();
        }
    }
}

bool MeshConnection::send(const void* data, size_t len, uint8_t destId) {
    return _mesh.write(data, 'C', len, destId);
}

bool MeshConnection::receive(void* buf, size_t len) {
    RF24NetworkHeader header;
    return _network.read(header, buf, len) > 0;
}

bool MeshConnection::available() {
    return _network.available();
}

bool MeshConnection::isConnected() {
    return _mesh.checkConnection();
}

bool MeshConnection::reconnect() {
    return _mesh.renewAddress() != MESH_DEFAULT_ADDRESS;
}
