//
//  ansi_reader.c
//  o1
//
//  Created by gpt-5-high on 2025-10-12.
//

#include "ansi_reader.h"

#include "ansi.h"
#include "include.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    STATE_GROUND = 0,
    STATE_ESC,
    STATE_CSI,
    STATE_OSC,
    STATE_OSC_MAYBE_ST,
} state_t;

struct ansi_reader_t {
    state_t state;
    uint8_t utf8[4];
    size_t utf8_length;
    bool csi_dec_private;
    char csi_intermediates[5];
    size_t csi_intermediates_count;
    int csi_parameters[ANSI_MAX_PARAMETERS];
    size_t csi_parameters_count;
    int csi_current;
    size_t osc_capacity;
    char *osc_buffer;
    size_t osc_length;
    int osc_code;
    ansi_reader_callback_t on_ansi;
    void *user_data;
};

static inline void sgr_unset_attributes(ansi_sgr_t *attributes) {
    if (!attributes) return;

    attributes->flags = ANSI_SGR_FLAG_NONE;
    attributes->fg_color = ANSI_COLOR_UNSET;
    attributes->bg_color = ANSI_COLOR_UNSET;
}

static inline void sgr_reset_attributes(ansi_sgr_t *attributes) {
    if (!attributes) return;

    attributes->flags = ANSI_SGR_FLAGS_OFF_MASK;
    attributes->fg_color = ANSI_COLOR_RESET;
    attributes->bg_color = ANSI_COLOR_RESET;
}

static void sgr_apply_parameters(ansi_sgr_t *attributes, const int *parameters, size_t count) {
    if (!attributes) return;

    if (count < 1) {
        sgr_reset_attributes(attributes);

        return;
    }

    size_t i = 0;

    while (i < count) {
        int p = parameters[i] < 0 ? 0 : parameters[i];

        switch (p) {
            case 0:
                sgr_reset_attributes(attributes);
                i++;

                break;
            case 1:
                attributes->flags |= ANSI_SGR_FLAG_BOLD;
                i++;

                break;
            case 2:
                attributes->flags |= ANSI_SGR_FLAG_FAINT;
                i++;

                break;
            case 3:
                attributes->flags |= ANSI_SGR_FLAG_ITALIC;
                i++;

                break;
            case 4:
                attributes->flags |= ANSI_SGR_FLAG_UNDERLINE;
                i++;

                break;
            case 5:
            case 6:
                attributes->flags |= ANSI_SGR_FLAG_BLINK;
                i++;

                break;
            case 7:
                attributes->flags |= ANSI_SGR_FLAG_INVERSE;
                i++;

                break;
            case 8:
                attributes->flags |= ANSI_SGR_FLAG_HIDDEN;
                i++;

                break;
            case 9:
                attributes->flags |= ANSI_SGR_FLAG_STRIKE;
                i++;

                break;
            case 21:
            case 22:
                attributes->flags |= ANSI_SGR_FLAG_OFF_BOLD | ANSI_SGR_FLAG_OFF_FAINT;
                i++;

                break;
            case 23:
                attributes->flags |= ANSI_SGR_FLAG_OFF_ITALIC;
                i++;

                break;
            case 24:
                attributes->flags |= ANSI_SGR_FLAG_OFF_UNDERLINE;
                i++;

                break;
            case 25:
            case 26:
                attributes->flags |= ANSI_SGR_FLAG_OFF_BLINK;
                i++;

                break;
            case 27:
                attributes->flags |= ANSI_SGR_FLAG_OFF_INVERSE;
                i++;

                break;
            case 28:
                attributes->flags |= ANSI_SGR_FLAG_OFF_HIDDEN;
                i++;

                break;
            case 29:
                attributes->flags |= ANSI_SGR_FLAG_OFF_STRIKE;
                i++;

                break;
            case 39:
                attributes->fg_color = ANSI_COLOR_RESET;
                i++;

                break;
            case 49:
                attributes->bg_color = ANSI_COLOR_RESET;
                i++;

                break;
            default: {
                if ((p >= 30 && p <= 37) || (p >= 90 && p <= 97)) {
                    int base = p >= 90 ? 90 : 30;
                    int index = p - base + (base == 90 ? 8 : 0);

                    attributes->fg_color = ansi_color_pack_indexed(index);
                    i++;
                } else if ((p >= 40 && p <= 47) || (p >= 100 && p <= 107)) {
                    int base = p >= 100 ? 100 : 40;
                    int index = p - base + (base == 100 ? 8 : 0);

                    attributes->bg_color = ansi_color_pack_indexed(index);
                    i++;
                } else if (p == 38 || p == 48) {
                    bool foreground = p == 38;

                    if (i + 1 < count && parameters[i + 1] == 5 && i + 2 < count) {
                        int index = parameters[i + 2];

                        if (index < 0) index = 0;
                        if (index > 255) index = 255;

                        uint32_t *color = foreground ? &attributes->fg_color : &attributes->bg_color;

                        *color = ansi_color_pack_indexed(index);
                        i += 3;
                    } else if (i + 4 < count && parameters[i + 1] == 2) {
                        int red = parameters[i + 2];
                        int green = parameters[i + 3];
                        int blue = parameters[i + 4];

                        if (red < 0) red = 0;
                        if (red > 255) red = 255;
                        if (green < 0) green = 0;
                        if (green > 255) green = 255;
                        if (blue < 0) blue = 0;
                        if (blue > 255) blue = 255;

                        uint32_t *color = foreground ? &attributes->fg_color : &attributes->bg_color;

                        *color = ansi_color_pack_rgb(red, green, blue);
                        i += 5;
                    } else {
                        i++;
                    }
                } else {
                    i++;
                }

                break;
            }
        }
    }
}

static inline ansi_mode_t csi_mode(int code) {
    switch (code) {
        case 4:
            return ANSI_MODE_INSERT;
        default:
            return ANSI_MODE_UNKNOWN;
    }
}

static inline ansi_dec_mode_t dec_mode(int code) {
    switch (code) {
        case 1:
            return ANSI_DEC_MODE_CURSOR_KEYS;
        case 6:
            return ANSI_DEC_MODE_ORIGIN;
        case 7:
            return ANSI_DEC_MODE_AUTO_WRAP;
        case 12:
            return ANSI_DEC_MODE_CURSOR_BLINK;
        case 25:
            return ANSI_DEC_MODE_CURSOR_VISIBLE;
        case 1000:
            return ANSI_DEC_MODE_MOUSE_X10;
        case 1002:
            return ANSI_DEC_MODE_MOUSE_NORMAL;
        case 1003:
            return ANSI_DEC_MODE_MOUSE_ALL;
        case 1004:
            return ANSI_DEC_MODE_FOCUS_REPORTING;
        case 1006:
            return ANSI_DEC_MODE_MOUSE_SGR;
        case 1047:
            return ANSI_DEC_MODE_ALTERNATE_SCREEN;
        case 1048:
            return ANSI_DEC_MODE_SAVE_CURSOR;
        case 1049:
            return ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR;
        case 2004:
            return ANSI_DEC_MODE_BRACKETED_PASTE;
        default:
            return ANSI_DEC_MODE_UNKNOWN;
    }
}

static void send_unknown(ansi_reader_t *reader, const uint8_t *start, size_t length) {
    if (!reader->on_ansi || length < 1) return;

    ansi_t ansi;

    ansi.event = ANSI_EVENT_UNKNOWN;
    ansi.unknown.bytes = start;
    ansi.unknown.length = length;
    reader->on_ansi(reader->user_data, &ansi);
}

static void send_text(ansi_reader_t *reader, const uint8_t *start, size_t length) {
    if (!reader->on_ansi || length < 1) return;

    ansi_t ansi;

    ansi.event = ANSI_EVENT_TEXT;
    ansi.text.bytes = start;
    ansi.text.length = length;
    reader->on_ansi(reader->user_data, &ansi);
}

static void send_esc(ansi_reader_t *reader, ansi_esc_event_t event) {
    if (!reader->on_ansi) return;

    ansi_t ansi;

    ansi.event = ANSI_EVENT_ESC;
    ansi.esc.event = event;
    reader->on_ansi(reader->user_data, &ansi);
}

static inline void reset_csi(ansi_reader_t *reader) {
    reader->csi_dec_private = false;
    reader->csi_parameters_count = 0;
    reader->csi_current = -1;

    for (size_t i = 0; i < ANSI_MAX_PARAMETERS; i++) reader->csi_parameters[i] = -1;

    reader->csi_intermediates_count = 0;
}

static void send_csi(ansi_reader_t *reader, char final_byte) {
    if (!reader->on_ansi) return;

    if (reader->csi_current != -1) {
        if (reader->csi_parameters_count < ANSI_MAX_PARAMETERS) reader->csi_parameters[reader->csi_parameters_count++] = reader->csi_current;

        reader->csi_current = -1;
    }

    ansi_t ansi;

    ansi.event = ANSI_EVENT_CSI;
    ansi.csi.dec_private = reader->csi_dec_private;
    ansi.csi.final_byte = final_byte;
    ansi.csi.parameters_count = reader->csi_parameters_count;

    for (size_t i = 0; i < reader->csi_parameters_count && i < ANSI_MAX_PARAMETERS; i++) ansi.csi.parameters[i] = reader->csi_parameters[i];

    ansi.csi.intermediates_count = reader->csi_intermediates_count;

    for (size_t j = 0; j < reader->csi_intermediates_count && j < 5; j++) ansi.csi.intermediates[j] = reader->csi_intermediates[j];

    sgr_unset_attributes(&ansi.csi.attributes);

    ansi_csi_event_t event = ANSI_CSI_KIND_UNKNOWN;

    switch (final_byte) {
        case 'A':
            event = ANSI_CSI_CUU;

            break;
        case 'B':
            event = ANSI_CSI_CUD;

            break;
        case 'C':
            event = ANSI_CSI_CUF;

            break;
        case 'D':
            event = ANSI_CSI_CUB;

            break;
        case 'E':
            event = ANSI_CSI_CNL;

            break;
        case 'F':
            event = ANSI_CSI_CPL;

            break;
        case 'G':
            event = ANSI_CSI_CHA;

            break;
        case 'H':
            event = ANSI_CSI_CUP;

            break;
        case 'I':
            event = ANSI_CSI_FCS_IN;

            break;
        case 'O':
            event = ANSI_CSI_FCS_OUT;

            break;
        case 'f':
            event = ANSI_CSI_HVP;

            break;
        case 'J':
            event = reader->csi_dec_private ? ANSI_CSI_DECSED : ANSI_CSI_ED;

            break;
        case 'K':
            event = reader->csi_dec_private ? ANSI_CSI_DECSEL : ANSI_CSI_EL;

            break;
        case 'S':
            event = ANSI_CSI_SU;

            break;
        case 'T':
            event = ANSI_CSI_SD;

            break;
        case 'r':
            event = ANSI_CSI_DECSTBM;

            break;
        case 'm':
            event = ANSI_CSI_SGR;

            break;
        case 'h':
            event = reader->csi_dec_private ? ANSI_CSI_DECSET : ANSI_CSI_SM;

            break;
        case 'l':
            event = reader->csi_dec_private ? ANSI_CSI_DECRST : ANSI_CSI_RM;

            break;
        case 'n':
            event = reader->csi_dec_private ? ANSI_CSI_DEC_DSR : ANSI_CSI_DSR;

            break;
        case 'c':
            event = ANSI_CSI_DA;

            break;
        case 'b':
            event = ANSI_CSI_REP;

            break;
        case 'g':
            event = ANSI_CSI_TBC;

            break;
        case '~':
            if (reader->csi_parameters_count > 0) {
                int v = reader->csi_parameters[0];

                if (v == 200) event = ANSI_CSI_BRP_START;
                if (v == 201) event = ANSI_CSI_BRP_END;
            }

            break;
    }

    ansi.csi.event = event;
    ansi.csi.mode = ANSI_MODE_UNKNOWN;
    ansi.csi.dec_mode = ANSI_DEC_MODE_UNKNOWN;

    if (event == ANSI_CSI_DECSET || event == ANSI_CSI_DECRST) {
        if (ansi.csi.parameters_count > 0 && ansi.csi.parameters[0] > -1) ansi.csi.dec_mode = dec_mode(ansi.csi.parameters[0]);
    }

    if (event == ANSI_CSI_SM || event == ANSI_CSI_RM) {
        if (ansi.csi.parameters_count > 0 && ansi.csi.parameters[0] > -1) ansi.csi.mode = csi_mode(ansi.csi.parameters[0]);
    }

    if (event == ANSI_CSI_SGR) {
        ansi_sgr_t attributes;

        sgr_unset_attributes(&attributes);
        sgr_apply_parameters(&attributes, ansi.csi.parameters, ansi.csi.parameters_count);
        ansi.csi.attributes = attributes;
    }

    reader->on_ansi(reader->user_data, &ansi);
}

static inline void reset_osc(ansi_reader_t *reader) {
    reader->osc_length = 0;
    reader->osc_code = -1;

    if (reader->osc_capacity > 0) reader->osc_buffer[0] = '\0';
}

static void send_osc(ansi_reader_t *reader) {
    if (!reader->on_ansi || !reader->osc_buffer) return;

    size_t term = reader->osc_length < reader->osc_capacity ? reader->osc_length : (reader->osc_capacity - 1);

    reader->osc_buffer[term] = '\0';

    if (reader->osc_code < 0) {
        char *end = NULL;

        reader->osc_code = (int)strtol(reader->osc_buffer, &end, 10);

        if (!end || *end != ';') reader->osc_code = -1;
    }

    const char *payload = reader->osc_buffer;
    const char *split = strchr(reader->osc_buffer, ';');

    if (split) payload = split + 1;

    ansi_t ansi;

    ansi.event = ANSI_EVENT_OSC;
    ansi.osc.code = reader->osc_code;
    ansi.osc.payload = payload;

    ansi_osc_event_t event = ANSI_OSC_KIND_UNKNOWN;

    switch (reader->osc_code) {
        case 0:
        case 2:
            event = ANSI_OSC_SET_TITLE;

            break;
        case 8:
            event = ANSI_OSC_HYPERLINK;

            break;
        case 52:
            event = ANSI_OSC_CLIPBOARD;

            break;
    }

    ansi.osc.event = event;
    reader->on_ansi(reader->user_data, &ansi);
}

static void send_bell(ansi_reader_t *reader) {
    if (!reader->on_ansi) return;

    ansi_t ansi;

    ansi.event = ANSI_EVENT_BELL;
    reader->on_ansi(reader->user_data, &ansi);
}

static inline int utf8_expected_length(uint8_t lead) {
    if (lead <= 0x7Fu) return 1;
    if (lead >= 0xC2u && lead <= 0xDFu) return 2;
    if (lead >= 0xE0u && lead <= 0xEFu) return 3;
    if (lead >= 0xF0u && lead <= 0xF4u) return 4;

    return 0;
}

static inline bool utf8_incomplete(uint8_t byte) {
    return (byte & 0xC0u) == 0x80u;
}

static size_t utf8_incomplete_length(const uint8_t *bytes, size_t length) {
    if (length < 1) return 0;

    size_t continuation = 0;

    while (continuation < 3 && length > continuation && utf8_incomplete(bytes[length - 1 - continuation])) continuation++;

    if (continuation == 0) {
        uint8_t last = bytes[length - 1];
        size_t expected = utf8_expected_length(last);

        return expected > 1 ? 1 : 0;
    }

    if (length > continuation) {
        size_t lead_index = length - 1 - continuation;
        uint8_t lead = bytes[lead_index];
        size_t expected = utf8_expected_length(lead);

        if (expected == 0) return continuation;

        size_t have = length - lead_index;

        return have < expected ? have : 0;
    }

    return continuation;
}

ansi_reader_t *init_ansi_reader(void) {
    ansi_reader_t *reader = (ansi_reader_t *)calloc(1, sizeof(ansi_reader_t));

    if (!reader) {
        log_error("malloc failed: %zu", sizeof(ansi_reader_t));

        return NULL;
    }

    reader->state = STATE_GROUND;
    reader->utf8_length = 0;
    reset_csi(reader);
    reader->osc_capacity = _KB(8);
    reader->osc_buffer = (char *)malloc(reader->osc_capacity);

    if (!reader->osc_buffer) {
        log_error("malloc failed: %zu", reader->osc_capacity);
        free(reader);

        return NULL;
    }

    reset_osc(reader);
    reader->on_ansi = NULL;
    reader->user_data = NULL;

    return reader;
}

void free_ansi_reader(ansi_reader_t *reader) {
    if (!reader) return;

    free(reader->osc_buffer);
    free(reader);
}

void ansi_reader_reset(ansi_reader_t *reader) {
    reader->state = STATE_GROUND;
    reader->utf8_length = 0;
    reset_csi(reader);
    reset_osc(reader);
}

void ansi_reader_set_osc_capacity(ansi_reader_t *reader, size_t capacity) {
    if (capacity < 1) return;

    char *buffer = (char *)realloc(reader->osc_buffer, capacity);

    if (!buffer) {
        log_error("realloc failed: %zu", capacity);

        return;
    }

    reader->osc_buffer = buffer;
    reader->osc_capacity = capacity;

    if (reader->osc_length >= reader->osc_capacity) reader->osc_length = reader->osc_capacity - 1;
}

void ansi_reader_set_callback(ansi_reader_t *reader, ansi_reader_callback_t on_ansi, void *user_data) {
    reader->on_ansi = on_ansi;
    reader->user_data = user_data;
}

void ansi_reader_feed(ansi_reader_t *reader, const uint8_t *bytes, size_t length) {
    if (!bytes || length < 1) return;

    const uint8_t *start = bytes;
    size_t i = 0;

    if (reader->utf8_length > 0) {
        size_t expected = utf8_expected_length(reader->utf8[0]);

        if (expected == 0) {
            send_text(reader, reader->utf8, reader->utf8_length);
            reader->utf8_length = 0;
        } else {
            size_t need = expected - reader->utf8_length;
            size_t j = 0;

            while (j < length && j < need && utf8_incomplete(bytes[j])) reader->utf8[reader->utf8_length++] = bytes[j++];

            if (reader->utf8_length == expected) {
                send_text(reader, reader->utf8, expected);
                reader->utf8_length = 0;
                i = j;
                start = bytes + i;
            } else if (j < need && j < length) {
                send_text(reader, reader->utf8, reader->utf8_length);
                reader->utf8_length = 0;
            } else if (j == length) {
                return;
            }
        }
    }

    while (i < length) {
        uint8_t byte = bytes[i];

        switch (reader->state) {
            case STATE_GROUND: {
                if (byte == 0x1Bu) {
                    if (bytes + i > start) send_text(reader, start, (size_t)(bytes + i - start));

                    reader->state = STATE_ESC;
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 0x07u) {
                    if (bytes + i > start) send_text(reader, start, (size_t)(bytes + i - start));

                    send_bell(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 0x9Bu) {
                    if (bytes + i > start) send_text(reader, start, (size_t)(bytes + i - start));

                    reader->state = STATE_CSI;
                    reset_csi(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 0x9Du) {
                    if (bytes + i > start) send_text(reader, start, (size_t)(bytes + i - start));

                    reader->state = STATE_OSC;
                    reset_osc(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                i++;

                break;
            }
            case STATE_ESC: {
                if (byte == '[') {
                    reader->state = STATE_CSI;
                    reset_csi(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == ']') {
                    reader->state = STATE_OSC;
                    reset_osc(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == '7') {
                    send_esc(reader, ANSI_ESC_DEC_SAVE_CURSOR);
                    reader->state = STATE_GROUND;
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == '8') {
                    send_esc(reader, ANSI_ESC_DEC_RESTORE_CURSOR);
                    reader->state = STATE_GROUND;
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 'c') {
                    send_esc(reader, ANSI_ESC_RESET);
                    reader->state = STATE_GROUND;
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 'H') {
                    send_esc(reader, ANSI_ESC_TAB_SET);
                    reader->state = STATE_GROUND;
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 'D') {
                    send_esc(reader, ANSI_ESC_IND);
                    reader->state = STATE_GROUND;
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 'M') {
                    send_esc(reader, ANSI_ESC_RI);
                    reader->state = STATE_GROUND;
                    i++;
                    start = bytes + i;

                    continue;
                }

                send_unknown(reader, bytes + (i - 1), 2);
                reader->state = STATE_GROUND;
                i++;
                start = bytes + i;

                continue;
            }
            case STATE_CSI: {
                if (byte == '?' || byte == '>' || byte == '<' || byte == '!' || byte == ' ') {
                    if (byte == '?') reader->csi_dec_private = true;
                    if (reader->csi_intermediates_count < 5) reader->csi_intermediates[reader->csi_intermediates_count++] = (char)byte;

                    i++;

                    continue;
                }

                if (byte >= '0' && byte <= '9') {
                    int digit = (int)(byte - '0');

                    if (reader->csi_current < 0) reader->csi_current = 0;
                    if (reader->csi_current < 1000000) reader->csi_current = reader->csi_current * 10 + digit;

                    i++;

                    continue;
                }

                if (byte == ';' || byte == ':') {
                    if (reader->csi_parameters_count < ANSI_MAX_PARAMETERS) reader->csi_parameters[reader->csi_parameters_count++] = reader->csi_current > -1 ? reader->csi_current : -1;

                    reader->csi_current = -1;
                    i++;

                    continue;
                }

                if (byte >= 0x40u && byte <= 0x7Eu) {
                    send_csi(reader, (char)byte);
                    reader->state = STATE_GROUND;
                    reset_csi(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                i++;

                continue;
            }
            case STATE_OSC: {
                if (byte == 0x07u) {
                    send_osc(reader);
                    reader->state = STATE_GROUND;
                    reset_osc(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (byte == 0x1Bu) {
                    reader->state = STATE_OSC_MAYBE_ST;
                    i++;

                    continue;
                }

                if (reader->osc_length + 1 < reader->osc_capacity) {
                    reader->osc_buffer[reader->osc_length++] = (char)byte;
                } else if (reader->osc_length < reader->osc_capacity) {
                    reader->osc_length = reader->osc_capacity;
                }

                i++;

                continue;
            }
            case STATE_OSC_MAYBE_ST: {
                if (byte == '\\') {
                    send_osc(reader);
                    reader->state = STATE_GROUND;
                    reset_osc(reader);
                    i++;
                    start = bytes + i;

                    continue;
                }

                if (reader->osc_length + 1 < reader->osc_capacity) reader->osc_buffer[reader->osc_length++] = 0x1Bu;

                reader->state = STATE_OSC;

                continue;
            }
        }
    }

    if (reader->state == STATE_GROUND && bytes + i > start) {
        size_t text_length = (size_t)(bytes + i - start);
        size_t withhold = utf8_incomplete_length(start, text_length);

        if (withhold < text_length) send_text(reader, start, text_length - withhold);

        if (withhold > 0) {
            size_t offset = text_length - withhold;
            size_t utf8_length = withhold < sizeof(reader->utf8) ? withhold : sizeof(reader->utf8);

            memcpy(reader->utf8, start + offset, utf8_length);
            reader->utf8_length = utf8_length;
        }
    }
}
