#include "mesh/MeshConnection.h"
#include <SPI.h>

volatile bool MeshConnection::rfDataReady = false;

void ISR_PREFIX MeshConnection::rfInterruptHandler() {
    rfDataReady = true;
}

MeshConnection::MeshConnection(uint8_t nodeId, int8_t irqPin)
    : _irqPin(irqPin),
      _nodeId(nodeId),
      // Usar 2 MHz (2000000) en lugar de los 10 MHz por defecto.
      // En protoboards con cables Dupont, 10 MHz causa ruido, capacitancia parasita y rebote de señal,
      // haciendo que el chip no responda aunque la continuidad sea fluida. 2 MHz es estable y seguro.
      _radio(CE_PIN, CSN_PIN, 2000000),
      _network(_radio),
      _mesh(_radio, _network)
{}

bool MeshConnection::begin() {
    _mesh.setNodeID(_nodeId);

    // Pre-configurar pines CE y CSN en un estado conocido antes de tocar el bus SPI
    pinMode(CE_PIN, OUTPUT);
    pinMode(CSN_PIN, OUTPUT);
    digitalWrite(CSN_PIN, HIGH); // CSN alto = bus SPI libre/deseleccionado
    digitalWrite(CE_PIN, LOW);   // CE bajo  = radio en modo espera/configuración

#if defined(IS_RP2040)
    // Enrutar explícitamente los pines del bus SPI0 por hardware en RP2040
    SPI.setSCK(18);
    SPI.setTX(19);  // MOSI
    SPI.setRX(16);  // MISO
    SPI.begin();
#endif

    // Retardo largo para permitir estabilización completa de voltaje y condensadores en protoboard/YD-RP2040
    delay(500);

    bool initOk = false;
    for (int attempt = 0; attempt < 8; attempt++) {
        // Asegurar que CSN esté en HIGH y CE en LOW antes de cada intento para limpiar el bus SPI
        digitalWrite(CSN_PIN, HIGH);
        digitalWrite(CE_PIN, LOW);
        delay(50);

        if (_mesh.begin(RF_CHANNEL, RF_DATARATE)) {
            initOk = true;
            break;
        }
        delay(250);
    }

    if (!initOk) {
        return false;
    }
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
