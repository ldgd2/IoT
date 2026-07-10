#ifndef LYRICS_DATA_H
#define LYRICS_DATA_H

#include <stdint.h>

struct LyricWord {
    const char* word;      // Texto de la palabra
    unsigned long startMs; // Tiempo de inicio en milisegundos
    unsigned long endMs;   // Tiempo de fin en milisegundos
};

struct LyricLine {
    unsigned long timeMs;        // Tiempo en milisegundos desde el inicio de la canción
    const char* text;            // Texto completo a mostrar
    const LyricWord* words;      // Puntero al array de palabras con sincronización fina (o nullptr)
    uint8_t wordCount;           // Cantidad de palabras en el array
};

// Duración total de la canción en milisegundos ([04:41.98] = 281980UL)
#define SONG_TOTAL_DURATION_MS 281980UL

// ── Palabras sincronizadas (Karaoke / Word by Word) ──────────────────────────
static const LyricWord L01_WORDS[] = { {"Well,", 20995UL, 21383UL}, {"I", 21383UL, 21732UL}, {"was", 21732UL, 22098UL}, {"there", 22098UL, 22431UL}, {"on", 22431UL, 22748UL}, {"the", 22748UL, 23098UL}, {"day", 23098UL, 23779UL} };
static const LyricWord L02_WORDS[] = { {"They", 23779UL, 24111UL}, {"sold", 24111UL, 24460UL}, {"the", 24460UL, 24810UL}, {"cause", 24810UL, 25159UL}, {"for", 25159UL, 25527UL}, {"the", 25527UL, 25860UL}, {"queen", 25860UL, 26398UL} };
static const LyricWord L03_WORDS[] = { {"And", 26558UL, 26922UL}, {"when", 26922UL, 27239UL}, {"the", 27239UL, 27605UL}, {"lights", 27605UL, 27938UL}, {"all", 27938UL, 28271UL}, {"went", 28271UL, 28639UL}, {"out", 28639UL, 29236UL} };
static const LyricWord L04_WORDS[] = { {"We", 29320UL, 29634UL}, {"watched", 29634UL, 29967UL}, {"our", 29967UL, 30333UL}, {"lives", 30333UL, 30717UL}, {"on", 30717UL, 31034UL}, {"the", 31034UL, 31367UL}, {"screen", 31367UL, 31896UL} };
static const LyricWord L05_WORDS[] = { {"I", 32066UL, 32362UL}, {"hate", 32362UL, 32695UL}, {"the", 32695UL, 33079UL}, {"ending,", 33079UL, 33829UL}, {"myself", 33829UL, 34881UL} };
static const LyricWord L06_WORDS[] = { {"But", 35170UL, 35504UL}, {"it", 35504UL, 35853UL}, {"started", 35853UL, 36538UL}, {"with", 36538UL, 36888UL}, {"an", 36888UL, 37221UL}, {"alright", 37221UL, 38202UL}, {"scene", 38202UL, 39090UL} };
static const LyricWord L07_WORDS[] = { {"It", 43111UL, 43441UL}, {"was", 43441UL, 43758UL}, {"the", 43758UL, 44124UL}, {"roar", 44124UL, 44457UL}, {"of", 44457UL, 44825UL}, {"the", 44825UL, 45124UL}, {"crowd", 45124UL, 45826UL} };
static const LyricWord L08_WORDS[] = { {"That", 45826UL, 46148UL}, {"gave", 46148UL, 46513UL}, {"me", 46513UL, 46862UL}, {"heartache", 46862UL, 47564UL}, {"to", 47564UL, 47897UL}, {"sing", 47897UL, 48434UL} };
static const LyricWord L09_WORDS[] = { {"It", 48618UL, 48937UL}, {"was", 48937UL, 49303UL}, {"a", 49303UL, 49636UL}, {"lie", 49636UL, 50004UL}, {"when", 50004UL, 50353UL}, {"they", 50353UL, 50671UL}, {"smiled", 50671UL, 51236UL} };
static const LyricWord L10_WORDS[] = { {"And", 51346UL, 51714UL}, {"said,", 51714UL, 52063UL}, {"\"You", 52063UL, 52396UL}, {"won't", 52396UL, 52730UL}, {"feel", 52730UL, 53114UL}, {"a", 53114UL, 53447UL}, {"thing\"", 53447UL, 53920UL} };
static const LyricWord L11_WORDS[] = { {"And", 54083UL, 54453UL}, {"as", 54453UL, 54786UL}, {"we", 54786UL, 55154UL}, {"ran", 55154UL, 55488UL}, {"from", 55488UL, 55837UL}, {"the", 55837UL, 56202UL}, {"cops", 56202UL, 56902UL} };
static const LyricWord L12_WORDS[] = { {"We", 57553UL, 57935UL}, {"laughed", 57935UL, 58253UL}, {"so", 58253UL, 58602UL}, {"hard", 58602UL, 59351UL}, {"it", 59351UL, 59653UL}, {"would", 59653UL, 60319UL}, {"sting", 60319UL, 61455UL} };
static const LyricWord L13_WORDS[] = { {"Yeah,", 62351UL, 63100UL}, {"yeah,", 63100UL, 64866UL}, {"oh", 64866UL, 66317UL} };
static const LyricWord L14_WORDS[] = { {"If", 66882UL, 67210UL}, {"I'm", 67210UL, 67860UL}, {"so", 67860UL, 68578UL}, {"wrong", 68578UL, 69698UL} };
static const LyricWord L15_WORDS[] = { {"(So", 69492UL, 69927UL}, {"wrong,", 69927UL, 70594UL}, {"so", 70594UL, 71311UL}, {"wrong)", 71311UL, 72345UL} };
static const LyricWord L16_WORDS[] = { {"How", 70630UL, 70999UL}, {"can", 70999UL, 71348UL}, {"you", 71348UL, 71665UL}, {"listen", 71665UL, 72713UL}, {"all", 72713UL, 73364UL}, {"night", 73364UL, 74047UL}, {"long?", 74047UL, 75113UL} };
static const LyricWord L17_WORDS[] = { {"(Night", 75113UL, 75811UL}, {"long,", 75811UL, 76529UL}, {"night", 76529UL, 77262UL}, {"long)", 77262UL, 77996UL} };
static const LyricWord L18_WORDS[] = { {"Now,", 77505UL, 77854UL}, {"will", 77854UL, 78187UL}, {"it", 78187UL, 78553UL}, {"matter", 78553UL, 79703UL}, {"after", 79995UL, 80614UL}, {"I'm", 80614UL, 80998UL}, {"gone?", 80998UL, 81663UL} };
static const LyricWord L19_WORDS[] = { {"Because", 81663UL, 82334UL}, {"you", 82334UL, 82686UL}, {"never", 82686UL, 83401UL}, {"learned", 83401UL, 83785UL}, {"a", 83785UL, 84118UL}, {"goddamn", 84118UL, 85134UL}, {"thing", 85134UL, 86279UL} };
static const LyricWord L20_WORDS[] = { {"You're", 87175UL, 87541UL}, {"just", 87541UL, 87890UL}, {"a", 87890UL, 88223UL}, {"sad", 88223UL, 89258UL}, {"song", 89258UL, 90383UL}, {"with", 90720UL, 91003UL}, {"nothing", 91003UL, 91704UL}, {"to", 91704UL, 92088UL}, {"say", 92088UL, 92655UL} };
static const LyricWord L21_WORDS[] = { {"About", 92765UL, 93473UL}, {"a", 93473UL, 93755UL}, {"lifelong", 93755UL, 95458UL}, {"wait", 95520UL, 95853UL}, {"for", 95853UL, 96186UL}, {"a", 96186UL, 96536UL}, {"hospital", 96536UL, 97602UL}, {"stay", 97602UL, 98069UL} };
static const LyricWord L22_WORDS[] = { {"And", 98242UL, 98578UL}, {"if", 98578UL, 98928UL}, {"you", 98928UL, 99296UL}, {"think", 99296UL, 99645UL}, {"that", 99645UL, 99978UL}, {"I'm", 99978UL, 100312UL}, {"wrong", 100312UL, 101184UL} };
static const LyricWord L23_WORDS[] = { {"This", 101685UL, 102065UL}, {"never", 102065UL, 102779UL}, {"meant", 102779UL, 103081UL}, {"nothing", 103081UL, 104465UL}, {"to", 104465UL, 105147UL}, {"you", 105147UL, 108017UL} };
static const LyricWord L24_WORDS[] = { {"I", 109243UL, 109593UL}, {"spent", 109593UL, 109958UL}, {"my", 109958UL, 110292UL}, {"high", 110292UL, 110644UL}, {"school", 110644UL, 110993UL}, {"career", 110993UL, 111776UL} };
static const LyricWord L25_WORDS[] = { {"Spit", 111970UL, 112369UL}, {"on", 112369UL, 112734UL}, {"and", 112734UL, 113068UL}, {"shoved", 113068UL, 113433UL}, {"to", 113433UL, 113769UL}, {"agree", 113769UL, 114514UL} };
static const LyricWord L26_WORDS[] = { {"So", 114741UL, 115138UL}, {"I", 115138UL, 115471UL}, {"could", 115471UL, 115836UL}, {"watch", 115836UL, 116170UL}, {"all", 116170UL, 116519UL}, {"my", 116519UL, 116836UL}, {"heroes", 116836UL, 117858UL} };
static const LyricWord L27_WORDS[] = { {"Sell", 117858UL, 118224UL}, {"a", 118224UL, 118541UL}, {"car", 118541UL, 118941UL}, {"on", 118941UL, 119275UL}, {"TV", 119275UL, 120124UL} };
static const LyricWord L28_WORDS[] = { {"Bring", 120265UL, 120638UL}, {"out", 120638UL, 120968UL}, {"the", 120968UL, 121336UL}, {"old", 121336UL, 121720UL}, {"guillotine", 121720UL, 123139UL} };
static const LyricWord L29_WORDS[] = { {"We'll", 123713UL, 124125UL}, {"show", 124125UL, 124459UL}, {"'em", 124459UL, 124808UL}, {"what", 124808UL, 125557UL}, {"we", 125557UL, 125875UL}, {"all", 125875UL, 126541UL}, {"mean", 126541UL, 127972UL} };
static const LyricWord L30_WORDS[] = { {"Yeah,", 128569UL, 129331UL}, {"yeah,", 129331UL, 131032UL}, {"oh", 131032UL, 132697UL} };
static const LyricWord L31_WORDS[] = { {"If", 133024UL, 133422UL}, {"I'm", 133422UL, 134072UL}, {"so", 134072UL, 134803UL}, {"wrong", 134803UL, 135873UL} };
static const LyricWord L32_WORDS[] = { {"(So", 135736UL, 136152UL}, {"wrong,", 136152UL, 136803UL}, {"so", 136803UL, 137571UL}, {"wrong)", 137571UL, 138573UL} };
static const LyricWord L33_WORDS[] = { {"How", 136800UL, 137192UL}, {"can", 137192UL, 137560UL}, {"you", 137560UL, 137893UL}, {"listen", 137893UL, 138903UL}, {"all", 138903UL, 139589UL}, {"night", 139589UL, 140303UL}, {"long?", 140303UL, 141314UL} };
static const LyricWord L34_WORDS[] = { {"(Night", 141314UL, 142047UL}, {"long,", 142047UL, 142730UL}, {"night", 142730UL, 143415UL}, {"long)", 143415UL, 144133UL} };
static const LyricWord L35_WORDS[] = { {"Now,", 143711UL, 144103UL}, {"will", 144103UL, 144420UL}, {"it", 144420UL, 144769UL}, {"matter", 144769UL, 145820UL}, {"long", 145820UL, 146188UL}, {"after", 146188UL, 146887UL}, {"I'm", 146887UL, 147220UL}, {"gone?", 147220UL, 147861UL} };
static const LyricWord L36_WORDS[] = { {"Because", 147903UL, 148627UL}, {"you", 148627UL, 148944UL}, {"never", 148944UL, 149643UL}, {"learned", 149643UL, 150008UL}, {"a", 150008UL, 150325UL}, {"goddamn", 150325UL, 151341UL}, {"thing", 151341UL, 152482UL} };
static const LyricWord L37_WORDS[] = { {"You're", 153369UL, 153752UL}, {"just", 153752UL, 154118UL}, {"a", 154118UL, 154486UL}, {"sad", 154486UL, 155419UL}, {"song", 155419UL, 156622UL}, {"with", 156902UL, 157267UL}, {"nothing", 157267UL, 157918UL}, {"to", 157918UL, 158251UL}, {"say", 158251UL, 158757UL} };
static const LyricWord L38_WORDS[] = { {"About", 158935UL, 159632UL}, {"a", 159632UL, 159965UL}, {"lifelong", 159965UL, 161717UL}, {"wait", 161717UL, 162066UL}, {"for", 162066UL, 162400UL}, {"a", 162400UL, 162733UL}, {"hospital", 162733UL, 163749UL}, {"stay", 163749UL, 164255UL} };
static const LyricWord L39_WORDS[] = { {"And", 164434UL, 164803UL}, {"if", 164803UL, 165120UL}, {"you", 165120UL, 165485UL}, {"think", 165485UL, 165835UL}, {"that", 165835UL, 166203UL}, {"I'm", 166203UL, 166520UL}, {"wrong", 166520UL, 167445UL} };
static const LyricWord L40_WORDS[] = { {"This", 167854UL, 168251UL}, {"never", 168251UL, 168933UL}, {"meant", 168933UL, 169267UL}, {"nothing", 169267UL, 170683UL}, {"to", 170683UL, 171384UL}, {"you", 171384UL, 174204UL} };
static const LyricWord L41_WORDS[] = { {"So", 175535UL, 176498UL}, {"go,", 176498UL, 177624UL}, {"go", 178263UL, 178549UL}, {"away", 178549UL, 179996UL} };
static const LyricWord L42_WORDS[] = { {"Just", 181252UL, 182036UL}, {"go,", 182036UL, 183142UL}, {"run", 183730UL, 184098UL}, {"away", 184098UL, 185502UL} };
static const LyricWord L43_WORDS[] = { {"But", 185815UL, 186159UL}, {"where", 186159UL, 186474UL}, {"did", 186474UL, 186858UL}, {"you", 186858UL, 187207UL}, {"run", 187207UL, 187892UL}, {"to?", 187892UL, 188396UL} };
static const LyricWord L44_WORDS[] = { {"And", 188575UL, 188903UL}, {"where", 188903UL, 189236UL}, {"did", 189236UL, 189586UL}, {"you", 189586UL, 189970UL}, {"hide?", 189970UL, 190668UL} };
static const LyricWord L45_WORDS[] = { {"Go", 190668UL, 190997UL}, {"find", 190997UL, 191349UL}, {"another", 191349UL, 192765UL}, {"way", 192765UL, 193751UL} };
static const LyricWord L46_WORDS[] = { {"Price", 194741UL, 195138UL}, {"you", 195138UL, 195472UL}, {"pay", 195472UL, 198282UL} };
static const LyricWord L47_WORDS[] = { {"Whoa,", 198282UL, 203260UL}, {"whoa,", 203861UL, 209000UL}, {"whoa", 209390UL, 214233UL} };
static const LyricWord L48_WORDS[] = { {"Whoa,", 214853UL, 216524UL}, {"whoa,", 216524UL, 217826UL}, {"whoa", 217826UL, 220636UL} };
static const LyricWord L49_WORDS[] = { {"You're", 219607UL, 219974UL}, {"just", 219974UL, 220273UL}, {"a", 220273UL, 220574UL}, {"sad", 220574UL, 221625UL}, {"song", 221625UL, 222853UL}, {"with", 223084UL, 223385UL}, {"nothing", 223385UL, 224119UL}, {"to", 224119UL, 224452UL}, {"say", 224452UL, 225042UL} };
static const LyricWord L50_WORDS[] = { {"About", 225140UL, 225852UL}, {"a", 225852UL, 226185UL}, {"lifelong", 226185UL, 227858UL}, {"wait", 227892UL, 228276UL}, {"for", 228276UL, 228591UL}, {"a", 228591UL, 228924UL}, {"hospital", 228924UL, 229991UL}, {"stay", 229991UL, 230479UL} };
static const LyricWord L51_WORDS[] = { {"And", 230607UL, 231037UL}, {"if", 231037UL, 231373UL}, {"you", 231373UL, 231687UL}, {"think", 231687UL, 232037UL}, {"that", 232037UL, 232373UL}, {"I'm", 232373UL, 232722UL}, {"wrong", 232722UL, 233666UL} };
static const LyricWord L52_WORDS[] = { {"This", 234084UL, 234469UL}, {"never", 234469UL, 235151UL}, {"meant", 235151UL, 235503UL}, {"nothing", 235503UL, 236869UL}, {"to", 236869UL, 237570UL}, {"you", 237570UL, 239066UL} };
static const LyricWord L53_WORDS[] = { {"Come", 239309UL, 239634UL}, {"on", 239634UL, 241178UL} };
static const LyricWord L54_WORDS[] = { {"You're", 241667UL, 242032UL}, {"just", 242032UL, 242365UL}, {"a", 242365UL, 242698UL}, {"sad", 242698UL, 243624UL}, {"song", 243624UL, 244951UL}, {"with", 245176UL, 245491UL}, {"nothing", 245491UL, 246192UL}, {"to", 246192UL, 246541UL}, {"say", 246541UL, 247112UL} };
static const LyricWord L55_WORDS[] = { {"About", 247229UL, 247983UL}, {"a", 247983UL, 248268UL}, {"lifelong", 248268UL, 249955UL}, {"wait", 250012UL, 250378UL}, {"for", 250378UL, 250711UL}, {"a", 250711UL, 251028UL}, {"hospital", 251028UL, 252012UL}, {"stay", 252012UL, 252633UL} };
static const LyricWord L56_WORDS[] = { {"And", 252709UL, 253108UL}, {"if", 253108UL, 253441UL}, {"you", 253441UL, 253790UL}, {"think", 253790UL, 254124UL}, {"that", 254124UL, 254473UL}, {"I'm", 254473UL, 254790UL}, {"wrong", 254790UL, 255703UL} };
static const LyricWord L57_WORDS[] = { {"This", 256073UL, 256495UL}, {"never", 256495UL, 257197UL}, {"meant", 257197UL, 257527UL}, {"nothing", 257527UL, 258879UL}, {"to", 258879UL, 259597UL}, {"you", 259597UL, 262899UL} };
static const LyricWord L58_WORDS[] = { {"At", 263721UL, 264479UL}, {"all", 264479UL, 265636UL} };
static const LyricWord L59_WORDS[] = { {"At", 269699UL, 270048UL}, {"all", 270048UL, 270897UL} };
static const LyricWord L60_WORDS[] = { {"At", 275190UL, 275531UL}, {"all", 275531UL, 276508UL} };
static const LyricWord L61_WORDS[] = { {"At", 280705UL, 281040UL}, {"all", 281040UL, 281989UL} };

#define COUNT_WORDS(arr) (sizeof(arr) / sizeof(arr[0]))

// Líricas sincronizadas de My Chemical Romance - Disenchanted
static const LyricLine SONG_LYRICS[] = {
    {     0UL, "MCR - Disenchanted",                         nullptr,   0 },
    { 20995UL, "Well, I was there on the day",               L01_WORDS, COUNT_WORDS(L01_WORDS) },
    { 23779UL, "They sold the cause for the queen",          L02_WORDS, COUNT_WORDS(L02_WORDS) },
    { 26558UL, "And when the lights all went out",           L03_WORDS, COUNT_WORDS(L03_WORDS) },
    { 29320UL, "We watched our lives on the screen",         L04_WORDS, COUNT_WORDS(L04_WORDS) },
    { 32066UL, "I hate the ending, myself",                  L05_WORDS, COUNT_WORDS(L05_WORDS) },
    { 35170UL, "But it started with an alright scene",       L06_WORDS, COUNT_WORDS(L06_WORDS) },
    { 39090UL, "...",                                        nullptr,   0 }, // Pausa instrumental
    { 43111UL, "It was the roar of the crowd",               L07_WORDS, COUNT_WORDS(L07_WORDS) },
    { 45826UL, "That gave me heartache to sing",             L08_WORDS, COUNT_WORDS(L08_WORDS) },
    { 48618UL, "It was a lie when they smiled",              L09_WORDS, COUNT_WORDS(L09_WORDS) },
    { 51346UL, "And said, \"You won't feel a thing\"",       L10_WORDS, COUNT_WORDS(L10_WORDS) },
    { 54083UL, "And as we ran from the cops",                L11_WORDS, COUNT_WORDS(L11_WORDS) },
    { 57553UL, "We laughed so hard it would sting",          L12_WORDS, COUNT_WORDS(L12_WORDS) },
    { 62351UL, "Yeah, yeah, oh",                             L13_WORDS, COUNT_WORDS(L13_WORDS) },
    { 66317UL, "...",                                        nullptr,   0 },
    { 66882UL, "If I'm so wrong",                            L14_WORDS, COUNT_WORDS(L14_WORDS) },
    { 69492UL, "(So wrong, so wrong)",                       L15_WORDS, COUNT_WORDS(L15_WORDS) },
    { 70630UL, "How can you listen all night long?",         L16_WORDS, COUNT_WORDS(L16_WORDS) },
    { 75113UL, "(Night long, night long)",                   L17_WORDS, COUNT_WORDS(L17_WORDS) },
    { 77505UL, "Now, will it matter after I'm gone?",        L18_WORDS, COUNT_WORDS(L18_WORDS) },
    { 81663UL, "Because you never learned a goddamn thing",  L19_WORDS, COUNT_WORDS(L19_WORDS) },
    { 86279UL, "...",                                        nullptr,   0 },
    { 87175UL, "You're just a sad song with nothing to say", L20_WORDS, COUNT_WORDS(L20_WORDS) },
    { 92765UL, "About a lifelong wait for a hospital stay",  L21_WORDS, COUNT_WORDS(L21_WORDS) },
    { 98242UL, "And if you think that I'm wrong",            L22_WORDS, COUNT_WORDS(L22_WORDS) },
    { 101685UL, "This never meant nothing to you",           L23_WORDS, COUNT_WORDS(L23_WORDS) },
    { 108017UL, "...",                                       nullptr,   0 },
    { 109243UL, "I spent my high school career",             L24_WORDS, COUNT_WORDS(L24_WORDS) },
    { 111970UL, "Spit on and shoved to agree",               L25_WORDS, COUNT_WORDS(L25_WORDS) },
    { 114741UL, "So I could watch all my heroes",            L26_WORDS, COUNT_WORDS(L26_WORDS) },
    { 117858UL, "Sell a car on TV",                          L27_WORDS, COUNT_WORDS(L27_WORDS) },
    { 120265UL, "Bring out the old guillotine",              L28_WORDS, COUNT_WORDS(L28_WORDS) },
    { 123713UL, "We'll show 'em what we all mean",           L29_WORDS, COUNT_WORDS(L29_WORDS) },
    { 128569UL, "Yeah, yeah, oh",                            L30_WORDS, COUNT_WORDS(L30_WORDS) },
    { 132697UL, "...",                                       nullptr,   0 },
    { 133024UL, "If I'm so wrong",                           L31_WORDS, COUNT_WORDS(L31_WORDS) },
    { 135736UL, "(So wrong, so wrong)",                      L32_WORDS, COUNT_WORDS(L32_WORDS) },
    { 136800UL, "How can you listen all night long?",        L33_WORDS, COUNT_WORDS(L33_WORDS) },
    { 141314UL, "(Night long, night long)",                  L34_WORDS, COUNT_WORDS(L34_WORDS) },
    { 143711UL, "Now, will it matter long after I'm gone?",  L35_WORDS, COUNT_WORDS(L35_WORDS) },
    { 147903UL, "Because you never learned a goddamn thing", L36_WORDS, COUNT_WORDS(L36_WORDS) },
    { 152482UL, "...",                                       nullptr,   0 },
    { 153369UL, "You're just a sad song with nothing to say",L37_WORDS, COUNT_WORDS(L37_WORDS) },
    { 158935UL, "About a lifelong wait for a hospital stay", L38_WORDS, COUNT_WORDS(L38_WORDS) },
    { 164434UL, "And if you think that I'm wrong",           L39_WORDS, COUNT_WORDS(L39_WORDS) },
    { 167854UL, "This never meant nothing to you",           L40_WORDS, COUNT_WORDS(L40_WORDS) },
    { 174204UL, "...",                                       nullptr,   0 },
    { 175535UL, "So go, go away",                            L41_WORDS, COUNT_WORDS(L41_WORDS) },
    { 181252UL, "Just go, run away",                         L42_WORDS, COUNT_WORDS(L42_WORDS) },
    { 185815UL, "But where did you run to?",                 L43_WORDS, COUNT_WORDS(L43_WORDS) },
    { 188575UL, "And where did you hide?",                   L44_WORDS, COUNT_WORDS(L44_WORDS) },
    { 190668UL, "Go find another way",                       L45_WORDS, COUNT_WORDS(L45_WORDS) },
    { 194741UL, "Price you pay",                             L46_WORDS, COUNT_WORDS(L46_WORDS) },
    { 198282UL, "Whoa, whoa, whoa",                          L47_WORDS, COUNT_WORDS(L47_WORDS) },
    { 214853UL, "Whoa, whoa, whoa",                          L48_WORDS, COUNT_WORDS(L48_WORDS) },
    { 219607UL, "You're just a sad song with nothing to say",L49_WORDS, COUNT_WORDS(L49_WORDS) },
    { 225140UL, "About a lifelong wait for a hospital stay", L50_WORDS, COUNT_WORDS(L50_WORDS) },
    { 230607UL, "And if you think that I'm wrong",           L51_WORDS, COUNT_WORDS(L51_WORDS) },
    { 234084UL, "This never meant nothing to you",           L52_WORDS, COUNT_WORDS(L52_WORDS) },
    { 239309UL, "Come on",                                   L53_WORDS, COUNT_WORDS(L53_WORDS) },
    { 241178UL, "...",                                       nullptr,   0 },
    { 241667UL, "You're just a sad song with nothing to say",L54_WORDS, COUNT_WORDS(L54_WORDS) },
    { 247229UL, "About a lifelong wait for a hospital stay", L55_WORDS, COUNT_WORDS(L55_WORDS) },
    { 252709UL, "And if you think that I'm wrong",           L56_WORDS, COUNT_WORDS(L56_WORDS) },
    { 256073UL, "This never meant nothing to you",           L57_WORDS, COUNT_WORDS(L57_WORDS) },
    { 262899UL, "...",                                       nullptr,   0 },
    { 263721UL, "At all",                                    L58_WORDS, COUNT_WORDS(L58_WORDS) },
    { 269699UL, "At all",                                    L59_WORDS, COUNT_WORDS(L59_WORDS) },
    { 275190UL, "At all",                                    L60_WORDS, COUNT_WORDS(L60_WORDS) },
    { 280705UL, "At all",                                    L61_WORDS, COUNT_WORDS(L61_WORDS) },
    { 281989UL, "...",                                       nullptr,   0 }
};

#define LYRICS_COUNT (sizeof(SONG_LYRICS) / sizeof(SONG_LYRICS[0]))

#endif // LYRICS_DATA_H
