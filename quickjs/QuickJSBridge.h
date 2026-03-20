#ifndef QuickJSBridge_h
#define QuickJSBridge_h

#include <stdio.h>

typedef void (*DrawCubeCallback)(float x, float y, float z, float size);

void qjs_init(DrawCubeCallback callback);
void qjs_run_script(const char *filename);
void qjs_run_code(const char *code);
void qjs_cleanup(void);

#endif /* QuickJSBridge_h */
