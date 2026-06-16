#ifndef FONT_PORT_H
#define FONT_PORT_H

/**
 * @file FontPort.h
 * @brief Sub-módulo para portar fuentes externas al formato de Adafruit GFX.
 *
 * Adafruit GFX usa el formato GFXfont (estructura con bitmap, glyph array,
 * y metadata). Este archivo provee:
 *   1. Declaraciones de fuentes incluidas en el proyecto
 *   2. Un helper para seleccionar fuentes según tamaño requerido
 *   3. Documentación del proceso para agregar nuevas fuentes
 *
 * ─── Cómo agregar una fuente nueva ──────────────────────────────────────────
 *
 * 1. Convertir la fuente usando la herramienta online:
 *    https://rop.nl/truetype2gfx/
 *    O el script Python de Adafruit:
 *    https://github.com/adafruit/Adafruit-GFX-Library/tree/master/fontconvert
 *
 * 2. Guardar el archivo .h generado en la carpeta:
 *    modules/display/fonts/
 *
 * 3. Incluirlo aquí y agregar una entrada en FontId.
 *
 * ─── Cómo usar en UILayout ───────────────────────────────────────────────────
 *
 * // Obtener la fuente por ID
 * const GFXfont* font = FontPort::get(FontPort::FONT_SMALL);
 *
 * // Aplicar al driver Adafruit directamente (solo para texto custom)
 * ssd1306Driver.raw().setFont(font);
 * ssd1306Driver.raw().setTextSize(1);
 * ssd1306Driver.raw().setCursor(x, y);
 * ssd1306Driver.raw().print("Texto custom");
 * ssd1306Driver.raw().setFont(nullptr); // restaurar fuente default
 */

#include <Adafruit_GFX.h>

// ─────────────────────────────────────────────────────────────────────────────
// Incluir fuentes personalizadas aquí (descomenta cuando las agregues):
// ─────────────────────────────────────────────────────────────────────────────

// #include "FreeSans9pt7b.h"       // Fuente sans-serif 9pt
// #include "FreeSansBold12pt7b.h"  // Fuente sans-serif negrita 12pt
// #include "TomThumb.h"            // Fuente pixel-art ultra pequeña (3×5)
// #include "FreeMonoBold9pt7b.h"   // Fuente monospaced negrita 9pt

class FontPort {
public:

    /** @brief Identificadores de fuentes disponibles en el proyecto. */
    enum FontId {
        FONT_DEFAULT = 0,  // Fuente built-in de Adafruit GFX (5×7 bitmap)
        FONT_SMALL,        // Fuente pequeña (ej: TomThumb 3×5) — requiere incluir archivo
        FONT_MEDIUM,       // Fuente mediana (ej: FreeSans9pt7b)
        FONT_LARGE,        // Fuente grande (ej: FreeSansBold12pt7b)
        FONT_MONO,         // Fuente monospaced (ej: FreeMonoBold9pt7b)
    };

    /**
     * @brief Retorna el puntero a la GFXfont correspondiente al ID dado.
     * @param id  Identificador de fuente (FontId)
     * @return    Puntero a GFXfont, o nullptr para la fuente built-in default
     */
    static const GFXfont* get(FontId id) {
        switch (id) {
            case FONT_DEFAULT: return nullptr;  // nullptr = fuente built-in GFX
            // case FONT_SMALL:   return &TomThumb;
            // case FONT_MEDIUM:  return &FreeSans9pt7b;
            // case FONT_LARGE:   return &FreeSansBold12pt7b;
            // case FONT_MONO:    return &FreeMonoBold9pt7b;
            default:           return nullptr;
        }
    }

    /**
     * @brief Retorna la altura aproximada en píxeles de una fuente.
     * Útil para calcular posiciones Y en UILayout.
     * @param id  Identificador de fuente
     * @return    Altura en píxeles (aproximada)
     */
    static uint8_t height(FontId id) {
        switch (id) {
            case FONT_DEFAULT: return 8;
            case FONT_SMALL:   return 6;
            case FONT_MEDIUM:  return 13;
            case FONT_LARGE:   return 17;
            case FONT_MONO:    return 13;
            default:           return 8;
        }
    }
};

#endif // FONT_PORT_H
