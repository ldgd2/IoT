#ifndef HID_TRANSPORT_H
#define HID_TRANSPORT_H

/**
 * @file HIDTransport.h
 * @brief ITransport sobre USB HID — binario directo para RP2040 (TinyUSB).
 *
 * Protocolo HID de comunicación con el HUB:
 *
 * ── Formato de report (64 bytes) ────────────────────────────────────────────
 * Byte 0..31  → RFPacket (32 bytes empaquetados, memcpy directo)
 * Byte 32     → Flags: bit0=válido, bit1=checksum_ok
 * Byte 33..63 → Reservado (cero)
 *
 * ── Recepción (host → HID IN report) ────────────────────────────────────────
 * El HUB escribe un HID report de 64 bytes con el RFPacket
 * en los primeros 32 bytes. El callback set_report_callback lo recibe.
 *
 * ── Envío (HID OUT report → host) ───────────────────────────────────────────
 * El translator llama a sendPacket() que envía un HID report de 64 bytes.
 * El byte 32 indica si el paquete es un RFPacket entrante (flags=0x01)
 * o un ACK de un comando enviado (flags=0x02).
 *
 * ── Ventajas sobre Serial ─────────────────────────────────────────────────
 * - No requiere driver en el host (HID es plug-and-play)
 * - Latencia < 1ms (USB bulk polling a 1000Hz)
 * - Sin overhead de parseo JSON
 * - El HUB usa `hid` library o `pyusb` para interactuar
 *
 * Solo disponible en IS_RP2040 con USE_TINYUSB.
 */

#include "../ITransport.h"

#if defined(IS_RP2040) && defined(USE_TINYUSB)

#include <Adafruit_TinyUSB.h>
#include <string.h>

// Descriptor HID: reporte genérico IN/OUT de 64 bytes
// Compatible con el descriptor usado por el HUB
static const uint8_t HID_TRANSPORT_DESC[] = {
    TUD_HID_REPORT_DESC_GENERIC_INOUT(64)
};

class HIDTransport : public ITransport {
public:
    HIDTransport();

    bool begin() override;
    bool available() override;
    bool readPacket(RFPacket& pkt) override;
    bool sendPacket(const RFPacket& pkt) override;
    bool sendAck(bool ok, uint8_t destId = 0) override;
    void sendStatus(const char* msg) override;

    // Callback interno — llamado por TinyUSB cuando llega un report del host
    // Debe ser estático para poder registrarse como callback C
    static void _onSetReport(uint8_t report_id, hid_report_type_t report_type,
                              uint8_t const* buffer, uint16_t bufsize);

private:
    Adafruit_USBD_HID _hid;

    // Buffer del paquete más reciente recibido vía HID
    static bool     _hasPacket;
    static uint8_t  _rxBuf[64];
};

#else

// ── Stub para plataformas sin TinyUSB ────────────────────────────────────────
// Permite incluir HIDTransport.h sin errores de compilación en ESP8266/ESP32.
// El main.cpp selecciona SerialTransport en esas plataformas.
#include "../ITransport.h"

class HIDTransport : public ITransport {
public:
    bool begin() override                            { return false; }
    bool available() override                        { return false; }
    bool readPacket(RFPacket&) override              { return false; }
    bool sendPacket(const RFPacket&) override        { return false; }
    bool sendAck(bool, uint8_t = 0) override         { return false; }
    void sendStatus(const char*) override            {}
};

#endif // IS_RP2040 && USE_TINYUSB

#endif // HID_TRANSPORT_H
