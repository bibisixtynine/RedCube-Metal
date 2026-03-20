#ifndef QuickJSBridge_h
#define QuickJSBridge_h

#include <stdio.h>

typedef void (*DrawCubeCallback)(float x, float y, float z, float size);
typedef void (*SetCameraCallback)(float px, float py, float pz, float tx, float ty, float tz);
typedef void (*ClearCubesCallback)(void);

void qjs_init(DrawCubeCallback draw_callback, SetCameraCallback camera_callback, ClearCubesCallback clear_callback);
void qjs_reset(DrawCubeCallback draw_callback, SetCameraCallback camera_callback, ClearCubesCallback clear_callback);
void qjs_run_script(const char *filename);
void qjs_run_code(const char *code);
void qjs_send_event(const char *type, double x, double y);
void qjs_on_frame(double timestamp);
void qjs_cleanup(void);

#endif /* QuickJSBridge_h */
