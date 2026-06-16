#ifndef ITRANSPORT_H
#define ITRANSPORT_H

/**
 * @file ITransport.h
 * @brief Interfaz abstracta de transporte de paquetes entre el translator y el HUB.
 *
 * Define el contrato para enviar y recibir RFPacket entre el firmware del translator
 * y el HUB (o cualquier host). Las implementaciones concretas son:
 *   - SerialTransport  → JSON sobre puerto Serial (ESP8266, Arduino, ESP32)
 *   - HIDTransport     → Binario sobre USB HID (RP2040 con TinyUSB)
 *
 * El código del translator trabaja SOLO con ITransport*, nunca con las
 * implementaciones concretas. La selección se hace en main.cpp según #ifdef.
 */

#include "protocol/Protocol.h"

class ITransport {
public:
    virtual ~ITransport() {}

    /**
     * @brief Inicializa el canal de transporte.
     * En SerialTransport: configura baud rate y envía mensaje de listo.
     * En HIDTransport: configura descriptores USB, registra callbacks, espera mount.
     * @return true si la inicialización fue exitosa
     */
    virtual bool begin() = 0;

    /**
     * @brief Verifica si hay datos disponibles para leer del host.
     * @return true si hay un paquete completo listo para leer
     */
    virtual bool available() = 0;

    /**
     * @brief Lee el siguiente paquete del host y lo decodifica a RFPacket.
     * En SerialTransport: parsea el JSON de Serial y llena la estructura.
     * En HIDTransport: copia el buffer binario HID al RFPacket.
     * @param pkt  Referencia al paquete donde se escriben los datos
     * @return true si se leyó y decodificó un paquete válido
     */
    virtual bool readPacket(RFPacket& pkt) = 0;

    /**
     * @brief Envía un paquete RF al host (HUB).
     * En SerialTransport: serializa a JSON y lo envía por Serial.
     * En HIDTransport: empaqueta en un HID report y lo envía.
     * @param pkt  Paquete a enviar
     * @return true si el envío fue exitoso
     */
    virtual bool sendPacket(const RFPacket& pkt) = 0;

    /**
     * @brief Envía una confirmación (ACK) al host sobre un comando recibido.
     * @param ok     true = éxito, false = fallo
     * @param destId Node ID del nodo destino (informativo, para el HUB)
     */
    virtual bool sendAck(bool ok, uint8_t destId = 0) = 0;

    /**
     * @brief Envía un mensaje de estado/log al host (opcional, sin bloquear).
     * En HID puede ser ignorado si no hay canal de log.
     * @param msg  Cadena de texto null-terminated
     */
    virtual void sendStatus(const char* msg) = 0;
};

#endif // ITRANSPORT_H
