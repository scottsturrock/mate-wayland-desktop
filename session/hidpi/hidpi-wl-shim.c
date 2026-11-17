/* hidpi-wl-shim -- preloaded into a program that "hidpi-run --native" starts
 * as a Wayland client. Part of MATE Wayland Desktop.
 *
 * Some programs can speak Wayland but do not: they switch themselves to X11
 * when they start, or their bundled toolkit trips over the compositor. On a
 * scaled screen an X11 window is enlarged as a picture and looks blurry, so
 * hidpi-run --native runs such a program as a real Wayland client instead.
 * This library removes the two obstacles met so far:
 *
 * 1. A program that overrides the session at start-up. It calls
 *    setenv("QT_QPA_PLATFORM", "xcb"), setenv("XDG_SESSION_TYPE", "x11") or
 *    setenv("GDK_BACKEND", "x11") on itself, whatever the launcher set. Those
 *    writes are ignored, so the values hidpi-run chose stay in effect.
 *
 * 2. A toolkit that sends window size limits in an invalid order. When a
 *    fixed-size window changes size, older Qt sends xdg_toplevel.set_min_size
 *    and set_max_size one at a time, so for a moment the minimum is larger
 *    than the maximum. wlroots compositors (labwc) answer that with a fatal
 *    protocol error and the program is disconnected. The missing counterpart
 *    is sent first, so the pair is valid at every step.
 *
 * Everything else passes through unchanged.
 *
 * Build: packaging/build-session-deb.sh compiles it into
 * /usr/lib/mate-wayland-desktop/hidpi-wl-shim.so
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

/* ---- 1. keep the session type the launcher chose ------------------------- */

static int forces_x11(const char *name, const char *value)
{
    if (!name || !value)
        return 0;
    if (!strcmp(name, "QT_QPA_PLATFORM"))
        return !strcmp(value, "xcb");
    if (!strcmp(name, "XDG_SESSION_TYPE") || !strcmp(name, "GDK_BACKEND"))
        return !strcasecmp(value, "x11");
    return 0;
}

int setenv(const char *name, const char *value, int overwrite)
{
    static int (*real)(const char *, const char *, int);
    if (!real)
        real = dlsym(RTLD_NEXT, "setenv");
    if (forces_x11(name, value))
        return 0;
    return real(name, value, overwrite);
}

int putenv(char *string)
{
    static int (*real)(char *);
    const char *eq = strchr(string, '=');
    if (!real)
        real = dlsym(RTLD_NEXT, "putenv");
    if (eq && eq - string < 32) {
        char name[32];
        memcpy(name, string, eq - string);
        name[eq - string] = '\0';
        if (forces_x11(name, eq + 1))
            return 0;
    }
    return real(string);
}

/* ---- 2. keep xdg_toplevel size limits valid ------------------------------ */

struct wl_proxy;
struct wl_array;
struct wl_message {
    const char *name;
    const char *signature;
    const void **types;
};
struct wl_interface {
    const char *name;
    int version;
    int method_count;
    const struct wl_message *methods;
    int event_count;
    const struct wl_message *events;
};
union wl_argument {
    int32_t i;
    uint32_t u;
    int32_t f;
    const char *s;
    void *o;
    uint32_t n;
    struct wl_array *a;
    int32_t h;
};

#define XDG_TOPLEVEL_DESTROY      0
#define XDG_TOPLEVEL_SET_MAX_SIZE 7
#define XDG_TOPLEVEL_SET_MIN_SIZE 8
#define MAX_ARGS   20       /* WL_CLOSURE_MAX_ARGS */
#define MAX_TRACK  64       /* toplevels followed at once; more are left alone */

static struct track {
    struct wl_proxy *proxy;
    int minw, minh, maxw, maxh;
} tracks[MAX_TRACK];

static struct track *track_for(struct wl_proxy *proxy)
{
    int i, spare = -1;
    for (i = 0; i < MAX_TRACK; i++) {
        if (tracks[i].proxy == proxy)
            return &tracks[i];
        if (!tracks[i].proxy && spare < 0)
            spare = i;
    }
    if (spare < 0)
        return NULL;
    tracks[spare] = (struct track){ proxy, 0, 0, 0, 0 };
    return &tracks[spare];
}

/* libwayland-client is usually loaded by a toolkit plugin, after us and out
 * of reach of RTLD_NEXT, so ask for the copy that is already loaded. */
static void *wayland_symbol(const char *name)
{
    void *sym = dlsym(RTLD_NEXT, name);
    void *lib;
    if (sym)
        return sym;
    lib = dlopen("libwayland-client.so.0", RTLD_LAZY | RTLD_NOLOAD);
    if (!lib)
        lib = dlopen("libwayland-client.so.0", RTLD_LAZY);
    return lib ? dlsym(lib, name) : NULL;
}

/* The program is the Wayland client we were loaded for: stop handing the
 * preload on to whatever it starts (a browser, a terminal, a helper). */
static void stop_inheriting(void)
{
    static int done;
    const char *v;
    if (done)
        return;
    done = 1;
    v = getenv("LD_PRELOAD");
    if (v && strstr(v, "hidpi-wl-shim") && !strpbrk(v, ": "))
        unsetenv("LD_PRELOAD");
}

static const struct wl_interface *interface_of(struct wl_proxy *proxy)
{
    /* struct wl_proxy begins with struct wl_object, whose first member is
     * the interface. This layout is libwayland's ABI. */
    return *(const struct wl_interface **)proxy;
}

static int read_args(const char *sig, va_list ap, union wl_argument *args)
{
    int n = 0;
    for (; *sig && n < MAX_ARGS; sig++) {
        switch (*sig) {
        case 'i': args[n++].i = va_arg(ap, int32_t); break;
        case 'u': args[n++].u = va_arg(ap, uint32_t); break;
        case 'f': args[n++].f = va_arg(ap, int32_t); break;
        case 'h': args[n++].h = va_arg(ap, int32_t); break;
        case 's': args[n++].s = va_arg(ap, const char *); break;
        case 'o': args[n++].o = va_arg(ap, void *); break;
        case 'n': args[n++].o = va_arg(ap, void *); break;
        case 'a': args[n++].a = va_arg(ap, struct wl_array *); break;
        default: break;     /* a version number or '?' */
        }
    }
    return n;
}

typedef void (*send_size_fn)(struct wl_proxy *, uint32_t opcode, int w, int h,
                             uint32_t version);

/* Called before a request is passed on. If it is a size limit that would
 * leave minimum > maximum, move the other limit out of the way first. */
static void fix_limits(struct wl_proxy *proxy, const struct wl_interface *iface,
                       uint32_t opcode, const union wl_argument *args,
                       uint32_t version, send_size_fn send)
{
    struct track *t;
    int w, h, nw, nh;

    if (strcmp(iface->name, "xdg_toplevel"))
        return;
    t = track_for(proxy);
    if (!t)
        return;

    if (opcode == XDG_TOPLEVEL_DESTROY) {
        t->proxy = NULL;
    } else if (opcode == XDG_TOPLEVEL_SET_MIN_SIZE) {
        w = args[0].i; h = args[1].i;
        nw = (t->maxw && w > t->maxw) ? w : t->maxw;   /* 0 = no limit */
        nh = (t->maxh && h > t->maxh) ? h : t->maxh;
        if (nw != t->maxw || nh != t->maxh) {
            send(proxy, XDG_TOPLEVEL_SET_MAX_SIZE, nw, nh, version);
            t->maxw = nw; t->maxh = nh;
        }
        t->minw = w; t->minh = h;
    } else if (opcode == XDG_TOPLEVEL_SET_MAX_SIZE) {
        w = args[0].i; h = args[1].i;
        nw = (w && t->minw > w) ? w : t->minw;
        nh = (h && t->minh > h) ? h : t->minh;
        if (nw != t->minw || nh != t->minh) {
            send(proxy, XDG_TOPLEVEL_SET_MIN_SIZE, nw, nh, version);
            t->minw = nw; t->minh = nh;
        }
        t->maxw = w; t->maxh = h;
    }
}

/* Toolkits built against libwayland before 1.20 (older bundled Qt). */
static void (*real_marshal_array)(struct wl_proxy *, uint32_t, union wl_argument *);

static void send_size_old(struct wl_proxy *proxy, uint32_t opcode, int w, int h,
                          uint32_t version)
{
    union wl_argument a[2];
    (void)version;
    a[0].i = w; a[1].i = h;
    real_marshal_array(proxy, opcode, a);
}

void wl_proxy_marshal(struct wl_proxy *proxy, uint32_t opcode, ...)
{
    const struct wl_interface *iface = interface_of(proxy);
    union wl_argument args[MAX_ARGS];
    va_list ap;

    if (!real_marshal_array)
        real_marshal_array = wayland_symbol("wl_proxy_marshal_array");
    stop_inheriting();

    va_start(ap, opcode);
    read_args(iface->methods[opcode].signature, ap, args);
    va_end(ap);

    fix_limits(proxy, iface, opcode, args, 0, send_size_old);
    real_marshal_array(proxy, opcode, args);
}

/* Toolkits built against libwayland 1.20 or later. */
static struct wl_proxy *(*real_marshal_array_flags)(struct wl_proxy *, uint32_t,
        const struct wl_interface *, uint32_t, uint32_t, union wl_argument *);

static void send_size_new(struct wl_proxy *proxy, uint32_t opcode, int w, int h,
                          uint32_t version)
{
    union wl_argument a[2];
    a[0].i = w; a[1].i = h;
    real_marshal_array_flags(proxy, opcode, NULL, version, 0, a);
}

struct wl_proxy *wl_proxy_marshal_flags(struct wl_proxy *proxy, uint32_t opcode,
        const struct wl_interface *interface, uint32_t version, uint32_t flags, ...)
{
    const struct wl_interface *iface = interface_of(proxy);
    union wl_argument args[MAX_ARGS];
    va_list ap;

    if (!real_marshal_array_flags)
        real_marshal_array_flags = wayland_symbol("wl_proxy_marshal_array_flags");
    stop_inheriting();

    va_start(ap, flags);
    read_args(iface->methods[opcode].signature, ap, args);
    va_end(ap);

    fix_limits(proxy, iface, opcode, args, version, send_size_new);
    return real_marshal_array_flags(proxy, opcode, interface, version, flags, args);
}
