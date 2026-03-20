#include "QuickJSBridge.h"
#include "quickjs.h"
#include "quickjs-libc.h"
#include <string.h>

static JSRuntime *rt;
static JSContext *ctx;
static DrawCubeCallback draw_cube_callback;
static SetCameraCallback set_camera_callback;

static JSValue js_drawCube(JSContext *ctx, JSValueConst this_val,
                           int argc, JSValueConst *argv) {
    if (argc < 4) return JS_UNDEFINED;
    double x, y, z, size;
    if (JS_ToFloat64(ctx, &x, argv[0])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &y, argv[1])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &z, argv[2])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &size, argv[3])) return JS_EXCEPTION;

    if (draw_cube_callback) {
        draw_cube_callback((float)x, (float)y, (float)z, (float)size);
    }

    return JS_UNDEFINED;
}

static JSValue js_setCamera(JSContext *ctx, JSValueConst this_val,
                            int argc, JSValueConst *argv) {
    if (argc < 6) return JS_UNDEFINED;
    double px, py, pz, tx, ty, tz;
    if (JS_ToFloat64(ctx, &px, argv[0])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &py, argv[1])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &pz, argv[2])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &tx, argv[3])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &ty, argv[4])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &tz, argv[5])) return JS_EXCEPTION;

    if (set_camera_callback) {
        set_camera_callback((float)px, (float)py, (float)pz, 
                            (float)tx, (float)ty, (float)tz);
    }

    return JS_UNDEFINED;
}

void qjs_init(DrawCubeCallback draw_cb, SetCameraCallback camera_cb) {
    if (rt) {
        printf("qjs_init: Already initialized\n");
        fflush(stdout);
        return;
    }
    printf("qjs_init: Initializing QuickJS\n");
    fflush(stdout);
    
    rt = JS_NewRuntime();
    if (!rt) { printf("Failed to create JSRuntime\n"); fflush(stdout); return; }
    
    ctx = JS_NewContext(rt);
    if (!ctx) { printf("Failed to create JSContext\n"); fflush(stdout); return; }
    
    draw_cube_callback = draw_cb;
    set_camera_callback = camera_cb;

    js_std_add_helpers(ctx, 0, NULL);

    JSValue global_obj = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global_obj, "drawCube",
                      JS_NewCFunction(ctx, js_drawCube, "drawCube", 4));
    JS_SetPropertyStr(ctx, global_obj, "setCamera",
                      JS_NewCFunction(ctx, js_setCamera, "setCamera", 6));
    JS_FreeValue(ctx, global_obj);
    printf("qjs_init: Finished\n");
    fflush(stdout);
}

void qjs_run_script(const char *filename) {
    printf("qjs_run_script: %s\n", filename);
    fflush(stdout);
    if (!ctx) { printf("qjs_run_script: ctx is NULL\n"); fflush(stdout); return; }
    size_t psize;
    uint8_t *buf = js_load_file(ctx, &psize, filename);
    if (!buf) {
        fprintf(stderr, "Could not load script: %s\n", filename);
        return;
    }

    JSValue val = JS_Eval(ctx, (const char *)buf, psize, filename, JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(val)) {
        js_std_dump_error(ctx);
    }
    JS_FreeValue(ctx, val);
    js_free(ctx, buf);
}

void qjs_run_code(const char *code) {
    printf("qjs_run_code: Starting eval\n");
    fflush(stdout);
    if (!ctx) { printf("qjs_run_code: ctx is NULL\n"); fflush(stdout); return; }
    
    JSValue val = JS_Eval(ctx, code, strlen(code), "<input>", JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(val)) {
        printf("qjs_run_code: Exception in JS\n");
        fflush(stdout);
        js_std_dump_error(ctx);
    }
    JS_FreeValue(ctx, val);
    printf("qjs_run_code: Done\n");
    fflush(stdout);
}

void qjs_cleanup(void) {
    printf("qjs_cleanup\n");
    fflush(stdout);
    if (ctx) JS_FreeContext(ctx);
    if (rt) JS_FreeRuntime(rt);
    ctx = NULL;
    rt = NULL;
}
