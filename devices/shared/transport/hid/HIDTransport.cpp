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
    // Descriptores USB: fabricante, producto, VID/PID
    TinyUSBDevice.setManufacturerDescriptor("Gerlex");
    TinyUSBDevice.setProductDescriptor("IoT RF Gateway");
    TinyUSBDevice.setID(0x1234, 0x5678);

    // Registrar callback de recepción de reports del host
    _hid.setReportCallback(NULL, _onSetReport);
    _hid.begin();

    // Esperar a que el host monte el dispositivo USB (max 5s)
    unsigned long t = millis();
    while (!TinyUSBDevice.mounted() && (millis() - t < 5000)) {
        delay(10);
    }

    return TinyUSBDevice.mounted();
}

// ── available() ──────────────────────────────────────────────────────────────
bool HIDTransport::available() {
    return _hasPacket;
}

// ── readPacket() ──────────────────────────────────────────────────────────────
bool HIDTransport::readPacket(RFPacket& pkt) {
    if (!_hasPacket) return false;
    _hasPacket = false;

    if (sizeof(RFPacket) > 64) return false; // Sanity check

    memcpy(&pkt, _rxBuf, sizeof(RFPacket));

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
// En HID no hay canal de log separado; los status se ignoran silenciosamente.
// Para debug usar el Serial monitor si está disponible.
void HIDTransport::sendStatus(const char* msg) {
    (void)msg; // HID no tiene canal de texto
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
