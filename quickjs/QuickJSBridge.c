#include "QuickJSBridge.h"
#include "quickjs.h"
#include "quickjs-libc.h"
#include <string.h>

static JSRuntime *rt;
static JSContext *ctx;
static DrawCubeCallback draw_cube_callback;
static SetCameraCallback set_camera_callback;
static ClearCubesCallback clear_cubes_callback;
static JSValue animation_callback = JS_UNDEFINED;

static JSValue js_drawCube(JSContext *ctx, JSValueConst this_val,
                           int argc, JSValueConst *argv) {
    if (argc < 4) return JS_UNDEFINED;
    double x, y, z, size;
    if (JS_ToFloat64(ctx, &x, argv[0])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &y, argv[1])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &z, argv[2])) return JS_EXCEPTION;
    if (JS_ToFloat64(ctx, &size, argv[3])) return JS_EXCEPTION;

    float r = -1.0f, g = -1.0f, b = -1.0f, a = -1.0f;
    
    if (argc >= 5 && JS_IsString(argv[4])) {
        const char *hex = JS_ToCString(ctx, argv[4]);
        if (hex && hex[0] == '#' && strlen(hex) == 9) {
            unsigned int ai, ri, gi, bi;
            if (sscanf(hex + 1, "%02x%02x%02x%02x", &ai, &ri, &gi, &bi) == 4) {
                a = ai / 255.0f;
                r = ri / 255.0f;
                g = gi / 255.0f;
                b = bi / 255.0f;
            }
        }
        JS_FreeCString(ctx, hex);
    }

    if (draw_cube_callback) {
        draw_cube_callback((float)x, (float)y, (float)z, (float)size, r, g, b, a);
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

static JSValue js_clearCubes(JSContext *ctx, JSValueConst this_val,
                             int argc, JSValueConst *argv) {
    if (clear_cubes_callback) {
        clear_cubes_callback();
    }
    return JS_UNDEFINED;
}

static JSValue js_requestAnimationFrame(JSContext *ctx, JSValueConst this_val,
                                        int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsFunction(ctx, argv[0]))
        return JS_UNDEFINED;
    
    JS_FreeValue(ctx, animation_callback);
    animation_callback = JS_DupValue(ctx, argv[0]);
    
    return JS_NewInt32(ctx, 0); // Dummy ID
}

void qjs_init(DrawCubeCallback draw_cb, SetCameraCallback camera_cb, ClearCubesCallback clear_cb) {
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
    clear_cubes_callback = clear_cb;
    animation_callback = JS_UNDEFINED;

    js_std_add_helpers(ctx, 0, NULL);

    JSValue global_obj = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global_obj, "drawCube",
                      JS_NewCFunction(ctx, js_drawCube, "drawCube", 4));
    JS_SetPropertyStr(ctx, global_obj, "setCamera",
                      JS_NewCFunction(ctx, js_setCamera, "setCamera", 6));
    JS_SetPropertyStr(ctx, global_obj, "clearCubes",
                      JS_NewCFunction(ctx, js_clearCubes, "clearCubes", 0));
    JS_SetPropertyStr(ctx, global_obj, "requestAnimationFrame",
                      JS_NewCFunction(ctx, js_requestAnimationFrame, "requestAnimationFrame", 1));
    JS_FreeValue(ctx, global_obj);
    printf("qjs_init: Finished\n");
    fflush(stdout);
}

void qjs_reset(DrawCubeCallback draw_cb, SetCameraCallback camera_cb, ClearCubesCallback clear_cb) {
    qjs_cleanup();
    qjs_init(draw_cb, camera_cb, clear_cb);
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

void qjs_send_event(const char *type, double x, double y) {
    if (!ctx) return;
    
    JSValue global_obj = JS_GetGlobalObject(ctx);
    JSValue func = JS_GetPropertyStr(ctx, global_obj, "_onEvent");
    
    if (JS_IsFunction(ctx, func)) {
        JSValue args[3];
        args[0] = JS_NewString(ctx, type);
        args[1] = JS_NewFloat64(ctx, x);
        args[2] = JS_NewFloat64(ctx, y);
        
        JSValue ret = JS_Call(ctx, func, global_obj, 3, args);
        
        JS_FreeValue(ctx, args[0]);
        JS_FreeValue(ctx, args[1]);
        JS_FreeValue(ctx, args[2]);
        JS_FreeValue(ctx, ret);
    }
    
    JS_FreeValue(ctx, func);
    JS_FreeValue(ctx, global_obj);
}

void qjs_on_frame(double timestamp) {
    if (!ctx || JS_IsUndefined(animation_callback)) return;
    
    JSValue cb = animation_callback;
    animation_callback = JS_UNDEFINED;
    
    JSValue args[1];
    args[0] = JS_NewFloat64(ctx, timestamp);
    
    JSValue ret = JS_Call(ctx, cb, JS_UNDEFINED, 1, args);
    
    JS_FreeValue(ctx, cb);
    JS_FreeValue(ctx, args[0]);
    JS_FreeValue(ctx, ret);
}

void qjs_cleanup(void) {
    printf("qjs_cleanup\n");
    fflush(stdout);
    if (ctx) {
        JS_FreeValue(ctx, animation_callback);
        animation_callback = JS_UNDEFINED;
        JS_FreeContext(ctx);
    }
    if (rt) JS_FreeRuntime(rt);
    ctx = NULL;
    rt = NULL;
}
