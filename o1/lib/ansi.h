//
//  ansi.h
//  o1
//
//  Created by gpt-5-high on 2025-10-12.
//

#ifndef ANSI_H
#define ANSI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define ANSI_MAX_PARAMETERS 16
#define ANSI_COLOR_RESET 0xFFFFFFFFu

typedef enum ansi_event_t {
    ANSI_EVENT_UNKNOWN = 0,
    ANSI_EVENT_TEXT,
    ANSI_EVENT_ESC,
    ANSI_EVENT_CSI,
    ANSI_EVENT_OSC,
    ANSI_EVENT_BELL,
} ansi_event_t;

typedef struct ansi_text_t {
    const uint8_t *bytes;
    size_t length;
} ansi_text_t;

typedef enum ansi_esc_event_t {
    ANSI_ESC_DEC_SAVE_CURSOR = 0,
    ANSI_ESC_DEC_RESTORE_CURSOR,
    ANSI_ESC_TAB_SET,
    ANSI_ESC_IND,
    ANSI_ESC_RI,
    ANSI_ESC_RESET,
} ansi_esc_event_t;

typedef struct ansi_esc_t {
    ansi_esc_event_t event;
} ansi_esc_t;

typedef enum ansi_csi_event_t {
    ANSI_CSI_KIND_UNKNOWN = 0,
    ANSI_CSI_CUU,
    ANSI_CSI_CUD,
    ANSI_CSI_CUF,
    ANSI_CSI_CUB,
    ANSI_CSI_CNL,
    ANSI_CSI_CPL,
    ANSI_CSI_CHA,
    ANSI_CSI_CUP,
    ANSI_CSI_HVP,
    ANSI_CSI_ED,
    ANSI_CSI_EL,
    ANSI_CSI_DECSED,
    ANSI_CSI_DECSEL,
    ANSI_CSI_SU,
    ANSI_CSI_SD,
    ANSI_CSI_DECSTBM,
    ANSI_CSI_SGR,
    ANSI_CSI_SM,
    ANSI_CSI_RM,
    ANSI_CSI_DECSET,
    ANSI_CSI_DECRST,
    ANSI_CSI_DSR,
    ANSI_CSI_DEC_DSR,
    ANSI_CSI_DA,
    ANSI_CSI_REP,
    ANSI_CSI_TBC,
    ANSI_CSI_BRP_START,
    ANSI_CSI_BRP_END,
} ansi_csi_event_t;

typedef enum ansi_mode_t {
    ANSI_MODE_UNKNOWN = 0,
    ANSI_MODE_INSERT = 4,
} ansi_mode_t;

typedef enum ansi_dec_mode_t {
    ANSI_DEC_MODE_UNKNOWN = 0,
    ANSI_DEC_MODE_ORIGIN = 6,
    ANSI_DEC_MODE_AUTO_WRAP = 7,
    ANSI_DEC_MODE_CURSOR_BLINK = 12,
    ANSI_DEC_MODE_CURSOR_VISIBLE = 25,
    ANSI_DEC_MODE_MOUSE_X10 = 1000,
    ANSI_DEC_MODE_MOUSE_NORMAL = 1002,
    ANSI_DEC_MODE_MOUSE_ALL = 1003,
    ANSI_DEC_MODE_FOCUS_REPORT = 1004,
    ANSI_DEC_MODE_MOUSE_SGR = 1006,
    ANSI_DEC_MODE_BRACKETED_PASTE = 2004,
} ansi_dec_mode_t;

typedef enum ansi_sgr_flag_t {
    ANSI_SGR_FLAG_NONE = 0,
    ANSI_SGR_FLAG_BOLD = 1u << 0,
    ANSI_SGR_FLAG_FAINT = 1u << 1,
    ANSI_SGR_FLAG_ITALIC = 1u << 2,
    ANSI_SGR_FLAG_UNDERLINE = 1u << 3,
    ANSI_SGR_FLAG_BLINK = 1u << 4,
    ANSI_SGR_FLAG_INVERSE = 1u << 5,
    ANSI_SGR_FLAG_HIDDEN = 1u << 6,
    ANSI_SGR_FLAG_STRIKE = 1u << 7,
} ansi_sgr_flag_t;

typedef struct ansi_sgr_t {
    uint32_t flags;
    uint32_t fg_color;
    uint32_t bg_color;
} ansi_sgr_t;

typedef struct ansi_csi_t {
    bool dec_private;
    char intermediates[5];
    size_t intermediates_count;
    int parameters[ANSI_MAX_PARAMETERS];
    size_t parameters_count;
    char final_byte;
    ansi_csi_event_t event;
    ansi_sgr_t attributes;
    ansi_mode_t mode;
    ansi_dec_mode_t dec_mode;
} ansi_csi_t;

typedef enum ansi_osc_event_t {
    ANSI_OSC_KIND_UNKNOWN = 0,
    ANSI_OSC_SET_TITLE,
    ANSI_OSC_HYPERLINK,
    ANSI_OSC_CLIPBOARD,
} ansi_osc_event_t;

typedef struct ansi_osc_t {
    int code;
    const char *payload;
    ansi_osc_event_t event;
} ansi_osc_t;

typedef struct ansi_unknown_t {
    const uint8_t *bytes;
    size_t length;
} ansi_unknown_t;

typedef struct ansi_t {
    ansi_event_t event;
    union {
        ansi_text_t text;
        ansi_esc_t esc;
        ansi_csi_t csi;
        ansi_osc_t osc;
        ansi_unknown_t unknown;
    };
} ansi_t;

typedef enum ansi_color_t {
    ANSI_COLOR_DEFAULT = 0,
    ANSI_COLOR_INDEXED,
    ANSI_COLOR_RGB,
} ansi_color_t;

uint32_t ansi_color_pack_indexed(int index);

uint32_t ansi_color_pack_rgb(uint8_t red, uint8_t green, uint8_t blue);

ansi_color_t ansi_color_unpack(uint32_t color, int *index, uint8_t *red, uint8_t *green, uint8_t *blue);

#endif // !ANSI_H
