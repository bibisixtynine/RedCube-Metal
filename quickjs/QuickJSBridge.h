#ifndef QuickJSBridge_h
#define QuickJSBridge_h

#include <stdio.h>

typedef char* (*SpawnCallback)(const char* type, const char* name);
typedef void (*SetPositionCallback)(const char* id, float x, float y, float z);
typedef void (*SetRotationCallback)(const char* id, float x, float y, float z);
typedef void (*SetScaleCallback)(const char* id, float x, float y, float z);
typedef void (*SetColorCallback)(const char* id, float r, float g, float b, float a, float metallic, float roughness);
typedef void (*RemoveCallback)(const char* id);
typedef void (*SetCameraCallback)(float px, float py, float pz, float tx, float ty, float tz);
typedef void (*SetPhysicsCallback)(const char* id, const char* mode);
typedef void (*SetTextureCallback)(const char* id, const char* name);
typedef void (*SetLockCallback)(const char* id, int locked);
typedef void (*SetCameraModeCallback)(const char* mode);
typedef void (*AttachToCallback)(const char* child_id, const char* parent_id);

void qjs_init(SpawnCallback spawn, SetPositionCallback pos, SetRotationCallback rot, SetScaleCallback scale, SetColorCallback color, RemoveCallback remove, SetCameraCallback camera, SetPhysicsCallback physics, SetTextureCallback texture, SetLockCallback lock, AttachToCallback attach, SetCameraModeCallback camera_mode);
void qjs_reset(SpawnCallback spawn, SetPositionCallback pos, SetRotationCallback rot, SetScaleCallback scale, SetColorCallback color, RemoveCallback remove, SetCameraCallback camera, SetPhysicsCallback physics, SetTextureCallback texture, SetLockCallback lock, AttachToCallback attach, SetCameraModeCallback camera_mode);
void qjs_run_script(const char *filename);
void qjs_run_code(const char *code);
void qjs_send_event(const char *type, double x, double y);
void qjs_on_frame(double timestamp);
void qjs_cleanup(void);

#endif /* QuickJSBridge_h */
