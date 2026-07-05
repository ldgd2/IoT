#include "display/render/Renderer.h"
#include <string.h>

Renderer::Renderer(IDisplay& display) : _display(display) {}

void Renderer::text(int16_t x, int16_t y, const char* str, uint8_t size) {
    _display.drawText(x, y, str, COLOR_ON, size);
}

void Renderer::textCentered(int16_t y, const char* str, uint8_t size) {
    int16_t charW  = _charWidth(size);
    int16_t strLen = (int16_t)strlen(str);
    int16_t totalW = strLen * charW;
    int16_t x      = (_display.getWidth() - totalW) / 2;
    if (x < 0) x = 0;
    _display.drawText(x, y, str, COLOR_ON, size);
}

void Renderer::textWrapped(int16_t x, int16_t y, int16_t w,
                            const char* str, uint8_t size) {
    int16_t charW  = _charWidth(size);
    int16_t charH  = _charHeight(size);
    int16_t charsPerLine = w / charW;
    if (charsPerLine <= 0) return;

    int16_t curX = x;
    int16_t curY = y;

    for (const char* p = str; *p; ) {
        // Contar cuántos chars caben en la línea actual
        int16_t remaining = (int16_t)strlen(p);
        int16_t n = (remaining < charsPerLine) ? remaining : charsPerLine;

        // Intentar cortar en espacio para no partir palabras
        if (remaining > charsPerLine) {
            int16_t cut = n;
            while (cut > 0 && p[cut] != ' ') cut--;
            if (cut > 0) n = cut;
        }

        // Dibujar segmento
        char buf[32];
        if (n >= (int16_t)sizeof(buf)) n = (int16_t)sizeof(buf) - 1;
        memcpy(buf, p, n);
        buf[n] = '\0';
        _display.drawText(curX, curY, buf, COLOR_ON, size);

        p += n;
        if (*p == ' ') p++; // saltar espacio de corte
        curY += charH + 1;

        // Salir si nos pasamos del display
        if (curY >= _display.getHeight()) break;
    }
}

void Renderer::hRule(int16_t y) {
    _display.drawHLine(0, y, _display.getWidth(), COLOR_ON);
}

void Renderer::progressBar(int16_t x, int16_t y, int16_t w, int16_t h, uint8_t pct) {
    if (pct > 100) pct = 100;
    _display.drawRect(x, y, w, h, COLOR_ON);
    int16_t filled = (int16_t)((int32_t)w * pct / 100);
    if (filled > 2) {
        _display.fillRect(x + 1, y + 1, filled - 2, h - 2, COLOR_ON);
    }
}

void Renderer::rect(int16_t x, int16_t y, int16_t w, int16_t h) {
    _display.drawRect(x, y, w, h, COLOR_ON);
}

void Renderer::fillRect(int16_t x, int16_t y, int16_t w, int16_t h) {
    _display.fillRect(x, y, w, h, COLOR_ON);
}

void Renderer::circle(int16_t x0, int16_t y0, int16_t r) {
    int16_t f = 1 - r;
    int16_t ddF_x = 1;
    int16_t ddF_y = -2 * r;
    int16_t x = 0;
    int16_t y = r;

    _display.drawPixel(x0, y0 + r, COLOR_ON);
    _display.drawPixel(x0, y0 - r, COLOR_ON);
    _display.drawPixel(x0 + r, y0, COLOR_ON);
    _display.drawPixel(x0 - r, y0, COLOR_ON);

    while (x < y) {
        if (f >= 0) {
            y--;
            ddF_y += 2;
            f += ddF_y;
        }
        x++;
        ddF_x += 2;
        f += ddF_x;

        _display.drawPixel(x0 + x, y0 + y, COLOR_ON);
        _display.drawPixel(x0 - x, y0 + y, COLOR_ON);
        _display.drawPixel(x0 + x, y0 - y, COLOR_ON);
        _display.drawPixel(x0 - x, y0 - y, COLOR_ON);
        _display.drawPixel(x0 + y, y0 + x, COLOR_ON);
        _display.drawPixel(x0 - y, y0 + x, COLOR_ON);
        _display.drawPixel(x0 + y, y0 - x, COLOR_ON);
        _display.drawPixel(x0 - y, y0 - x, COLOR_ON);
    }
}

void Renderer::icon8x8(int16_t x, int16_t y, const uint8_t bmp[8]) {
    for (int16_t row = 0; row < 8; row++) {
        uint8_t line = bmp[row];
        for (int16_t col = 0; col < 8; col++) {
            if (line & (0x80 >> col)) {
                _display.drawPixel(x + col, y + row, COLOR_ON);
            }
        }
    }
}

void Renderer::clear() {
    _display.clear();
}

void Renderer::flush() {
    _display.commit();
}
