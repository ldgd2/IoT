#ifndef PROTOCOL_H
#define PROTOCOL_H

/**
 * @file Protocol.h
 * @brief Protocolo RF base — Compartido entre TODOS los dispositivos de la colmena.
 *
 * Define la estructura RFPacket que todos los nodos (lights, sensors, translator/gateway)
 * usan para comunicarse. Cada dispositivo puede extender la semántica del campo `data[]`
 * a través de ProtocolExt.h, pero el header del paquete es siempre igual.
 *
 * Compatibilidad: ESP32, ESP8266, YD-RP2040, Raspberry Pi Pico, Arduino AVR
 */

#include <stdint.h>

// ─── Comandos Universales ────────────────────────────────────────────────────
// Todos los nodos deben reconocer y responder a estos comandos.
#define CMD_ON          0x01   // Encender / activar
#define CMD_OFF         0x02   // Apagar / desactivar
#define CMD_REPORT      0x03   // Solicitar reporte de estado
#define CMD_HEARTBEAT   0x04   // Latido periódico de presencia
#define CMD_DISCOVER    0x05   // Anuncio de auto-descubrimiento al master
#define CMD_TOGGLE      0x06   // Invertir estado actual
#define CMD_CONFIG_SYNC 0x07   // Sincronización de parámetros de colmena
#define CMD_ACK         0x08   // Confirmación de recepción
#define CMD_ON_ALL      0x09   // Encender todos los canales/relays
#define CMD_OFF_ALL     0x0A   // Apagar todos los canales/relays
#define CMD_SET_MASK    0x0B   // Configurar mascara de bits directa

// ─── Tipos de dispositivo y Feature Flags ────────────────────────────────────
// Movidos a DeviceTypes.h para mejor organización y extensibilidad.
// Incluir DeviceTypes.h da acceso a DEV_*, FEAT_* y las macros de utilidad.
#include "protocol/DeviceTypes.h"

// ─── Direcciones Especiales ───────────────────────────────────────────────────
#define ADDR_MASTER     0x00   // Nodo master (translator/gateway)
#define ADDR_BROADCAST  0xFF   // Broadcast a todos los nodos


// ─── Estructura Base del Paquete RF ──────────────────────────────────────────
// Carga máxima del nRF24L01 = 32 bytes. Esta estructura ocupa exactamente 32 bytes.
// __attribute__((packed)) elimina padding del compilador para garantizar el tamaño.
struct __attribute__((packed)) RFPacket {
    // ── Header (4 bytes) ──────────────────────────────────────────────────────
    uint8_t  originId;     // Node ID del remitente (1-254)
    uint8_t  destId;       // Node ID del destinatario (0=master, 0xFF=broadcast)
    uint8_t  deviceType;   // Tipo de dispositivo (DEV_TYPE_*)
    uint8_t  command;      // Comando (CMD_*)

    // ── Body (26 bytes) ───────────────────────────────────────────────────────
    // El significado de data[] varía según el comando y el tipo de dispositivo.
    // Ver ProtocolExt.h para helpers de lectura/escritura por caso de uso.
    uint8_t  data[26];

    // ── Checksum (2 bytes) ────────────────────────────────────────────────────
    // CRC16 del header + body. Calculado con Protocol_checksum().
    // Nota: el campo checksum en sí se excluye del cálculo.
    uint16_t checksum;
};

// ─── Utilidades de Protocolo ─────────────────────────────────────────────────

/**
 * @brief Calcula el checksum CRC16 de un paquete.
 *
 * Calcula CRC16-CCITT sobre los primeros 30 bytes del paquete (header + body),
 * excluyendo el campo checksum. Usar antes de enviar y al recibir para validar.
 *
 * @param pkt Puntero al paquete
 * @return uint16_t Checksum calculado
 */
inline uint16_t Protocol_calcChecksum(const RFPacket* pkt) {
    uint16_t crc = 0xFFFF;
    const uint8_t* buf = reinterpret_cast<const uint8_t*>(pkt);
    // Procesar los primeros 30 bytes (excluir los 2 bytes de checksum al final)
    for (uint8_t i = 0; i < sizeof(RFPacket) - 2; i++) {
        crc ^= (uint16_t)buf[i] << 8;
        for (uint8_t j = 0; j < 8; j++) {
            crc = (crc & 0x8000) ? (crc << 1) ^ 0x1021 : (crc << 1);
        }
    }
    return crc;
}

/**
 * @brief Inicializa un paquete con valores base.
 * Pone a cero el campo data[] y el checksum antes de usar.
 */
inline void Protocol_initPacket(RFPacket* pkt, uint8_t originId, uint8_t destId,
                                  uint8_t deviceType, uint8_t command) {
    pkt->originId   = originId;
    pkt->destId     = destId;
    pkt->deviceType = deviceType;
    pkt->command    = command;
    for (uint8_t i = 0; i < 26; i++) pkt->data[i] = 0;
    pkt->checksum   = 0;
}

/**
 * @brief Sella el paquete calculando y guardando el checksum.
 * Llamar justo antes de enviar.
 */
inline void Protocol_seal(RFPacket* pkt) {
    pkt->checksum = Protocol_calcChecksum(pkt);
}

/**
 * @brief Verifica si el paquete recibido es válido (checksum correcto).
 * @return true si el paquete es válido
 */
inline bool Protocol_verify(const RFPacket* pkt) {
    return pkt->checksum == Protocol_calcChecksum(pkt);
}

#endif // PROTOCOL_H
