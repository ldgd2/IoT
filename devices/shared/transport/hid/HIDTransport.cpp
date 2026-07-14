#include "HIDTransport.h"

#if defined(IS_RP2040) && defined(USE_TINYUSB)

// ── Variables estáticas ───────────────────────────────────────────────────────
bool    HIDTransport::_hasPacket = false;
uint8_t HIDTransport::_rxBuf[64] = {0};

// ── Constructor ───────────────────────────────────────────────────────────────
HIDTransport::HIDTransport()
    : _hid(HID_TRANSPORT_DESC, sizeof(HID_TRANSPORT_DESC),
           HID_ITF_PROTOCOL_NONE, 2, false)
{}

// ── begin() ───────────────────────────────────────────────────────────────────
bool HIDTransport::begin() {
    // IMPORTANTE: los descriptores deben configurarse ANTES de _hid.begin()
    // De lo contrario TinyUSB ya enumeró como CDC y el host ve un COM port.
    // VID/PID vienen de los build flags definidos en platformio.ini
    TinyUSBDevice.setManufacturerDescriptor(USBD_MANUFACTURER_STRING);
    TinyUSBDevice.setProductDescriptor(USBD_PRODUCT_STRING);
    TinyUSBDevice.setID(HID_VID, HID_PID);

    // Registrar callback de recepción ANTES de begin()
    _hid.setReportCallback(NULL, _onSetReport);

    // Iniciar stack HID — esto gatilla la enumeración USB con los descriptores ya configurados
    _hid.begin();

    // En el core earlephilhower para RP2040, el stack USB se inicia antes de setup().
    // Si ya enumeró como CDC, la nueva interfaz HID y el cambio de VID/PID no tomarán efecto
    // hasta forzar una re-enumeración (detach/attach) en el bus USB.
    if (TinyUSBDevice.mounted()) {
        TinyUSBDevice.detach();
        delay(20);
        TinyUSBDevice.attach();
    }

    // Bombear el stack USB mientras esperamos que el host monte el dispositivo (max 5s)
    unsigned long t = millis();
    while (!TinyUSBDevice.mounted() && (millis() - t < 5000)) {
#ifdef ARDUINO_ARCH_RP2040
        tud_task(); // Procesar eventos USB del stack TinyUSB
#endif
        delay(1);
    }

    return TinyUSBDevice.mounted();
}

// ── available() ──────────────────────────────────────────────────────────────
bool HIDTransport::available() {
#ifdef ARDUINO_ARCH_RP2040
    tud_task();
#endif
    return _hasPacket;
}

// ── readPacket() ──────────────────────────────────────────────────────────────
bool HIDTransport::readPacket(RFPacket& pkt) {
    if (!_hasPacket) return false;
    _hasPacket = false;

    if (sizeof(RFPacket) > 64) return false; // Sanity check

    memcpy(&pkt, _rxBuf, sizeof(RFPacket));

    // Si el host USB/HID envió checksum en 0 (ej. desde el frontend o python sin CRC), sellar automáticamente
    if (pkt.checksum == 0) {
        Protocol_seal(&pkt);
        return true;
    }

    // Verificar checksum del paquete recibido
    return Protocol_verify(&pkt);
}

// ── sendPacket() ──────────────────────────────────────────────────────────────
bool HIDTransport::sendPacket(const RFPacket& pkt) {
    if (!_hid.ready()) return false;

    uint8_t report[64] = {0};
    memcpy(report, &pkt, sizeof(RFPacket));
    report[32] = 0x01;  // Flag: paquete RF válido entrante

    return _hid.sendReport(0, report, sizeof(report));
}

// ── sendAck() ─────────────────────────────────────────────────────────────────
bool HIDTransport::sendAck(bool ok, uint8_t destId) {
    if (!_hid.ready()) return false;

    uint8_t report[64] = {0};
    report[32] = 0x02;          // Flag: este report es un ACK
    report[33] = ok ? 1 : 0;   // Resultado
    report[34] = destId;        // Node ID destino del comando

    return _hid.sendReport(0, report, sizeof(report));
}

// ── sendStatus() ──────────────────────────────────────────────────────────────
// Enviar mensajes de estado o eventos JSON (ej. pairing_timeout) al HUB usando flag 0x03
void HIDTransport::sendStatus(const char* msg) {
    if (!_hid.ready() || !msg) return;
    size_t len = strlen(msg);
    size_t offset = 0;
    while (offset < len || len == 0) {
        uint8_t report[64] = {0};
        report[32] = 0x03; // Flag 0x03: STATUS / EVENTO
        
        size_t remaining = len - offset;
        size_t part1 = remaining < 32 ? remaining : 32;
        if (part1 > 0) {
            memcpy(report, msg + offset, part1);
            offset += part1;
            remaining = len - offset;
            if (remaining > 0) {
                size_t part2 = remaining < 31 ? remaining : 31;
                memcpy(&report[33], msg + offset, part2);
                offset += part2;
            }
        }
        _hid.sendReport(0, report, sizeof(report));
        if (len == 0 || offset >= len) break;
        delay(3);
    }
}

// ── Callback estático (llamado por TinyUSB en IRQ) ────────────────────────────
void HIDTransport::_onSetReport(uint8_t report_id, hid_report_type_t report_type,
                                  uint8_t const* buffer, uint16_t bufsize) {
    (void)report_id;
    (void)report_type;

    if (bufsize >= sizeof(RFPacket)) {
        memcpy(_rxBuf, buffer, 64 < bufsize ? 64 : bufsize);
        _hasPacket = true;
    }
}

#endif // IS_RP2040 && USE_TINYUSB
