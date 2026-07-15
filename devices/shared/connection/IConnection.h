#ifndef ICONNECTION_H
#define ICONNECTION_H

/**
 * @file IConnection.h
 * @brief Interfaz abstracta de conectividad — módulo compartido (shared/).
 *
 * Define el contrato que cualquier medio de conexión debe cumplir.
 * MeshConnection (RF24Mesh) implementa esta interfaz para nodos leaf.
 * MasterMeshConnection la implementa para el nodo master.
 * Futuras implementaciones: WiFiConnection, BLEConnection, etc.
 *
 * Los módulos de nivel superior (ColmenaNode, ColmenaMaster, main.cpp)
 * trabajan SOLO con IConnection*, nunca con implementaciones concretas.
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include <stdint.h>
#include <stddef.h>

class IConnection {
public:
    virtual ~IConnection() {}

    /**
     * @brief Inicializa el hardware de conectividad.
     * Configura pines, inicia librerías, establece parámetros de red.
     * Los parámetros (canal RF, datarate, etc.) vienen de RadioConfig.h del dispositivo.
     * @return true si la inicialización fue exitosa
     */
    virtual bool begin() = 0;

    /**
     * @brief Mantenimiento periódico de la conexión.
     * Debe llamarse en cada iteración del loop(). Gestiona keep-alive,
     * renovación de dirección, procesamiento interno de la pila de red.
     */
    virtual void update() = 0;

    /**
     * @brief Envía un bloque de datos a un nodo destino.
     * @param data    Puntero al buffer de datos a enviar
     * @param len     Tamaño del buffer en bytes
     * @param destId  Node ID destino (ADDR_BROADCAST = 0xFF para todos)
     * @return true si el envío fue confirmado (ACK recibido por la red)
     */
    virtual bool send(const void* data, size_t len, uint8_t destId) = 0;

    /**
     * @brief Lee el siguiente paquete del buffer de recepción.
     * Llamar solo cuando available() retorna true.
     * @param buf  Buffer donde escribir los datos recibidos
     * @param len  Tamaño máximo a leer en bytes
     * @return true si se leyó correctamente al menos un byte
     */
    virtual bool receive(void* buf, size_t len) = 0;

    /**
     * @brief Indica si hay paquetes pendientes de leer.
     * @return true si hay al menos un paquete disponible
     */
    virtual bool available() = 0;

    /**
     * @brief Verifica si la conexión con la red está activa.
     * @return true si el nodo está conectado y puede enviar/recibir
     */
    virtual bool isConnected() = 0;

    /**
     * @brief Intenta restablecer una conexión perdida.
     * En RF24Mesh: renueva la dirección DHCP del nodo.
     * @return true si la reconexión fue exitosa
     */
    virtual bool reconnect() = 0;

    /**
     * @brief Retorna el Node ID lógico de este nodo.
     * @return Node ID (0 = master, 1-254 = nodo leaf)
     */
    virtual uint8_t getNodeId() const = 0;

    /**
     * @brief Registra un nodo en la tabla de enrutamiento interna del transporte.
     */
    virtual void registerNodeRoute(uint8_t nodeId, uint16_t address) {}
};

#endif // ICONNECTION_H
