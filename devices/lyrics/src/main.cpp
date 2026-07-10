/**
 * @file main.cpp — lyrics test device
 * @brief Dispositivo de prueba para visualización sincronizada de líricas en pantalla OLED bicolor.
 *
 * - Zona Superior (Amarilla, y=0 a y=15): Tiempo transcurrido y título de la canción.
 * - Zona Inferior (Azul, y=16 a y=63):
 *   * Intro (0 a 21s): Animación de presentación en 4 fases (título, ecualizador, álbum, prepárate).
 *   * Partes instrumentales / pausas ("..."): Animación fluida de ecualizador de ondas musicales.
 *   * Versos: Únicamente el verso actual perfectamente centrado horizontal y verticalmente.
 */

#include <Arduino.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include "PinConfig.h"
#include "LyricsData.h"

#include "display/core/SSD1306Driver.h"
#include "display/render/Renderer.h"

#if defined(IS_RP2040) && defined(USE_TINYUSB)
    #include <Adafruit_TinyUSB.h>
#endif

// ─── Instancias de Pantalla ──────────────────────────────────────────────────
SSD1306Driver displayDriver;
Renderer      renderer(displayDriver);

// ─── Variables de Temporización ──────────────────────────────────────────────
unsigned long songStartTime = 0;
unsigned long lastRenderTime = 0;
int lastPlayedIndex = -1;

/**
 * @brief Dibuja un texto en el área azul (y=16 a y=63) centrado horizontal y verticalmente.
 */
void drawCenteredLyrics(const char* str) {
    char lines[4][22];
    int lineCount = 0;
    
    const char* p = str;
    while (*p && lineCount < 4) {
        int len = strlen(p);
        int n = (len <= 21) ? len : 21;
        
        if (len > 21) {
            int cut = n;
            while (cut > 0 && p[cut] != ' ') cut--;
            if (cut > 0) n = cut;
        }
        
        strncpy(lines[lineCount], p, n);
        lines[lineCount][n] = '\0';
        lineCount++;
        
        p += n;
        if (*p == ' ') p++;
    }
    
    int totalHeight = lineCount * 8 + (lineCount - 1) * 4;
    int startY = 16 + (48 - totalHeight) / 2;
    
    for (int i = 0; i < lineCount; i++) {
        renderer.textCentered(startY + (i * 12), lines[i], 1);
    }
}

/**
 * @brief Dibuja las líricas con efecto máquina de escribir ("typewriter"), armándose letra por letra.
 * Conforme avanza el tiempo de cada palabra, las letras aparecen una por una sincronizadas con la entonación.
 */
void drawSyncedLyrics(const LyricLine& line, unsigned long elapsedMs) {
    if (line.words == nullptr || line.wordCount == 0) {
        drawCenteredLyrics(line.text);
        return;
    }

    // 1. Agrupar palabras en filas (word-wrap hasta 21 caracteres por fila, máximo 4 filas)
    int rowStart[4] = {0};
    int rowEnd[4] = {0};
    int rowLen[4] = {0};
    int rowCount = 0;
    
    int currentLen = 0;
    rowStart[0] = 0;
    
    for (int i = 0; i < line.wordCount; i++) {
        int wLen = (int)strlen(line.words[i].word);
        int needed = (currentLen == 0) ? wLen : (currentLen + 1 + wLen);
        
        if (needed <= 21 || currentLen == 0) {
            currentLen = needed;
            rowEnd[rowCount] = i;
            rowLen[rowCount] = currentLen;
        } else {
            if (rowCount < 3) {
                rowCount++;
                rowStart[rowCount] = i;
                rowEnd[rowCount] = i;
                rowLen[rowCount] = wLen;
                currentLen = wLen;
            } else {
                // Si excede 4 filas, agregamos a la última fila
                rowEnd[rowCount] = i;
                rowLen[rowCount] += 1 + wLen;
            }
        }
    }
    rowCount++;

    // 2. Centrado vertical en la Zona Azul (y = 16 a 63, altura 48px)
    int totalHeight = rowCount * 8 + (rowCount - 1) * 4;
    int startY = 16 + (48 - totalHeight) / 2;

    // 3. Dibujar cada fila centrada horizontalmente, armando letra por letra (tipo máquina de escribir)
    for (int r = 0; r < rowCount; r++) {
        int rowWidthPx = rowLen[r] * 6; // 6px por carácter
        int curX = (128 - rowWidthPx) / 2;
        int curY = startY + (r * 12);
        
        for (int i = rowStart[r]; i <= rowEnd[r]; i++) {
            int wordLen = (int)strlen(line.words[i].word);
            int wordWidthPx = wordLen * 6;
            unsigned long startMs = line.words[i].startMs;
            unsigned long endMs = line.words[i].endMs;
            
            if (elapsedMs >= endMs) {
                // Palabra ya entonada completamente -> Mostrar toda la palabra
                renderer.text(curX, curY, line.words[i].word, 1);
            } 
            else if (elapsedMs >= startMs) {
                // Palabra entonándose ACTUALMENTE -> Calcular cuántas letras se han armado (máquina de escribir)
                unsigned long wordDuration = (endMs > startMs) ? (endMs - startMs) : 1;
                unsigned long elapsedInWord = elapsedMs - startMs;
                
                // +1 para que la primera letra aparezca de inmediato al tocar startMs
                int typedLetters = (int)((elapsedInWord * wordLen) / wordDuration) + 1;
                if (typedLetters > wordLen) typedLetters = wordLen;
                
                for (int k = 0; k < typedLetters; k++) {
                    char c = line.words[i].word[k];
                    char buf[2] = { c, '\0' };
                    renderer.text(curX + k * 6, curY, buf, 1);
                }
            }
            // Si elapsedMs < startMs (palabra futura): no se dibuja nada aún, esperando su turno de escritura.
            
            // Avanzar posición X a la siguiente palabra (ancho de la palabra + 1 espacio de 6px)
            curX += wordWidthPx + 6;
        }
    }
}

/**
 * @brief Animación de carga puramente gráfica, calmada y melancólica (SIN LETRAS NI TEXTO).
 * Muestra una barra de progreso que avanza tranquilamente y tres círculos que respiran.
 */
void drawLoadingAnimation(unsigned long now, uint8_t pct) {
    // Barra de carga elegante y centrada en la zona azul (y=36, alto=8, ancho=96)
    int barW = 96;
    int barH = 8;
    int barX = (128 - barW) / 2;
    int barY = 36;
    renderer.progressBar(barX, barY, barW, barH, pct);
    
    // Tres círculos gráficos en la parte inferior que se iluminan lentamente (1 segundo por paso)
    // Sin ninguna palabra ni letra
    renderer.circle(56, 52, 2);
    renderer.circle(64, 52, 2);
    renderer.circle(72, 52, 2);
    
    unsigned long step = (now / 1000UL) % 4;
    if (step >= 1) renderer.fillRect(56 - 1, 52 - 1, 3, 3);
    if (step >= 2) renderer.fillRect(64 - 1, 52 - 1, 3, 3);
    if (step >= 3) renderer.fillRect(72 - 1, 52 - 1, 3, 3);
}

/**
 * @brief Animación para partes instrumentales / pausas ("...").
 * Suave, lenta y melancólica, mostrando únicamente la animación gráfica sin letras.
 */
void drawInstrumentalAnimation(unsigned long now, unsigned long elapsedMs, int currentIndex) {
    unsigned long startPause = SONG_LYRICS[currentIndex].timeMs;
    unsigned long endPause = (currentIndex < (int)LYRICS_COUNT - 1) ? SONG_LYRICS[currentIndex + 1].timeMs : SONG_TOTAL_DURATION_MS;
    unsigned long duration = endPause - startPause;
    
    uint8_t pct = 0;
    if (duration >= 3000UL && elapsedMs >= startPause) {
        // Para pausas largas, la barra se llena suavemente desde 0% hasta 100% durante la pausa
        unsigned long elapsedInPause = elapsedMs - startPause;
        pct = (uint8_t)((elapsedInPause * 100UL) / duration);
        if (pct > 100) pct = 100;
    } else {
        // Para pausas cortas, una respiración suave y constante de 6 segundos
        unsigned long cycle = (now % 6000UL);
        if (cycle < 3000UL) {
            pct = (uint8_t)((cycle * 100UL) / 3000UL);
        } else {
            pct = (uint8_t)(((6000UL - cycle) * 100UL) / 3000UL);
        }
    }
    
    drawLoadingAnimation(now, pct);
}

/**
 * @brief Animación de introducción durante los primeros ~21 segundos de la canción.
 * Muestra el nombre de la canción lentamente al principio y luego pasa a la animación calmada sin letras.
 */
void drawIntroAnimation(unsigned long elapsedMs, unsigned long now) {
    const unsigned long introTitleDuration = 7000UL; // Primeros 7 segundos: nombre de la canción
    const unsigned long introTotalDuration = 20990UL; // Inicio de la primera letra en 20.99s
    
    if (elapsedMs < introTitleDuration) {
        // Fase 1: Únicamente el nombre de la canción y una línea que crece suavemente (sin ningún otro texto)
        renderer.textCentered(24, "My Chemical Romance", 1);
        renderer.textCentered(38, "DISENCHANTED", 1);
        
        int maxW = 80;
        int w = (int)((elapsedMs * maxW) / introTitleDuration);
        if (w > maxW) w = maxW;
        int x = (128 - w) / 2;
        if (w > 0) {
            renderer.fillRect(x, 52, w, 1);
        }
    } 
    else {
        // Fase 2: Pasa a la animación de carga calmada y puramente gráfica (sin letras) hasta el 20.99s
        unsigned long loadElapsed = elapsedMs - introTitleDuration;
        unsigned long loadDuration = (introTotalDuration > introTitleDuration) ? (introTotalDuration - introTitleDuration) : 1000UL;
        
        uint8_t pct = (uint8_t)((loadElapsed * 100UL) / loadDuration);
        if (pct > 100) pct = 100;
        
        drawLoadingAnimation(now, pct);
    }
}

void setup() {
    Serial.begin(115200);

    // Inicializar pantalla OLED
    displayDriver.init();
    renderer.clear();
    
    renderer.text(2, 4, "[00:00.00]", 1);
    renderer.text(70, 4, "MCR-Dis", 1);
    renderer.textCentered(28, "My Chemical Romance", 1);
    renderer.textCentered(44, "DISENCHANTED", 1);
    renderer.flush();

    unsigned long tStart = millis();
    while (millis() - tStart < 2000) {
#if defined(IS_RP2040) && defined(USE_TINYUSB)
        tud_task();
#endif
        delay(5);
    }

    songStartTime = millis();
}

void loop() {
#if defined(IS_RP2040) && defined(USE_TINYUSB)
    tud_task();
#endif

    unsigned long now = millis();
    unsigned long elapsedMs = now - songStartTime;

    if (elapsedMs >= SONG_TOTAL_DURATION_MS) {
        songStartTime = now;
        elapsedMs = 0;
        lastPlayedIndex = -1;
    }

    // Refrescar pantalla a ~25 FPS (cada 40 ms)
    if (now - lastRenderTime >= 40) {
        lastRenderTime = now;

        int currentIndex = 0;
        for (int i = 0; i < (int)LYRICS_COUNT; i++) {
            if (SONG_LYRICS[i].timeMs <= elapsedMs) {
                currentIndex = i;
            } else {
                break;
            }
        }

        unsigned long min = (elapsedMs / 60000UL);
        unsigned long sec = ((elapsedMs % 60000UL) / 1000UL);
        unsigned long hun = ((elapsedMs % 1000UL) / 10UL);
        
        char timeStr[16];
        snprintf(timeStr, sizeof(timeStr), "[%02lu:%02lu.%02lu]", min, sec, hun);

        renderer.clear();

        // ── ZONA AMARILLA (y = 0 a 15) ───────────────────────────────────────
        renderer.text(2, 4, timeStr, 1);
        renderer.text(70, 4, "MCR-Dis", 1);

        // ── ZONA AZUL (y = 16 a 63) ──────────────────────────────────────────
        if (currentIndex == 0) {
            // Intro de la canción (de 0 a 20.99 segundos) -> Animación en 4 fases
            drawIntroAnimation(elapsedMs, now);
        } 
        else if (strcmp(SONG_LYRICS[currentIndex].text, "...") == 0 || strlen(SONG_LYRICS[currentIndex].text) == 0) {
            // Parte instrumental / pausa -> Animación de carga suave y melancólica
            drawInstrumentalAnimation(now, elapsedMs, currentIndex);
        } 
        else {
            // Verso cantado -> Sincronización fina palabra por palabra / letra por letra
            drawSyncedLyrics(SONG_LYRICS[currentIndex], elapsedMs);
        }

        renderer.flush();

        if (currentIndex != lastPlayedIndex) {
            lastPlayedIndex = currentIndex;
            Serial.printf("%s %s\n", timeStr, SONG_LYRICS[currentIndex].text);
        }
    }

    delay(1);
}
