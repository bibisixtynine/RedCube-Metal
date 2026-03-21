#include "QuickJSBridge.h"
#include "quickjs.h"
#include "quickjs-libc.h"
#include <string.h>

static JSRuntime *rt;
static JSContext *ctx;
static SpawnCallback spawn_cb;
static SetPositionCallback pos_cb;
static SetRotationCallback rot_cb;
static SetScaleCallback scale_cb;
static SetColorCallback color_cb;
static RemoveCallback remove_cb;
static SetCameraCallback camera_cb;
static SetPhysicsCallback physics_cb;
static SetTextureCallback texture_cb;
static SetLockCallback lock_cb;
static AttachToCallback attach_cb;
static SetCameraModeCallback camera_mode_cb;
static JSValue animation_callback = JS_UNDEFINED;

static JSValue js_console_log(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    for (int i = 0; i < argc; i++) {
        const char *str = JS_ToCString(ctx, argv[i]);
        if (str) {
            printf("%s%s", i > 0 ? " " : "", str);
            JS_FreeCString(ctx, str);
        }
    }
    printf("\n");
    fflush(stdout);
    return JS_UNDEFINED;
}

static JSValue js_spawn(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_EXCEPTION;
    const char *type = JS_ToCString(ctx, argv[0]);
    const char *name = (argc > 1) ? JS_ToCString(ctx, argv[1]) : "";
    char *id = spawn_cb(type, name);
    JSValue res = JS_NewString(ctx, id);
    JS_FreeCString(ctx, type);
    if (argc > 1) JS_FreeCString(ctx, name);
    return res;
}

static JSValue js_setPosition(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 4) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    double x, y, z;
    JS_ToFloat64(ctx, &x, argv[1]);
    JS_ToFloat64(ctx, &y, argv[2]);
    JS_ToFloat64(ctx, &z, argv[3]);
    pos_cb(id, (float)x, (float)y, (float)z);
    JS_FreeCString(ctx, id);
    return JS_UNDEFINED;
}

static JSValue js_attachTo(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    const char *parentId = (argc > 1 && !JS_IsNull(argv[1]) && !JS_IsUndefined(argv[1])) ? JS_ToCString(ctx, argv[1]) : NULL;
    attach_cb(id, parentId);
    JS_FreeCString(ctx, id);
    if (parentId) JS_FreeCString(ctx, parentId);
    return JS_UNDEFINED;
}

static JSValue js_setRotation(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 4) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    double x, y, z;
    JS_ToFloat64(ctx, &x, argv[1]);
    JS_ToFloat64(ctx, &y, argv[2]);
    JS_ToFloat64(ctx, &z, argv[3]);
    rot_cb(id, (float)x, (float)y, (float)z);
    JS_FreeCString(ctx, id);
    return JS_UNDEFINED;
}

static JSValue js_setScale(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 4) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    double x, y, z;
    JS_ToFloat64(ctx, &x, argv[1]);
    JS_ToFloat64(ctx, &y, argv[2]);
    JS_ToFloat64(ctx, &z, argv[3]);
    scale_cb(id, (float)x, (float)y, (float)z);
    JS_FreeCString(ctx, id);
    return JS_UNDEFINED;
}

static JSValue js_setColor(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 5) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    double r, g, b, a, metallic = 0, roughness = 0.5;
    JS_ToFloat64(ctx, &r, argv[1]);
    JS_ToFloat64(ctx, &g, argv[2]);
    JS_ToFloat64(ctx, &b, argv[3]);
    JS_ToFloat64(ctx, &a, argv[4]);
    if (argc > 5) JS_ToFloat64(ctx, &metallic, argv[5]);
    if (argc > 6) JS_ToFloat64(ctx, &roughness, argv[6]);
    color_cb(id, (float)r, (float)g, (float)b, (float)a, (float)metallic, (float)roughness);
    JS_FreeCString(ctx, id);
    return JS_UNDEFINED;
}

static JSValue js_remove(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    remove_cb(id);
    JS_FreeCString(ctx, id);
    return JS_UNDEFINED;
}

static JSValue js_setCamera(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 6) return JS_EXCEPTION;
    double px, py, pz, tx, ty, tz;
    JS_ToFloat64(ctx, &px, argv[0]);
    JS_ToFloat64(ctx, &py, argv[1]);
    JS_ToFloat64(ctx, &pz, argv[2]);
    JS_ToFloat64(ctx, &tx, argv[3]);
    JS_ToFloat64(ctx, &ty, argv[4]);
    JS_ToFloat64(ctx, &tz, argv[5]);
    camera_cb((float)px, (float)py, (float)pz, (float)tx, (float)ty, (float)tz);
    return JS_UNDEFINED;
}

static JSValue js_setPhysics(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 2) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    const char *mode = JS_ToCString(ctx, argv[1]);
    physics_cb(id, mode);
    JS_FreeCString(ctx, id);
    JS_FreeCString(ctx, mode);
    return JS_UNDEFINED;
}

static JSValue js_setTexture(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 2) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    const char *name = JS_ToCString(ctx, argv[1]);
    texture_cb(id, name);
    JS_FreeCString(ctx, id);
    JS_FreeCString(ctx, name);
    return JS_UNDEFINED;
}

static JSValue js_requestAnimationFrame(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsFunction(ctx, argv[0])) return JS_UNDEFINED;
    JS_FreeValue(ctx, animation_callback);
    animation_callback = JS_DupValue(ctx, argv[0]);
    return JS_NewInt32(ctx, 0);
}

static JSValue js_cameraMode(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_EXCEPTION;
    const char *mode = JS_ToCString(ctx, argv[0]);
    camera_mode_cb(mode);
    JS_FreeCString(ctx, mode);
    return JS_UNDEFINED;
}

static JSValue js_lock(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    lock_cb(id, 1);
    JS_FreeCString(ctx, id);
    return JS_UNDEFINED;
}

static JSValue js_unlock(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_EXCEPTION;
    const char *id = JS_ToCString(ctx, argv[0]);
    lock_cb(id, 0);
    JS_FreeCString(ctx, id);
    return JS_UNDEFINED;
}

void qjs_init(SpawnCallback spawn, SetPositionCallback pos, SetRotationCallback rot, SetScaleCallback scale, SetColorCallback color, RemoveCallback remove, SetCameraCallback camera, SetPhysicsCallback physics, SetTextureCallback texture, SetLockCallback lock, AttachToCallback attach, SetCameraModeCallback camera_mode) {
    if (rt) return;
    rt = JS_NewRuntime();
    ctx = JS_NewContext(rt);
    spawn_cb = spawn;
    pos_cb = pos;
    rot_cb = rot;
    scale_cb = scale;
    color_cb = color;
    remove_cb = remove;
    camera_cb = camera;
    physics_cb = physics;
    texture_cb = texture;
    lock_cb = lock;
    attach_cb = attach;
    camera_mode_cb = camera_mode;
    animation_callback = JS_UNDEFINED;
    js_std_add_helpers(ctx, 0, NULL);
    JSValue global_obj = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global_obj, "spawn", JS_NewCFunction(ctx, js_spawn, "spawn", 1));
    JS_SetPropertyStr(ctx, global_obj, "setPosition", JS_NewCFunction(ctx, js_setPosition, "setPosition", 4));
    JS_SetPropertyStr(ctx, global_obj, "setRotation", JS_NewCFunction(ctx, js_setRotation, "setRotation", 4));
    JS_SetPropertyStr(ctx, global_obj, "setScale", JS_NewCFunction(ctx, js_setScale, "setScale", 4));
    JS_SetPropertyStr(ctx, global_obj, "setColor", JS_NewCFunction(ctx, js_setColor, "setColor", 5));
    JS_SetPropertyStr(ctx, global_obj, "remove", JS_NewCFunction(ctx, js_remove, "remove", 1));
    JS_SetPropertyStr(ctx, global_obj, "setCamera", JS_NewCFunction(ctx, js_setCamera, "setCamera", 6));
    JS_SetPropertyStr(ctx, global_obj, "setPhysics", JS_NewCFunction(ctx, js_setPhysics, "setPhysics", 2));
    JS_SetPropertyStr(ctx, global_obj, "setTexture", JS_NewCFunction(ctx, js_setTexture, "setTexture", 2));
    JS_SetPropertyStr(ctx, global_obj, "lock", JS_NewCFunction(ctx, js_lock, "lock", 1));
    JS_SetPropertyStr(ctx, global_obj, "unlock", JS_NewCFunction(ctx, js_unlock, "unlock", 1));
    JS_SetPropertyStr(ctx, global_obj, "attachTo", JS_NewCFunction(ctx, js_attachTo, "attachTo", 2));
    JS_SetPropertyStr(ctx, global_obj, "cameraMode", JS_NewCFunction(ctx, js_cameraMode, "cameraMode", 1));
    JS_SetPropertyStr(ctx, global_obj, "requestAnimationFrame", JS_NewCFunction(ctx, js_requestAnimationFrame, "requestAnimationFrame", 1));
    JSValue console = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, console, "log", JS_NewCFunction(ctx, js_console_log, "log", 1));
    JS_SetPropertyStr(ctx, global_obj, "console", console);
    JS_FreeValue(ctx, global_obj);

    // Object-Oriented Style Wrapper
    const char *oo_prelude =
        "(function() {"
        "  const _spawn = globalThis.spawn;"
        "  globalThis.spawn = function(type, name) {"
        "    const id = _spawn(type, name);"
        "    return {"
        "      id: id,"
        "      toString: function() { return this.id; },"
        "      setPosition: function(x, y, z) { setPosition(this.id, x, y, z); return this; },"
        "      setRotation: function(x, y, z) { setRotation(this.id, x, y, z); return this; },"
        "      setScale: function(x, y, z) { setScale(this.id, x, y, z); return this; },"
        "      setColor: function(r, g, b, a, m, r2) { setColor(this.id, r, g, b, a, m, r2); return this; },"
        "      setPhysics: function(mode) { setPhysics(this.id, mode); return this; },"
        "      setTexture: function(name) { setTexture(this.id, name); return this; },"
        "      remove: function() { remove(this.id); },"
        "      lock: function() { lock(this.id); },"
        "      unlock: function() { unlock(this.id); },"
        "      attachTo: function(parent) { attachTo(this.id, parent?.id || parent); return this; }"
        "    };"
        "  };"
        "})();";
    qjs_run_code(oo_prelude);
}

void qjs_reset(SpawnCallback spawn, SetPositionCallback pos, SetRotationCallback rot, SetScaleCallback scale, SetColorCallback color, RemoveCallback remove, SetCameraCallback camera, SetPhysicsCallback physics, SetTextureCallback texture, SetLockCallback lock, AttachToCallback attach, SetCameraModeCallback camera_mode) {
    qjs_cleanup();
    qjs_init(spawn, pos, rot, scale, color, remove, camera, physics, texture, lock, attach, camera_mode);
}

void qjs_run_script(const char *filename) {
    if (!ctx) return;
    size_t psize;
    uint8_t *buf = js_load_file(ctx, &psize, filename);
    if (!buf) return;
    JSValue val = JS_Eval(ctx, (const char *)buf, psize, filename, JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(val)) js_std_dump_error(ctx);
    JS_FreeValue(ctx, val);
    js_free(ctx, buf);
}

void qjs_run_code(const char *code) {
    if (!ctx) return;
    JSValue val = JS_Eval(ctx, code, strlen(code), "<input>", JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(val)) js_std_dump_error(ctx);
    JS_FreeValue(ctx, val);
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
    if (ctx) {
        JS_FreeValue(ctx, animation_callback);
        animation_callback = JS_UNDEFINED;
        JS_FreeContext(ctx);
    }
    if (rt) JS_FreeRuntime(rt);
    ctx = NULL;
    rt = NULL;
}
