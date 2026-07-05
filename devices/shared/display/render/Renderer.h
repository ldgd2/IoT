#ifndef RENDERER_H
#define RENDERER_H

/**
 * @file Renderer.h
 * @brief Sub-módulo de renderizado. Puede dibujar cualquier cosa sobre IDisplay.
 *
 * El Renderer trabaja con IDisplay* y no conoce el hardware específico.
 * Provee primitivas de alto nivel (barras de progreso, separadores, iconos,
 * texto multilínea con wrap) encima de las primitivas básicas del driver.
 *
 * El UILayout usa el Renderer para componer pantallas completas.
 * El Renderer no sabe nada de "pantalla de status" o "pantalla de actividad";
 * solo sabe dibujar formas y texto en posiciones arbitrarias.
 */

#include "../core/IDisplay.h"
#include <stdint.h>

// Colores para display monocromo (compatibles con IDisplay)
#define COLOR_OFF    0
#define COLOR_ON     1

class Renderer {
public:
    /**
     * @param display  Referencia al driver de display (IDisplay*)
     */
    explicit Renderer(IDisplay& display);

    // ── Texto ────────────────────────────────────────────────────────────────

    /**
     * @brief Dibuja texto en una posición. size=1: char = 6×8px, size=2: 12×16px.
     */
    void text(int16_t x, int16_t y, const char* str, uint8_t size = 1);

    /**
     * @brief Dibuja texto centrado horizontalmente en la fila y dada.
     * @param y     Posición Y
     * @param str   Cadena a dibujar
     * @param size  Escala del texto
     */
    void textCentered(int16_t y, const char* str, uint8_t size = 1);

    /**
     * @brief Dibuja texto con wrap automático en un área rectangular.
     * @param x, y    Posición inicial
     * @param w       Ancho máximo en píxeles
     * @param str     Cadena a dibujar (se corta si supera el área)
     * @param size    Escala del texto
     */
    void textWrapped(int16_t x, int16_t y, int16_t w,
                     const char* str, uint8_t size = 1);

    // ── Formas ───────────────────────────────────────────────────────────────

    /**
     * @brief Dibuja una línea horizontal separadora de ancho completo.
     * @param y  Posición Y de la línea
     */
    void hRule(int16_t y);

    /**
     * @brief Dibuja una barra de progreso.
     * @param x, y    Posición superior-izquierda
     * @param w, h    Ancho y alto de la barra
     * @param pct     Porcentaje de relleno (0-100)
     */
    void progressBar(int16_t x, int16_t y, int16_t w, int16_t h, uint8_t pct);

    /**
     * @brief Dibuja un rectángulo simple (solo borde).
     */
    void rect(int16_t x, int16_t y, int16_t w, int16_t h);

    /**
     * @brief Dibuja un rectángulo relleno.
     */
    void fillRect(int16_t x, int16_t y, int16_t w, int16_t h);

    /**
     * @brief Dibuja un círculo de radio r (algoritmo de Bresenham).
     */
    void circle(int16_t x0, int16_t y0, int16_t r);

    // ── Iconos (bitmaps simples) ─────────────────────────────────────────────

    /**
     * @brief Dibuja un bitmap monocromo de 8×8 px.
     * @param x, y  Posición
     * @param bmp   Array de 8 bytes, cada byte = una fila de 8 píxeles (bit 7=izq)
     */
    void icon8x8(int16_t x, int16_t y, const uint8_t bmp[8]);

    // ── Control del framebuffer ──────────────────────────────────────────────

    /** @brief Limpia el framebuffer (fondo negro). */
    void clear();

    /** @brief Envía el framebuffer al display físico. */
    void flush();

    IDisplay& getDisplay() { return _display; }

private:
    IDisplay& _display;

    // Ancho de un carácter en píxeles según escala (fuente GFX 6px por defecto)
    static int16_t _charWidth(uint8_t size)  { return 6 * size; }
    static int16_t _charHeight(uint8_t size) { return 8 * size; }
};

#endif // RENDERER_H
