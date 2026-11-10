/* core/include/als/als_core_api.h — C interfész a Flutter (dart:ffi) felülethez.
 * A Dart oldal ezt a néhány függvényt hívja; minden C++ objektum a magban marad. */
#ifndef ALS_CORE_API_H
#define ALS_CORE_API_H
#include <stdint.h>

#if defined(_WIN32)
#  define ALS_API __declspec(dllexport)
#else
#  define ALS_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* MIDI real-time esemény (0xF8 Clock, 0xFA Start, 0xFC Stop) a Smart Readernek */
typedef void (*als_realtime_cb)(int32_t status, int64_t ts_us);

/* Portlista "IN:név\n...OUT:név\n" formában; visszatér a szükséges hosszal */
ALS_API int32_t als_list_ports(char* buf, int32_t buflen);

/* in_port = -1: csak kimenet. use_console = 1: hangszer nélküli teszt. 0 = siker */
ALS_API int32_t als_open(int32_t in_port, int32_t out_port, int32_t use_console);
ALS_API void    als_close(void);
ALS_API void    als_set_realtime_callback(als_realtime_cb cb);

/* Ugyanaz a monoton óra (µs), amelyből a MIDI időbélyegek jönnek */
ALS_API int64_t als_now_us(void);

ALS_API int32_t als_style_start(void);
ALS_API int32_t als_style_stop(void);
ALS_API int32_t als_section(int32_t code);         /* Yamaha szakaszkód, pl. 0x08 = Main A */
ALS_API int32_t als_tempo(double bpm);

/* Tetszőleges MIDI-üzenet(ek) küldése (pl. dal lejátszása a hangszeren) */
ALS_API int32_t als_send_raw(const uint8_t* data, int32_t len);

ALS_API int32_t als_set_zone(int32_t slot, int32_t enabled, int32_t low, int32_t high,
                             int32_t vel_low, int32_t vel_high, int32_t transpose,
                             float vel_curve, int32_t out_channel);

/* Hangszín választása egy csatornán: Bank MSB/LSB + Program Change + hangerő (CC7).
 * channel 0-alapú (0 = MIDI ch1). */
ALS_API int32_t als_voice(int32_t channel, int32_t msb, int32_t lsb, int32_t program, int32_t volume);

/* Rendszer fájlmegnyitó ablak (Windows). ext pl. "wav" vagy "txt".
 * A kiválasztott út UTF-8-ban kerül az out bufferbe. 0 = kiválasztva, 1 = mégse, -1 = nem támogatott */
ALS_API int32_t als_open_file_dialog(const char* title, const char* ext, char* out, int32_t out_len);

/* Sample-vágás (UTF-8 utakkal); a riportot JSON-ként írja a report bufferbe. 0 = siker */
ALS_API int32_t als_trim_wav(const char* in_path, const char* out_path,
                             char* report, int32_t report_len);

/* Paraméterezett vágás (Sample Studio). fade_tail/trim_head/trim_tail: 0/1 */
ALS_API int32_t als_trim_wav_ex(const char* in_path, const char* out_path,
                                double start_thresh_db, double tail_thresh_db,
                                int32_t trim_head, int32_t trim_tail, int32_t fade_tail,
                                char* report, int32_t report_len);

/* Loop-pont keresés (Loop Studio): a kimenet 'smpl' blokkal (loop pontokkal) íródik.
 * crossfade_ms = 0: a minták érintetlenek maradnak. */
ALS_API int32_t als_loop_wav(const char* in_path, const char* out_path,
                             double min_loop_ms, double crossfade_ms, int32_t unity_note,
                             char* report, int32_t report_len);

#ifdef __cplusplus
}
#endif
#endif
