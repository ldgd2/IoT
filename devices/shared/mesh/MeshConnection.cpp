#include "mesh/MeshConnection.h"
#include <SPI.h>

#if defined(IS_RP2040) && defined(USE_TINYUSB)
#include <Adafruit_TinyUSB.h>
static void safe_delay(unsigned long ms) {
    unsigned long start = millis();
    while (millis() - start < ms) {
        tud_task();
        delay(1);
    }
}
#else
static void safe_delay(unsigned long ms) {
    delay(ms);
}
#endif

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

    // Retardo largo de 500ms para permitir estabilización completa del regulador AMS1117 y condensadores soldados
    // Al usar safe_delay(), el stack TinyUSB (tud_task) se atiende cada milisegundo y Windows NO desconecta el HID
    safe_delay(500);

    // En pruebas de escritorio a corta distancia (centímetros o pocos metros), RF24_PA_MAX y RF24_PA_LOW
    // saturan y ciegan el receptor LNA del chip opuesto causando 100% de pérdida de paquetes.
    // RF24_PA_MIN (-18dBm) garantiza comunicación perfecta cara a cara o en interiores sin saturar.
    // NOTA CRÍTICA NRF24L01+ / Si24R1: El registro RF_SETUP (setPALevel/setDataRate) NUNCA debe escribirse
    // con el radio en modo PRX o PTX (CE en HIGH) o el receptor/transmisor se bloqueará indefinidamente.

    if (_nodeId > 0 && _nodeId <= 5) {
        // Nodos Leaf con enrutamiento estático (ID 1 al 5):
        // NO intentamos DHCP (`_mesh.begin`) porque el Master ya tiene sus direcciones preasignadas.
        bool radioFound = false;
        for (int attempt = 0; attempt < 5; attempt++) {
            digitalWrite(CSN_PIN, HIGH);
            digitalWrite(CE_PIN, LOW);
            safe_delay(50);
            if (_radio.begin()) {
                radioFound = true;
                break;
            }
            safe_delay(150);
        }
        if (!radioFound || !_radio.isChipConnected()) {
            return false;
        }

        _radio.setChannel(RF_CHANNEL);
        _radio.setDataRate(RF_DATARATE);
        _radio.setPALevel(RF24_PA_MIN);

        _mesh.mesh_address = _nodeId;
        _network.begin(_mesh.mesh_address); // Configura pipes de lectura y activa CE en HIGH al finalizar
    } else {
        // Master (ID 0) y Nodos dinámicos (ID > 5):
        bool initOk = false;
        for (int attempt = 0; attempt < 5; attempt++) {
            digitalWrite(CSN_PIN, HIGH);
            digitalWrite(CE_PIN, LOW);
            safe_delay(50);

            uint32_t timeout = (_nodeId == 0) ? 2000 : 2500;
            if (_mesh.begin(RF_CHANNEL, RF_DATARATE, timeout)) {
                initOk = true;
                break;
            }
            safe_delay(150);
        }
        if (!initOk) {
            return false;
        }

        // Aplicar potencia mínima de forma segura desactivando CE temporalmente antes de tocar RF_SETUP
        _radio.stopListening();
        _radio.setPALevel(RF24_PA_MIN);
        _radio.startListening();

        if (_nodeId == 0) {
            // Enrutar estáticamente los nodos 1 al 5 en el master sin requerir DHCP (compatibilidad 100% Si24R1)
            for (uint8_t i = 1; i <= 5; i++) {
                _mesh.setAddress(i, i);
            }
        }
    }

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
    // En RF24Mesh, _mesh.update() debe llamarse continuamente en cada ciclo de loop().
    // Limitarlo a 1 segundo o depender exclusivamente del pin IRQ provoca que se pierdan
    // las peticiones rápidas de DHCP y los paquetes CMD_DISCOVER durante la vinculación.
    if (_irqPin != -1 && rfDataReady) {
        rfDataReady = false;
    }
    return true;
}

void MeshConnection::update() {
    if (shouldPerformUpdate()) {
        _mesh.update();
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
    if (_nodeId > 0 && _nodeId <= 5) {
        if (_mesh.mesh_address == MESH_DEFAULT_ADDRESS || _mesh.mesh_address != _nodeId) {
            _radio.stopListening();
            _mesh.mesh_address = _nodeId;
            _network.begin(_mesh.mesh_address);
        }
        return _radio.isChipConnected();
    }
    return _mesh.checkConnection();
}

bool MeshConnection::reconnect() {
    _radio.stopListening();
    _radio.setPALevel(RF24_PA_MIN);
    if (_nodeId > 0 && _nodeId <= 5) {
        _mesh.mesh_address = _nodeId;
        _network.begin(_mesh.mesh_address);
        return _radio.isChipConnected();
    }
    _radio.startListening();
    return _mesh.renewAddress(1500) != MESH_DEFAULT_ADDRESS;
}
