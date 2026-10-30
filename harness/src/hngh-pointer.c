/*
 * hngh-pointer — hngh-owned user-space uinput pointer writer.
 *
 * design: ~/Projects/omp-work/PLANS/2026-10-28-cu-stack-design.md
 *         §3 (option c' — the MVP pointer transport) and §5 (pointer.* rows).
 *
 * One op per process: the virtual device is created, the planned events are
 * written, the device is destroyed — no daemon, no root, no package. The
 * /dev/uinput ACL (steam uaccess rule) is the whole prerequisite.
 *
 * --dry-run prints the exact event plan and NEVER opens a device.
 *
 * Exit codes: 0 emitted · 1 runtime error · 3 usage.
 */

#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define MAX_EVENTS 64
#define DEFAULT_DEVICE "/dev/uinput"
/* Fallback absolute range when the caller does not pass --range. */
#define DEFAULT_MIN_X 0
#define DEFAULT_MIN_Y 0
#define DEFAULT_MAX_X 1919
#define DEFAULT_MAX_Y 1079
/* The compositor's libinput must attach to a freshly created uinput device
 * before events are written, else the first events land nowhere. */
#define ATTACH_SETTLE_US 150000
/* Let the written events drain before the device goes away. */
#define DRAIN_SETTLE_US 100000

struct plan {
	struct input_event ev[MAX_EVENTS];
	int n;
	int uses_abs;
	int uses_rel;
	int uses_buttons;
};

struct range {
	int min_x, min_y, max_x, max_y;
};

static const char *device_path = DEFAULT_DEVICE;
static int dry_run = 0;

static void usage(FILE *out) {
	fprintf(out,
"hngh-pointer — hngh user-space uinput pointer writer\n"
"\n"
"Usage:\n"
"  hngh-pointer [--device PATH] [--range X0,Y0,X1,Y1] [--dry-run] move --abs X,Y\n"
"  hngh-pointer [--device PATH] [--range X0,Y0,X1,Y1] [--dry-run] move --rel DX,DY\n"
"  hngh-pointer [--device PATH] [--dry-run] click [--button left|right|middle]\n"
"                                              [--count N]\n"
"  hngh-pointer [--device PATH] [--dry-run] scroll --delta N\n"
"\n"
"  --device PATH   uinput node (default %s)\n"
"  --range X0,Y0,X1,Y1\n"
"                  absolute range of the virtual pointer, in global desktop\n"
"                  coordinates (default %d,%d,%d,%d); hngh-act passes the\n"
"                  union bounding box of the monitors\n"
"  --dry-run       print the event plan; never open the device\n"
"  --abs X,Y       absolute move (exact, immune to pointer acceleration)\n"
"  --rel DX,DY     relative move\n"
"  --button        mouse button for click (default left)\n"
"  --count N       click cycles to emit (2 = double click)\n"
"  --delta N       wheel notches (positive = up)\n",
		DEFAULT_DEVICE, DEFAULT_MIN_X, DEFAULT_MIN_Y, DEFAULT_MAX_X,
		DEFAULT_MAX_Y);
}

static void usage_exit(const char *msg) {
	fprintf(stderr, "hngh-pointer: %s\n", msg);
	usage(stderr);
	exit(3);
}

static void die(const char *msg) {
	fprintf(stderr, "hngh-pointer: %s\n", msg);
	exit(1);
}

static void die_errno(const char *msg) {
	fprintf(stderr, "hngh-pointer: %s: %s\n", msg, strerror(errno));
	exit(1);
}

/* Wait until the kernel registers the device in sysfs. Events written
 * before a reader (libinput) opens the event node are dropped by the
 * kernel, so the wait is what makes the first event land. Bounded,
 * best effort. */
static void wait_registered(const char *name) {
	const char *base = "/sys/class/input";
	struct dirent *e;
	DIR *d;
	FILE *f;
	char path[512], buf[256];
	int waited = 0;
	size_t len = strlen(name);

	d = opendir(base);
	if (!d)
		return;
	while (waited < 1000) {
		rewinddir(d);
		while ((e = readdir(d))) {
			if (strncmp(e->d_name, "event", 5))
				continue;
			snprintf(path, sizeof(path), "%s/%s/device/name", base, e->d_name);
			f = fopen(path, "r");
			if (!f)
				continue;
			if (fgets(buf, sizeof(buf), f) &&
			    !strncmp(buf, name, len) && buf[len] == '\n') {
				fclose(f);
				closedir(d);
				return;
			}
			fclose(f);
		}
		usleep(5000);
		waited += 5;
	}
	closedir(d);
}

static void plan_add(struct plan *p, unsigned short type, unsigned short code, int value) {
	struct input_event *e;

	if (p->n >= MAX_EVENTS)
		die("event plan overflow");
	e = &p->ev[p->n++];
	memset(e, 0, sizeof(*e));
	e->type = type;
	e->code = code;
	e->value = value;
	if (type == EV_ABS)
		p->uses_abs = 1;
	else if (type == EV_REL)
		p->uses_rel = 1;
	else if (type == EV_KEY)
		p->uses_buttons = 1;
}

static const char *type_name(unsigned short type) {
	switch (type) {
	case EV_SYN: return "EV_SYN";
	case EV_KEY: return "EV_KEY";
	case EV_REL: return "EV_REL";
	case EV_ABS: return "EV_ABS";
	default: return "EV_?";
	}
}

/* Event codes repeat across types (REL_X==ABS_X==0), so the type decides
 * which name applies. */
static const char *code_name(unsigned short type, unsigned short code) {
	switch (type) {
	case EV_SYN:
		return code == SYN_REPORT ? "SYN_REPORT" : "SYN_?";
	case EV_KEY:
		switch (code) {
		case BTN_LEFT: return "BTN_LEFT";
		case BTN_RIGHT: return "BTN_RIGHT";
		case BTN_MIDDLE: return "BTN_MIDDLE";
		default: return "KEY_?";
		}
	case EV_REL:
		switch (code) {
		case REL_X: return "REL_X";
		case REL_Y: return "REL_Y";
		case REL_WHEEL: return "REL_WHEEL";
		default: return "REL_?";
		}
	case EV_ABS:
		switch (code) {
		case ABS_X: return "ABS_X";
		case ABS_Y: return "ABS_Y";
		default: return "ABS_?";
		}
	default:
		return "CODE_?";
	}
}

static int parse_int(const char *s, int *out) {
	char *end = NULL;
	long v;

	if (!s || !*s)
		return -1;
	errno = 0;
	v = strtol(s, &end, 10);
	if (errno || !end || *end != '\0')
		return -1;
	*out = (int)v;
	return 0;
}

/* "X,Y" -> two ints */
static int parse_pair(const char *s, int *a, int *b) {
	char buf[64];
	const char *comma = s ? strchr(s, ',') : NULL;
	size_t len;

	if (!comma)
		return -1;
	len = (size_t)(comma - s);
	if (len == 0 || len >= sizeof(buf))
		return -1;
	memcpy(buf, s, len);
	buf[len] = '\0';
	if (parse_int(buf, a) || parse_int(comma + 1, b))
		return -1;
	return 0;
}

/* "X0,Y0,X1,Y1" -> absolute range */
static int parse_range(const char *s, struct range *r) {
	char buf[128];
	char *p, *q;

	if (!s || strlen(s) >= sizeof(buf))
		return -1;
	strcpy(buf, s);
	p = strtok(buf, ",");
	q = strtok(NULL, ",");
	if (!p || !q)
		return -1;
	if (parse_int(p, &r->min_x))
		return -1;
	if (parse_int(q, &r->min_y))
		return -1;
	p = strtok(NULL, ",");
	q = strtok(NULL, ",");
	if (!p || !q)
		return -1;
	if (parse_int(p, &r->max_x) || parse_int(q, &r->max_y))
		return -1;
	if (r->max_x <= r->min_x || r->max_y <= r->min_y)
		return -1;
	return 0;
}

static unsigned short button_code(const char *name) {
	if (!name || !strcmp(name, "left"))
		return BTN_LEFT;
	if (!strcmp(name, "right"))
		return BTN_RIGHT;
	if (!strcmp(name, "middle"))
		return BTN_MIDDLE;
	return 0;
}

/* Absolute move + SYN. */
static void plan_abs(struct plan *p, int x, int y) {
	plan_add(p, EV_ABS, ABS_X, x);
	plan_add(p, EV_ABS, ABS_Y, y);
	plan_add(p, EV_SYN, SYN_REPORT, 0);
}

/* Relative move + SYN. */
static void plan_rel(struct plan *p, int dx, int dy) {
	plan_add(p, EV_REL, REL_X, dx);
	plan_add(p, EV_REL, REL_Y, dy);
	plan_add(p, EV_SYN, SYN_REPORT, 0);
}

/* One press/release cycle, SYN after each state change. */
static void plan_press(struct plan *p, unsigned short btn) {
	plan_add(p, EV_KEY, btn, 1);
	plan_add(p, EV_SYN, SYN_REPORT, 0);
	plan_add(p, EV_KEY, btn, 0);
	plan_add(p, EV_SYN, SYN_REPORT, 0);
}

static void print_plan(const struct plan *p) {
	int i;

	printf("plan: device=%s (not opened) events=%d abs=%d rel=%d buttons=%d\n",
	       device_path, p->n, p->uses_abs, p->uses_rel, p->uses_buttons);
	for (i = 0; i < p->n; i++)
		printf("plan: %s %s=%d\n", type_name(p->ev[i].type),
		       code_name(p->ev[i].type, p->ev[i].code), p->ev[i].value);
}

static int write_events(int fd, const struct input_event *ev, int n) {
	size_t off = 0, total = (size_t)n * sizeof(struct input_event);

	while (off < total) {
		ssize_t w = write(fd, (const char *)ev + off, total - off);

		if (w < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		off += (size_t)w;
	}
	return 0;
}

/* The absolute axes as a standalone event group: used to prime the device
 * state right after creation. */
static int abs_prime(const struct plan *p, struct input_event *out) {
	int i, n = 0;

	for (i = 0; i < p->n; i++)
		if (p->ev[i].type == EV_ABS)
			out[n++] = p->ev[i];
	if (n == 0)
		return 0;
	memset(&out[n], 0, sizeof(out[n]));
	out[n].type = EV_SYN;
	out[n].code = SYN_REPORT;
	return n + 1;
}

/* Create the virtual device, write the plan, destroy it. The device is open
 * for the whole life of the process. */
static void emit(const struct plan *p, const struct range *r) {
	struct uinput_setup setup;
	struct uinput_abs_setup abs_x, abs_y;
	struct input_event prime[MAX_EVENTS];
	int fd;
	int n_prime;

	fd = open(device_path, O_WRONLY | O_NONBLOCK);
	if (fd < 0)
		die_errno("cannot open uinput device");

	if (ioctl(fd, UI_SET_EVBIT, EV_SYN) < 0 ||
	    ioctl(fd, UI_SET_EVBIT, EV_KEY) < 0)
		die_errno("cannot declare event types");

	/* Button bits are declared even for a move-only plan: libinput only
	 * classifies a REL device as a mouse when it also reports a button,
	 * and a device it does not classify is ignored entirely. */
	if (ioctl(fd, UI_SET_KEYBIT, BTN_LEFT) < 0 ||
	    ioctl(fd, UI_SET_KEYBIT, BTN_RIGHT) < 0 ||
	    ioctl(fd, UI_SET_KEYBIT, BTN_MIDDLE) < 0)
		die_errno("cannot declare button bits");

	/* One device profile: REL axes always (so libinput classifies the
	 * device as a mouse — a device with only absolute axes is tagged as a
	 * joystick and ignored for pointer motion), plus the absolute axes
	 * when the plan needs them, plus the button bits when it needs them.
	 * A mixed REL+ABS device keeps the mouse classification, so the
	 * ABS event is the extra precision and the REL event is the fallback.
	 * INPUT_PROP_POINTER below keeps it out of the touch class. */
	if (ioctl(fd, UI_SET_EVBIT, EV_REL) < 0)
		die_errno("cannot declare EV_REL");
	if (ioctl(fd, UI_SET_RELBIT, REL_X) < 0 ||
	    ioctl(fd, UI_SET_RELBIT, REL_Y) < 0 ||
	    ioctl(fd, UI_SET_RELBIT, REL_WHEEL) < 0)
		die_errno("cannot declare relative axes");

	if (p->uses_abs) {
		if (ioctl(fd, UI_SET_EVBIT, EV_ABS) < 0)
			die_errno("cannot declare EV_ABS");
		if (ioctl(fd, UI_SET_ABSBIT, ABS_X) < 0 ||
		    ioctl(fd, UI_SET_ABSBIT, ABS_Y) < 0)
			die_errno("cannot declare absolute axes");

		memset(&abs_x, 0, sizeof(abs_x));
		abs_x.code = ABS_X;
		abs_x.absinfo.minimum = r->min_x;
		abs_x.absinfo.maximum = r->max_x;
		if (ioctl(fd, UI_ABS_SETUP, &abs_x) < 0)
			die_errno("cannot set up ABS_X");

		memset(&abs_y, 0, sizeof(abs_y));
		abs_y.code = ABS_Y;
		abs_y.absinfo.minimum = r->min_y;
		abs_y.absinfo.maximum = r->max_y;
		if (ioctl(fd, UI_ABS_SETUP, &abs_y) < 0)
			die_errno("cannot set up ABS_Y");
	}
	/* Mark it as a pointer, not a touch device. */
	if (ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_POINTER) < 0)
		die_errno("cannot set pointer property");

	memset(&setup, 0, sizeof(setup));
	setup.id.bustype = BUS_VIRTUAL;
	setup.id.vendor = 0x484e; /* "HN" */
	setup.id.product = 0x5031; /* "P1" */
	setup.id.version = 1;
	snprintf(setup.name, sizeof(setup.name), "hngh-pointer");
	if (ioctl(fd, UI_DEV_SETUP, &setup) < 0)
		die_errno("cannot set up device");

	if (ioctl(fd, UI_DEV_CREATE) < 0)
		die_errno("cannot create device");

	/* Prime the absolute state BEFORE the compositor attaches: the input
	 * core keeps the axis values, so a compositor that reads them on
	 * attach sees the target position instead of the device origin. */
	n_prime = abs_prime(p, prime);
	if (n_prime && write_events(fd, prime, n_prime) < 0)
		die_errno("cannot prime the absolute position");

	wait_registered("hngh-pointer");
	usleep(ATTACH_SETTLE_US); /* let libinput attach before events land */

	if (write_events(fd, p->ev, p->n) < 0)
		die_errno("cannot write events");

	usleep(DRAIN_SETTLE_US);
	ioctl(fd, UI_DEV_DESTROY);
	close(fd);
}

int main(int argc, char **argv) {
	struct plan p;
	struct range r = { DEFAULT_MIN_X, DEFAULT_MIN_Y, DEFAULT_MAX_X, DEFAULT_MAX_Y };
	const char *op = NULL;
	const char *v_abs = NULL, *v_rel = NULL, *v_button = NULL;
	const char *v_count = NULL, *v_delta = NULL, *v_range = NULL;
	int i, op_index = -1;

	memset(&p, 0, sizeof(p));

	/* Pass 1: find the op (skipping flag values, so a path named
	 * "move" is not mistaken for the op). */
	for (i = 1; i < argc; i++) {
		const char *a = argv[i];

		if (!strcmp(a, "--device") || !strcmp(a, "--range") ||
		    !strcmp(a, "--abs") || !strcmp(a, "--rel") ||
		    !strcmp(a, "--button") || !strcmp(a, "--count") ||
		    !strcmp(a, "--delta")) {
			i++;
			continue;
		}
		if (!strcmp(a, "move") || !strcmp(a, "click") ||
		    !strcmp(a, "scroll")) {
			op = a;
			op_index = i;
			break;
		}
	}
	if (!op)
		usage_exit("no op given (move|click|scroll)");

	/* Pass 2: flags. */
	for (i = 1; i < argc; i++) {
		const char *a = argv[i];

		if (i == op_index)
			continue;
		if (!strcmp(a, "--dry-run")) {
			dry_run = 1;
			continue;
		}
		if (!strcmp(a, "-h") || !strcmp(a, "--help")) {
			usage(stdout);
			return 0;
		}
		if (!strcmp(a, "--device")) {
			if (++i >= argc)
				usage_exit("--device needs a path");
			device_path = argv[i];
			continue;
		}
		if (!strcmp(a, "--range")) {
			if (++i >= argc)
				usage_exit("--range needs X0,Y0,X1,Y1");
			v_range = argv[i];
			continue;
		}
		if (!strcmp(a, "--abs")) {
			if (++i >= argc)
				usage_exit("--abs needs X,Y");
			v_abs = argv[i];
			continue;
		}
		if (!strcmp(a, "--rel")) {
			if (++i >= argc)
				usage_exit("--rel needs DX,DY");
			v_rel = argv[i];
			continue;
		}
		if (!strcmp(a, "--button")) {
			if (++i >= argc)
				usage_exit("--button needs left|right|middle");
			v_button = argv[i];
			continue;
		}
		if (!strcmp(a, "--count")) {
			if (++i >= argc)
				usage_exit("--count needs N");
			v_count = argv[i];
			continue;
		}
		if (!strcmp(a, "--delta")) {
			if (++i >= argc)
				usage_exit("--delta needs N");
			v_delta = argv[i];
			continue;
		}
		usage_exit("unknown argument");
	}

	if (v_range && parse_range(v_range, &r))
		usage_exit("--range wants X0,Y0,X1,Y1 (e.g. 0,0,1919,1079)");

	if (!strcmp(op, "move")) {
		int x, y;

		if (v_abs && v_rel)
			usage_exit("move takes --abs or --rel, not both");
		if (v_abs) {
			if (parse_pair(v_abs, &x, &y))
				usage_exit("--abs wants X,Y");
			plan_abs(&p, x, y);
		} else if (v_rel) {
			if (parse_pair(v_rel, &x, &y))
				usage_exit("--rel wants DX,DY");
			plan_rel(&p, x, y);
		} else {
			usage_exit("move needs --abs X,Y or --rel DX,DY");
		}
	} else if (!strcmp(op, "click")) {
		unsigned short btn = button_code(v_button);
		int count = 1, c;

		if (!btn)
			usage_exit("--button wants left|right|middle");
		if (v_count) {
			if (parse_int(v_count, &count) || count < 1 || count > 5)
				usage_exit("--count wants 1..5");
		}
		for (c = 0; c < count; c++)
			plan_press(&p, btn);
	} else { /* scroll */
		int delta;

		if (!v_delta)
			usage_exit("scroll needs --delta N");
		if (parse_int(v_delta, &delta))
			usage_exit("--delta wants N");
		plan_add(&p, EV_REL, REL_WHEEL, delta);
		plan_add(&p, EV_SYN, SYN_REPORT, 0);
	}

	if (dry_run) {
		print_plan(&p);
		return 0;
	}

	emit(&p, &r);
	return 0;
}
