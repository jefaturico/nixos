#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-layer-shell-unstable-v1-client-protocol.h"

struct mask;

struct state {
	struct wl_display *display;
	struct wl_compositor *compositor;
	struct wl_shm *shm;
	struct zwlr_layer_shell_v1 *layer_shell;
	struct mask *masks;
	const char *output_name;
	int radius;
};

struct mask {
	struct state *state;
	struct wl_output *output;
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer_surface;
	char *name;
	uint32_t global_name;
	int scale;
	int right;
	int configured;
	struct mask *peer;
	struct mask *next;
};

static int
create_shm_file(size_t size)
{
	int fd = memfd_create("display-corner-mask", MFD_CLOEXEC | MFD_ALLOW_SEALING);
	if (fd < 0) {
		perror("memfd_create");
		return -1;
	}
	if (ftruncate(fd, (off_t)size) < 0) {
		perror("ftruncate");
		close(fd);
		return -1;
	}
	return fd;
}

static void
draw_mask(struct mask *mask, uint32_t width, uint32_t height)
{
	const int scale = mask->scale > 0 ? mask->scale : 1;
	const int pixel_width = (int)width * scale;
	const int pixel_height = (int)height * scale;
	const int stride = pixel_width * 4;
	const size_t size = (size_t)stride * pixel_height;
	const int radius = mask->state->radius * scale;
	int fd = create_shm_file(size);
	if (fd < 0)
		exit(EXIT_FAILURE);

	uint32_t *pixels = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (pixels == MAP_FAILED) {
		perror("mmap");
		close(fd);
		exit(EXIT_FAILURE);
	}

	for (int y = 0; y < pixel_height; y++) {
		for (int x = 0; x < pixel_width; x++) {
			/* Four-by-four coverage gives the static edge inexpensive
			 * antialiasing without a rendering library or frame loop. */
			int covered = 0;
			for (int sy = 0; sy < 4; sy++) {
				for (int sx = 0; sx < 4; sx++) {
					double sample_x = x + (sx + 0.5) / 4.0;
					double sample_y = y + (sy + 0.5) / 4.0;
					double dx = mask->right ? sample_x : radius - sample_x;
					double distance_squared = dx * dx + sample_y * sample_y;
					if (distance_squared > (double)radius * radius)
						covered++;
				}
			}
			uint32_t alpha = (uint32_t)((covered * 255 + 8) / 16);
			pixels[y * pixel_width + x] = alpha << 24;
		}
	}

	struct wl_shm_pool *pool = wl_shm_create_pool(mask->state->shm, fd, (int)size);
	struct wl_buffer *buffer = wl_shm_pool_create_buffer(
		pool, 0, pixel_width, pixel_height, stride, WL_SHM_FORMAT_ARGB8888);
	wl_shm_pool_destroy(pool);
	munmap(pixels, size);
	close(fd);

	wl_surface_set_buffer_scale(mask->surface, scale);
	wl_surface_attach(mask->surface, buffer, 0, 0);
	wl_surface_damage_buffer(mask->surface, 0, 0, pixel_width, pixel_height);
	wl_surface_commit(mask->surface);
	wl_buffer_destroy(buffer);
}

static void
layer_surface_configure(void *data, struct zwlr_layer_surface_v1 *layer_surface,
		uint32_t serial, uint32_t width, uint32_t height)
{
	struct mask *mask = data;
	zwlr_layer_surface_v1_ack_configure(layer_surface, serial);
	if (width == 0 || height == 0)
		return;
	mask->configured = 1;
	draw_mask(mask, width, height);
}

static void
layer_surface_closed(void *data, struct zwlr_layer_surface_v1 *layer_surface)
{
	(void)data;
	(void)layer_surface;
	exit(EXIT_FAILURE);
}

static const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
	.configure = layer_surface_configure,
	.closed = layer_surface_closed,
};

static void
create_surface(struct mask *mask, int right)
{
	mask->right = right;
	mask->surface = wl_compositor_create_surface(mask->state->compositor);
	mask->layer_surface = zwlr_layer_shell_v1_get_layer_surface(
		mask->state->layer_shell, mask->surface, mask->output,
		ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "display-corner-mask");
	zwlr_layer_surface_v1_set_size(
		mask->layer_surface, (uint32_t)mask->state->radius, (uint32_t)mask->state->radius);
	zwlr_layer_surface_v1_set_anchor(mask->layer_surface,
		ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
		(right ? ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT : ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT));
	zwlr_layer_surface_v1_set_exclusive_zone(mask->layer_surface, 0);
	zwlr_layer_surface_v1_set_keyboard_interactivity(
		mask->layer_surface, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);
	zwlr_layer_surface_v1_add_listener(mask->layer_surface, &layer_surface_listener, mask);

	/* An empty input region makes the opaque pixels pointer-transparent. */
	struct wl_region *region = wl_compositor_create_region(mask->state->compositor);
	wl_surface_set_input_region(mask->surface, region);
	wl_region_destroy(region);
	wl_surface_commit(mask->surface);
}

static void
output_geometry(void *data, struct wl_output *output, int32_t x, int32_t y,
		int32_t physical_width, int32_t physical_height, int32_t subpixel,
		const char *make, const char *model, int32_t transform)
{
	(void)data; (void)output; (void)x; (void)y; (void)physical_width;
	(void)physical_height; (void)subpixel; (void)make; (void)model; (void)transform;
}

static void
output_mode(void *data, struct wl_output *output, uint32_t flags,
		int32_t width, int32_t height, int32_t refresh)
{
	(void)data; (void)output; (void)flags; (void)width; (void)height; (void)refresh;
}

static void
output_done(void *data, struct wl_output *output)
{
	(void)data; (void)output;
}

static void
output_scale(void *data, struct wl_output *output, int32_t factor)
{
	struct mask *mask = data;
	(void)output;
	if (factor < 1 || factor == mask->scale)
		return;
	mask->scale = factor;
	if (mask->configured)
		draw_mask(mask, (uint32_t)mask->state->radius, (uint32_t)mask->state->radius);
	if (mask->peer) {
		mask->peer->scale = factor;
		if (mask->peer->configured)
			draw_mask(mask->peer, (uint32_t)mask->state->radius,
				(uint32_t)mask->state->radius);
	}
}

static void
output_name(void *data, struct wl_output *output, const char *name)
{
	struct mask *mask = data;
	(void)output;
	free(mask->name);
	mask->name = strdup(name);
	if (!mask->name) {
		perror("strdup");
		exit(EXIT_FAILURE);
	}
}

static void
output_description(void *data, struct wl_output *output, const char *description)
{
	(void)data; (void)output; (void)description;
}

static const struct wl_output_listener output_listener = {
	.geometry = output_geometry,
	.mode = output_mode,
	.done = output_done,
	.scale = output_scale,
	.name = output_name,
	.description = output_description,
};

static void
registry_global(void *data, struct wl_registry *registry, uint32_t name,
		const char *interface, uint32_t version)
{
	struct state *state = data;
	if (strcmp(interface, wl_compositor_interface.name) == 0) {
		state->compositor = wl_registry_bind(registry, name, &wl_compositor_interface,
			version < 4 ? version : 4);
	} else if (strcmp(interface, wl_shm_interface.name) == 0) {
		state->shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
	} else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
		state->layer_shell = wl_registry_bind(registry, name,
			&zwlr_layer_shell_v1_interface, version < 4 ? version : 4);
	} else if (strcmp(interface, wl_output_interface.name) == 0) {
		if (version < 4) {
			fprintf(stderr, "display-corner-mask: wl_output version 4 is required\n");
			return;
		}
		struct mask *mask = calloc(1, sizeof(*mask));
		if (!mask) {
			perror("calloc");
			exit(EXIT_FAILURE);
		}
		mask->state = state;
		mask->global_name = name;
		mask->scale = 1;
		mask->output = wl_registry_bind(registry, name, &wl_output_interface, 4);
		mask->next = state->masks;
		state->masks = mask;
		wl_output_add_listener(mask->output, &output_listener, mask);
	}
}

static void
registry_global_remove(void *data, struct wl_registry *registry, uint32_t name)
{
	struct state *state = data;
	(void)registry;
	for (struct mask *mask = state->masks; mask; mask = mask->next) {
		if (mask->global_name == name && mask->surface)
			exit(EXIT_SUCCESS);
	}
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_global,
	.global_remove = registry_global_remove,
};

int
main(int argc, char **argv)
{
	if (argc != 3) {
		fprintf(stderr, "usage: %s OUTPUT RADIUS\n", argv[0]);
		return EXIT_FAILURE;
	}
	char *end = NULL;
	long radius = strtol(argv[2], &end, 10);
	if (!end || *end != '\0' || radius < 1 || radius > 256) {
		fprintf(stderr, "display-corner-mask: radius must be between 1 and 256\n");
		return EXIT_FAILURE;
	}

	struct state state = {
		.output_name = argv[1],
		.radius = (int)radius,
	};
	state.display = wl_display_connect(NULL);
	if (!state.display) {
		fprintf(stderr, "display-corner-mask: unable to connect to Wayland display\n");
		return EXIT_FAILURE;
	}

	struct wl_registry *registry = wl_display_get_registry(state.display);
	wl_registry_add_listener(registry, &registry_listener, &state);
	if (wl_display_roundtrip(state.display) < 0 ||
		!state.compositor || !state.shm || !state.layer_shell) {
		fprintf(stderr, "display-corner-mask: required Wayland interfaces unavailable\n");
		return EXIT_FAILURE;
	}
	/* Output listeners are installed while dispatching the registry globals
	 * above, so their initial name and scale events arrive on a second trip. */
	if (wl_display_roundtrip(state.display) < 0)
		return EXIT_FAILURE;

	struct mask *target = NULL;
	for (struct mask *mask = state.masks; mask; mask = mask->next) {
		if (mask->name && strcmp(mask->name, state.output_name) == 0) {
			target = mask;
			break;
		}
	}
	if (!target) {
		fprintf(stderr, "display-corner-mask: output %s not found\n", state.output_name);
		return EXIT_FAILURE;
	}

	create_surface(target, 0);
	struct mask *right = calloc(1, sizeof(*right));
	if (!right) {
		perror("calloc");
		return EXIT_FAILURE;
	}
	right->state = &state;
	right->output = target->output;
	right->scale = target->scale;
	right->global_name = target->global_name;
	right->name = strdup(target->name);
	right->next = target->next;
	target->next = right;
	target->peer = right;
	right->peer = target;
	create_surface(right, 1);

	if (wl_display_roundtrip(state.display) < 0)
		return EXIT_FAILURE;

	while (wl_display_dispatch(state.display) >= 0) {}
	return errno == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
