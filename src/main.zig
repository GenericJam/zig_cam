const std = @import("std");

const img = @import("zigimg");

const libuvc = @cImport({
    @cInclude("libuvc/libuvc.h");
});

const libpng = @cImport({
    @cInclude("libpng/png.h");
});

const stdio = @cImport({
    @cInclude("stdio.h");
});

const unistd = @cImport({
    @cInclude("unistd.h");
});

const UvcFrameFormat = enum(c_uint) {
    // unknown = libuvc.UVC_FRAME_FORMAT_UNKNOWN,
    // Any supported format
    any = libuvc.UVC_FRAME_FORMAT_ANY,
    uncompressed = libuvc.UVC_FRAME_FORMAT_UNCOMPRESSED,
    compressed = libuvc.UVC_FRAME_FORMAT_COMPRESSED,
    //   /** YUYV/YUV2/YUV422: YUV encoding with one luminance value per pixel and
    //    * one UV (chrominance) pair for every two pixels.
    //    */
    yuyv = libuvc.UVC_FRAME_FORMAT_YUYV,
    usvy = libuvc.UVC_FRAME_FORMAT_UYVY,
    //   /** 24-bit RGB */
    rgb = libuvc.UVC_FRAME_FORMAT_RGB,
    bgr = libuvc.UVC_FRAME_FORMAT_BGR,
    //   /** Motion-JPEG (or JPEG) encoded images */
    mjpeg = libuvc.UVC_FRAME_FORMAT_MJPEG,
    h264 = libuvc.UVC_FRAME_FORMAT_H264,
    //   /** Greyscale images */
    gray8 = libuvc.UVC_FRAME_FORMAT_GRAY8,
    gray16 = libuvc.UVC_FRAME_FORMAT_GRAY16,
    //   /* Raw colour mosaic images */
    by8 = libuvc.UVC_FRAME_FORMAT_BY8,
    ba81 = libuvc.UVC_FRAME_FORMAT_BA81,
    sgrbg8 = libuvc.UVC_FRAME_FORMAT_SGRBG8,
    sgbrg8 = libuvc.UVC_FRAME_FORMAT_SGBRG8,
    srggb8 = libuvc.UVC_FRAME_FORMAT_SRGGB8,
    sbggr8 = libuvc.UVC_FRAME_FORMAT_SBGGR8,
    //   /** YUV420: NV12 */
    nv12 = libuvc.UVC_FRAME_FORMAT_NV12,
    //   /** YUV: P010 */
    p010 = libuvc.UVC_FRAME_FORMAT_P010,
    //   /** Number of formats understood */
    count = libuvc.UVC_FRAME_FORMAT_COUNT,
};

// This callback function runs once per frame. Use it to perform any
// quick processing you need, or have it put the frame into your application's
// input queue. If this function takes too long, you'll start losing frames.
fn cb(frame: [*c]libuvc.uvc_frame_t, opaque_canvas: ?*anyopaque) callconv(.C) void {
    const canvas_ptr: *img.Image = @ptrCast(@alignCast(opaque_canvas));

    // UVC_FRAME_FORMAT_MJPEG is the frame format

    std.debug.print("Frame sequence {?}\n", .{frame.*.sequence});

    // We'll convert the image from YUV/JPEG to RGB, so allocate space
    const rgb = libuvc.uvc_allocate_frame(frame.*.width * frame.*.height * 3);

    defer libuvc.uvc_free_frame(rgb);

    if (rgb == null) {
        std.debug.print("unable to allocate rgb frame!\n", .{});
        return;
    }

    // Do the RGB conversion
    const ret = libuvc.uvc_any2rgb(frame, rgb);
    if (ret < 0) {
        libuvc.uvc_perror(ret, "uvc_any2rgb");
        std.debug.print("uvc_any2rgb {?}", .{ret});
        return;
    }

    _ = switch (frame.*.frame_format) {
        // We only care about this one
        libuvc.UVC_COLOR_FORMAT_MJPEG => null,

        else => {
            std.debug.print("Wrong frame format {any}", .{frame.*.frame_format});
            return;
        },
    };

    const buffer_ptr: [*]img.color.Rgb24 = @ptrCast(@alignCast(rgb.*.data));
    const buffer_slice: []img.color.Rgb24 = buffer_ptr[0 .. frame.*.width * frame.*.height * 3];

    canvas_ptr.*.pixels = .{ .rgb24 = buffer_slice };

    // // Maybe stop ignoring this potential error in the future
    // // Uncomment to save a frame to disk - this is slow
    // _ = img.Image.writeToFilePath(canvas_ptr.*, "test.png", .{
    //     .png = .{
    //         // These are defaults which can be substituted
    //         // .interlaced = false,
    //         // .filter_choice = .heuristic,
    //     },
    // }) catch img.Image.WriteError;
}

pub fn main() !void {

    // All of these get dropped into libuvc functions
    var ctx: ?*libuvc.uvc_context_t = undefined;
    var dev: ?*libuvc.uvc_device_t = undefined;
    var ctrl: libuvc.uvc_stream_ctrl_t = undefined;
    var devh: ?*libuvc.uvc_device_handle_t = undefined;

    const res0 = libuvc.uvc_init(&ctx, null);

    // Demo of printing context info
    std.log.info("{s}-{?}: yo", .{ @src().fn_name, @src().line });

    if (res0 < 0) {
        libuvc.uvc_perror(res0, "uvc_init");
        std.debug.print("uvc_init failed\n", .{});
        return;
    }

    std.debug.print("UVC initialized\n", .{});

    // If you're failing here it might be a permissions issue
    const res1 = libuvc.uvc_find_device(ctx, &dev, 0, 0, null);

    // Close the UVC context. This closes and cleans up any existing device handles,
    // and it closes the libusb context if one was not provided.
    defer libuvc.uvc_exit(ctx);

    if (res1 < 0) {
        // No devices found
        libuvc.uvc_perror(res1, "uvc_find_device");
        std.debug.print("No device found\n", .{});
        return;
    }

    // Try to open the device: requires exclusive access
    const res2 = libuvc.uvc_open(dev, &devh);

    if (res2 < 0) {
        //  unable to open device
        libuvc.uvc_perror(res2, "uvc_open");
        std.debug.print("Unable to open device\n", .{});
        return;
    }

    // Release the device descriptor
    defer libuvc.uvc_unref_device(dev);
    // Release our handle on the device
    defer libuvc.uvc_close(devh);

    std.debug.print("Device found\n", .{});

    // Print out a message containing all the information that libuvc
    // knows about the device
    libuvc.uvc_print_diag(devh, null);

    const format_desc = libuvc.uvc_get_format_descs(devh);
    const frame_desc = format_desc.*.frame_descs;

    var c_width: c_int = 640;
    var c_height: c_int = 480;
    var fps: c_int = 30;

    const frame_format: c_uint = switch (format_desc.*.bDescriptorSubtype) {
        libuvc.UVC_VS_FORMAT_MJPEG => libuvc.UVC_COLOR_FORMAT_MJPEG,
        libuvc.UVC_VS_FORMAT_FRAME_BASED => libuvc.UVC_FRAME_FORMAT_H264,
        else => libuvc.UVC_FRAME_FORMAT_YUYV,
    };

    if (frame_desc != null) {
        c_width = frame_desc.*.wWidth;
        c_height = frame_desc.*.wHeight;
        fps = @intCast(10000000 / frame_desc.*.dwDefaultFrameInterval);
    }

    std.debug.print("\nFirst format: {?} {?} {?} {?}\n", .{ format_desc.*, c_width, c_height, fps });

    // Try to negotiate first stream profile
    const res3 = libuvc.uvc_get_stream_ctrl_format_size(devh,
    // result stored in ctrl
    &ctrl, frame_format, c_width, c_height, fps);

    // Print out the result
    libuvc.uvc_print_stream_ctrl(&ctrl, null);

    if (res3 < 0) {
        //  device doesn't provide a matching stream
        libuvc.uvc_perror(res3, "get_mode");
        std.debug.print("device doesn't provide a matching stream\n", .{});
        return;
    }

    // initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // free the memory on exit
    defer arena.deinit();

    // initialize the allocator
    const allocator = arena.allocator();

    const width: u64 = @intCast(c_width);
    const height: u64 = @intCast(c_height);

    var canvas = try img.Image.create(allocator, width, height, .rgb24);

    // const user_ptr: *anyopaque = undefined;
    const opaque_canvas: *anyopaque = @constCast(&canvas);

    // This user_fn here can be any kind of pointer which you could use however you want
    const res4 = libuvc.uvc_start_streaming(devh, &ctrl, cb, opaque_canvas, 0);

    if (res4 < 0) {
        libuvc.uvc_perror(res4, "start_streaming");
        std.debug.print("unable to start stream\n", .{});

        return;
    }
    std.debug.print("Streaming...\n", .{});

    // enable auto exposure - see uvc_set_ae_mode documentation
    std.debug.print("Setting aperture and exposure mode.\n", .{});
    const UVC_AUTO_EXPOSURE_MODE_AUTO: u8 = 8;
    const res5 = libuvc.uvc_set_ae_mode(devh, UVC_AUTO_EXPOSURE_MODE_AUTO);

    if (res5 == libuvc.UVC_SUCCESS) {
        std.debug.print("enabled aperture priority auto exposure mode\n", .{});
    } else {
        libuvc.uvc_perror(res5, " ... uvc_set_ae_mode failed to enable auto exposure mode");
    }

    // stream for 10 seconds */
    // _ = unistd.sleep(10);
    std.time.sleep(std.time.ns_per_s * 1);

    // End the stream. Blocks until last callback is serviced */
    libuvc.uvc_stop_streaming(devh);

    // Save whatever the last image is to show us it worked
    // Maybe stop ignoring this potential error in the future
    _ = img.Image.writeToFilePath(canvas, "test.png", .{
        .png = .{
            // These are defaults which can be substituted
            // .interlaced = false,
            // .filter_choice = .heuristic,
        },
    }) catch img.Image.WriteError;

    std.debug.print("Done streaming.\n", .{});
}
