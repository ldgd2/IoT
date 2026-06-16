#ifndef UI_LAYOUT_H
#define UI_LAYOUT_H

/**
 * @file UILayout.h
 * @brief Sub-módulo de interfaces y layouts de pantalla.
 *
 * Compone pantallas completas usando el Renderer. Cada método `draw*`
 * construye un layout específico de la interfaz del translator/gateway.
 *
 * UILayout no conoce nada del hardware, ni de Adafruit, ni de SSD1306.
 * Solo habla con Renderer. Si se cambia el display hardware, UILayout
 * no necesita ningún cambio.
 *
 * Layouts disponibles:
 *   - StatusScreen   → Estado general del gateway (status, nodos, colmena)
 *   - ActivityScreen → Última actividad RF (tx/rx, nodo, resultado)
 *   - BootScreen     → Pantalla de arranque con nombre del sistema
 *   - ErrorScreen    → Pantalla de error con mensaje
 */

#include "../render/Renderer.h"
#include <stdint.h>

class UILayout {
public:
    explicit UILayout(Renderer& renderer);

    /**
     * @brief Pantalla principal: estado del gateway, nodos y nombre de colmena.
     *
     * Layout (128×64, tamaño 1 = char 6×8px):
     *   [0]   "Colmena IoT"       (título, centrado, size=1)
     *   [9]   ──────────────────  (separador)
     *   [12]  "Est: <status>"     (estado actual)
     *   [22]  "Nodos: <N>"        (nodos conectados)
     *   [32]  "Red: <name>"       (nombre de colmena)
     *   [42]  ──────────────────  (separador)
     *   [45]  "Act: <activity>"   (última actividad, wrapeada)
     *
     * @param status    Cadena de estado (max ~14 chars para caber en pantalla)
     * @param nodeCount Número de nodos conectados al mesh
     * @param colmenaName Nombre de la colmena
     * @param lastActivity Descripción de la última acción RF
     */
    void drawStatusScreen(const char* status, uint8_t nodeCount,
                          const char* colmenaName, const char* lastActivity);

    /**
     * @brief Pantalla de arranque con logo/nombre del sistema.
     * Se muestra durante el boot antes de que la red esté activa.
     *
     * @param title    Nombre del sistema (ej: "Colmena IoT")
     * @param subtitle Subtítulo (ej: "Gateway v1.0")
     * @param status   Estado del boot (ej: "Iniciando...")
     */
    void drawBootScreen(const char* title, const char* subtitle, const char* status);

    /**
     * @brief Pantalla de error.
     * @param errorCode Código de error (ej: "E_RADIO")
     * @param detail    Descripción del error (se wrapea si es largo)
     */
    void drawErrorScreen(const char* errorCode, const char* detail);

    /**
     * @brief Barra de estado mínima en la parte inferior de la pantalla.
     * Puede superponerse a cualquier otro layout.
     * @param msg   Mensaje corto (max ~21 chars a size=1)
     */
    void drawStatusBar(const char* msg);

private:
    Renderer& _r;
};

#endif // UI_LAYOUT_H
