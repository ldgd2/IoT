#ifndef IDISPLAY_H
#define IDISPLAY_H

/**
 * @file IDisplay.h
 * @brief Interfaz abstracta pura de display.
 *
 * Define el contrato mínimo que cualquier driver de pantalla debe implementar.
 * El módulo Renderer trabaja ÚNICAMENTE con IDisplay*, sin conocer el hardware.
 *
 * Coordenadas: (0,0) = esquina superior izquierda.
 * Colores: 0 = apagado/negro, 1 = encendido/blanco (para OLED monocromo).
 * En pantallas a color, el driver traduce 0→negro, 1→color primario.
 *
 * Flujo de uso:
 *   1. Llamar a los métodos de dibujo (drawText, drawRect, etc.)
 *   2. Llamar a commit() para enviar el framebuffer al display físico.
 *      (Sin commit(), los cambios solo están en buffer, no se ven.)
 */

#include <stdint.h>

class IDisplay {
public:
    virtual ~IDisplay() {}

    // ── Ciclo de vida ────────────────────────────────────────────────────────

    /**
     * @brief Inicializa el hardware del display.
     * @return true si la inicialización fue exitosa
     */
    virtual bool init() = 0;

    /**
     * @brief Envía el framebuffer al display físico.
     * Llamar después de todas las operaciones de dibujo.
     */
    virtual void commit() = 0;

    /**
     * @brief Limpia el framebuffer (pone todo en negro/off).
     * Requiere commit() para que se vea en el display.
     */
    virtual void clear() = 0;

    // ── Primitivas de dibujo ─────────────────────────────────────────────────

    /**
     * @brief Dibuja un píxel.
     * @param x, y  Coordenadas
     * @param color 0=apagado, 1=encendido
     */
    virtual void drawPixel(int16_t x, int16_t y, uint16_t color) = 0;

    /**
     * @brief Dibuja una línea horizontal.
     */
    virtual void drawHLine(int16_t x, int16_t y, int16_t w, uint16_t color) = 0;

    /**
     * @brief Dibuja una línea vertical.
     */
    virtual void drawVLine(int16_t x, int16_t y, int16_t h, uint16_t color) = 0;

    /**
     * @brief Dibuja un rectángulo (solo borde).
     */
    virtual void drawRect(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t color) = 0;

    /**
     * @brief Dibuja un rectángulo relleno.
     */
    virtual void fillRect(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t color) = 0;

    /**
     * @brief Dibuja un carácter en la posición indicada.
     * @param x, y     Posición superior-izquierda del carácter
     * @param c        Carácter ASCII
     * @param color    Color del texto
     * @param bg       Color de fondo (0 = transparente en OLED)
     * @param size     Escala (1=normal, 2=doble, etc.)
     */
    virtual void drawChar(int16_t x, int16_t y, char c,
                          uint16_t color, uint16_t bg, uint8_t size) = 0;

    /**
     * @brief Dibuja una cadena de texto.
     * @param x, y   Posición inicial
     * @param text   Cadena null-terminated
     * @param color  Color del texto
     * @param size   Escala del texto
     */
    virtual void drawText(int16_t x, int16_t y, const char* text,
                          uint16_t color, uint8_t size = 1) = 0;

    // ── Información del display ──────────────────────────────────────────────

    /** @brief Ancho del display en píxeles. */
    virtual int16_t getWidth()  const = 0;

    /** @brief Alto del display en píxeles. */
    virtual int16_t getHeight() const = 0;
};

#endif // IDISPLAY_H
