/* hidpi-xwl-shim -- preloaded into the rootful Xwayland that hidpi-run starts.
 * Part of MATE Wayland Desktop.
 *
 * Xwayland hardcodes its window title ("Xwayland on :N") and application id
 * ("org.freedesktop.Xwayland"), so the taskbar cannot tell which app is in
 * the window. This replaces both with the real app's, taken from:
 *   HIDPI_TITLE    window title  (the app's Name)
 *   HIDPI_APP_ID   application id (the app's .desktop basename -> its icon)
 * and, when HIDPI_DECOR=server, asks the compositor to draw the title bar so
 * the window has the same frame and close button as every other window.
 *
 * Build: packaging/build-session-deb.sh compiles it into
 * /usr/lib/mate-wayland-desktop/hidpi-xwl-shim.so
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

struct libdecor_frame;

static void *next(const char *name) { return dlsym(RTLD_NEXT, name); }

static const char *env(const char *name)
{
    const char *v = getenv(name);
    return (v && *v) ? v : NULL;
}

void libdecor_frame_set_title(struct libdecor_frame *frame, const char *title)
{
    void (*real)(struct libdecor_frame *, const char *) = next(__func__);
    const char *t = env("HIDPI_TITLE");
    if (real) real(frame, t ? t : title);
}

void libdecor_frame_set_app_id(struct libdecor_frame *frame, const char *app_id)
{
    void (*real)(struct libdecor_frame *, const char *) = next(__func__);
    const char *a = env("HIDPI_APP_ID");
    if (real) real(frame, a ? a : app_id);
}

void libdecor_frame_map(struct libdecor_frame *frame)
{
    void (*real)(struct libdecor_frame *) = next(__func__);
    const char *d = env("HIDPI_DECOR");
    if (d && strcmp(d, "server") == 0) {
        /* visible=true makes libdecor request server-side decoration */
        void (*vis)(struct libdecor_frame *, bool) =
            next("libdecor_frame_set_visibility");
        if (vis) vis(frame, true);
    }
    if (real) real(frame);
}
