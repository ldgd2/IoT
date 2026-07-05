#ifndef SSD1306_DRIVER_H
#define SSD1306_DRIVER_H

/**
 * @file SSD1306Driver.h
 * @brief Driver concreto para OLED SSD1306 usando Adafruit SSD1306.
 *
 * Implementa IDisplay sobre la biblioteca Adafruit_SSD1306.
 * Este es el ÚNICO archivo que conoce de Adafruit. El resto del sistema
 * de display (Renderer, UILayout) trabaja con IDisplay*.
 *
 * Para cambiar a otro display (SH1106, ST7735, ePaper, etc.):
 *   → Crear un nuevo driver que implemente IDisplay
 *   → El Renderer y UILayout no necesitan cambios
 */

#include "display/core/IDisplay.h"
#include "PinConfig.h"   // Aportado por el dispositivo vía include_dirs en platformio.ini
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

class SSD1306Driver : public IDisplay {
public:
    /**
     * @param width   Ancho del display en píxeles (default: OLED_WIDTH de PinConfig)
     * @param height  Alto del display en píxeles (default: OLED_HEIGHT de PinConfig)
     */
    SSD1306Driver(uint8_t width = OLED_WIDTH, uint8_t height = OLED_HEIGHT)
        : _display(width, height, &Wire, -1), _w(width), _h(height) {}

    bool init() override {
        // Retardo vital en el arranque para estabilizar la alimentación y el charge-pump
        // del display OLED en placas como YD-RP2040 / Raspberry Pi Pico
        delay(300);

        // Inicializar bus I2C con pines de PinConfig si están definidos
#if defined(OLED_SDA) && defined(OLED_SCL)
    #if defined(IS_RP2040)
        Wire.setSDA(OLED_SDA);
        Wire.setSCL(OLED_SCL);
        Wire.begin();
    #else
        Wire.begin(OLED_SDA, OLED_SCL);
    #endif
#else
        Wire.begin();
#endif
        Wire.setClock(400000); // I2C a 400kHz para animaciones fluidas a tiempo real

        // Intentar dirección por defecto (0x3C) y respaldo (0x3D)
        if (!_display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
            if (!_display.begin(SSD1306_SWITCHCAPVCC, 0x3D)) {
                return false;
            }
        }
        _display.clearDisplay();
        _display.display();
        return true;
    }

    void commit() override {
        _display.display();
    }

    void clear() override {
        _display.clearDisplay();
    }

    void drawPixel(int16_t x, int16_t y, uint16_t color) override {
        _display.drawPixel(x, y, color ? SSD1306_WHITE : SSD1306_BLACK);
    }

    void drawHLine(int16_t x, int16_t y, int16_t w, uint16_t color) override {
        _display.drawFastHLine(x, y, w, color ? SSD1306_WHITE : SSD1306_BLACK);
    }

    void drawVLine(int16_t x, int16_t y, int16_t h, uint16_t color) override {
        _display.drawFastVLine(x, y, h, color ? SSD1306_WHITE : SSD1306_BLACK);
    }

    void drawRect(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t color) override {
        _display.drawRect(x, y, w, h, color ? SSD1306_WHITE : SSD1306_BLACK);
    }

    void fillRect(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t color) override {
        _display.fillRect(x, y, w, h, color ? SSD1306_WHITE : SSD1306_BLACK);
    }

    void drawChar(int16_t x, int16_t y, char c,
                  uint16_t color, uint16_t bg, uint8_t size) override {
        _display.setTextSize(size);
        _display.setTextColor(color ? SSD1306_WHITE : SSD1306_BLACK,
                               bg   ? SSD1306_WHITE : SSD1306_BLACK);
        _display.setCursor(x, y);
        _display.print(c);
    }

    void drawText(int16_t x, int16_t y, const char* text,
                  uint16_t color, uint8_t size = 1) override {
        _display.setTextSize(size);
        _display.setTextColor(color ? SSD1306_WHITE : SSD1306_BLACK);
        _display.setCursor(x, y);
        _display.print(text);
    }

    int16_t getWidth()  const override { return _w; }
    int16_t getHeight() const override { return _h; }

    // Acceso directo al objeto Adafruit (para compatibilidad con fuentes GFX custom)
    Adafruit_SSD1306& raw() { return _display; }

private:
    Adafruit_SSD1306 _display;
    uint8_t          _w, _h;
};

#endif // SSD1306_DRIVER_H
