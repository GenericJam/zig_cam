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

fn user_fun() void {
    std.debug.print("Woot woot!", .{});
}

// This callback function runs once per frame. Use it to perform any
// quick processing you need, or have it put the frame into your application's
// input queue. If this function takes too long, you'll start losing frames.
fn cb(frame: [*c]libuvc.uvc_frame_t, ptr: ?*anyopaque) callconv(.C) void {

    // UVC_FRAME_FORMAT_MJPEG is the frame format

    std.debug.print("inside callback\n", .{});

    // So the equivalent of this, would be to pass `&frame_format` to the library, and
    // do `const frame_format: *uvc_frame_format = @ptrCast(@alignCast(ptr));`
    // in the callback, although a single enum value could also be passed as
    // `@ptrFromInt(@intFromEnum(frame_format))` and accepted as
    // `const frame_format: uvc_frame_format = @enumFromInt(@intFromPtr(ptr));`.
    const frame_format: *libuvc.uvc_frame_format = @ptrCast(@alignCast(ptr));
    //   /* FILE *fp;
    //    * static int jpeg_count = 0;
    //    * static const char *H264_FILE = "iOSDevLog.h264";
    //    * static const char *MJPEG_FILE = ".jpeg";
    //    * char filename[16]; */

    // We'll convert the image from YUV/JPEG to RGB, so allocate space
    const rgb = libuvc.uvc_allocate_frame(frame.*.width * frame.*.height * 3);

    defer libuvc.uvc_free_frame(rgb);

    if (rgb == null) {
        std.debug.print("unable to allocate rgb frame!\n", .{});
        return;
    }

    // std.debug.print("uvc_frame_format {?}\n", .{@as(libuvc.uvc_frame_format, @enumFromInt(frame_format.*))});

    std.debug.print("callback! frame_format = {?}, width = {?}, height = {?}, length = {?}, frame_format = {?}\n", .{ frame.*.frame_format, frame.*.width, frame.*.height, frame.*.data_bytes, frame_format });

    // /* Do the RGB conversion */
    const ret = libuvc.uvc_any2rgb(frame, rgb);
    if (ret < 0) {
        libuvc.uvc_perror(ret, "uvc_any2rgb");
        std.debug.print("uvc_any2rgb {?}", .{ret});
        return;
    }

    // A simple to save a png with a bit more flexibility. This function
    // returns 0 on success otherwise -1.

    // - filename:   the path where you want to save the png.
    // - width:      width of the image
    // - height:     height of the image
    // - bitdepth:   how many bits per pixel (e.g. 8).
    // - colortype:  PNG_COLOR_TYEP_GRAY
    //               PNG_COLOR_TYPE_PALETTE
    //               PNG_COLOR_TYPE_RGB
    //               PNG_COLOR_TYPE_RGB_ALPHA
    //               PNG_COLOR_TYPE_GRAY_ALPHA
    //               PNG_COLOR_TYPE_RGBA          (alias for _RGB_ALPHA)
    //               PNG_COLOR_TYPE_GA            (alias for _GRAY_ALPHA)
    // - pitch:      The stride (e.g. '4 * width' for RGBA).
    // - transform:  PNG_TRANSFORM_IDENTITY
    //               PNG_TRANSFORM_PACKING
    //               PNG_TRANSFORM_PACKSWAP
    //               PNG_TRANSFORM_INVERT_MONO
    //               PNG_TRANSFORM_SHIFT
    //               PNG_TRANSFORM_BGR
    //               PNG_TRANSFORM_SWAP_ALPHA
    //               PNG_TRANSFORM_SWAP_ENDIAN
    //               PNG_TRANSFORM_INVERT_ALPHA
    //               PNG_TRANSFORM_STRIP_FILLER

    // _ = png.save("yo.png", frame.*.width, frame.*.height, 16, libpng.PNG_COLOR_TYPE_RGB, rgb.*.data, 3, libpng.PNG_TRANSFORM_IDENTITY);

    // initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // free the memory on exit
    defer arena.deinit();

    // initialize the allocator
    const allocator = arena.allocator();

    const buffer: [*]img.color.Rgb24 = @ptrCast(@alignCast(rgb.*.data));
    const b: []img.color.Rgb24 = buffer[0 .. frame.*.width * frame.*.height * 3];

    const image = img.Image{
        .allocator = allocator,
        .width = frame.*.width,
        .height = frame.*.height,
        .pixels = img.color.PixelStorage{ .rgb24 = b },
    };

    // const png_format = img.Image.EncoderOptions{ .png = img.Image.EncoderOptions.PNG };
    // const png_format = img.Image.EncoderOptions;

    _ = img.Image.writeToFilePath(image, "yo.png", .{
        .png = .{
            // These are defaults which can be substituted
            // .interlaced = false,
            // .filter_choice = .heuristic,
        },
    }) catch img.Image.WriteError;

    _ = switch (frame.*.frame_format) {
        libuvc.UVC_FRAME_FORMAT_H264 =>
        // /* use `ffplay H264_FILE` to play */
        // /* fp = fopen(H264_FILE, "a");
        //  * fwrite(frame->data, 1, frame->data_bytes, fp);
        //  * fclose(fp); */
        null,
        libuvc.UVC_COLOR_FORMAT_MJPEG =>
        // /* sprintf(filename, "%d%s", jpeg_count++, MJPEG_FILE);
        //  * fp = fopen(filename, "w");
        //  * fwrite(frame->data, 1, frame->data_bytes, fp);
        //  * fclose(fp); */
        null,
        libuvc.UVC_COLOR_FORMAT_YUYV => {},

        else => null,
    };

    if (frame.*.sequence % 30 == 0) {
        std.debug.print(" * got image {?}\n", .{frame.*.sequence});
    }

    //   /* Call a user function:
    //    *
    //    * my_type *my_obj = (*my_type) ptr;
    //    * my_user_function(ptr, rgb);
    //    * my_other_function(ptr, rgb->data, rgb->width, rgb->height);
    //    */

    //   /* Call a C++ method:
    //    *
    //    * my_type *my_obj = (*my_type) ptr;
    //    * my_obj->my_func(rgb);
    //    */

    //   /* Use opencv.highgui to display the image:
    //    *
    //    * cvImg = cvCreateImageHeader(
    //    *     cvSize(rgb->width, rgb->height),
    //    *     IPL_DEPTH_8U,
    //    *     3);
    //    *
    //    * cvSetData(cvImg, rgb->data, rgb->width * 3);
    //    *
    //    * cvNamedWindow("Test", CV_WINDOW_AUTOSIZE);
    //    * cvShowImage("Test", cvImg);
    //    * cvWaitKey(10);
    //    *
    //    * cvReleaseImageHeader(&cvImg);
    //    */

}

pub fn main() !void {
    std.debug.print("enum {?}", .{@intFromEnum(UvcFrameFormat.mjpeg)});
    // // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // // stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!

    // std.debug.print("yo", .{});

    var ctx: ?*libuvc.uvc_context_t = undefined;
    var dev: ?*libuvc.uvc_device_t = undefined;
    var ctrl: libuvc.uvc_stream_ctrl_t = undefined;
    var devh: ?*libuvc.uvc_device_handle_t = undefined;
    // var usb_devh: ?*libusb_device_handle = undefined;
    // var ret: u16 = 0
    //     unsigned int ret;

    //     bw = blobwatch_new(WIDTH, HEIGHT);

    //     SDL_Init(SDL_INIT_EVERYTHING);

    //     SDL_mutex* mutex = SDL_CreateMutex();

    const res0 = libuvc.uvc_init(&ctx, null);
    std.debug.print("res0 {?}", .{res0});
    std.log.info("{s}-{?}: yo", .{ @src().fn_name, @src().line });

    if (res0 < 0) {
        libuvc.uvc_perror(res0, "uvc_init");
        std.debug.print("uvc_init failed\n", .{});
        return;
    }

    std.debug.print("UVC initialized\n", .{});

    // ATTRS{dbc_idProduct}=="0010"
    //     ATTRS{dbc_idVendor}=="1d6b"
    // 0c45:6d1f
    // ATTRS{idProduct}=="6d1f"
    //     ATTRS{idVendor}=="0c45"

    //     ATTRS{idProduct}=="5423"
    //     ATTRS{idVendor}=="0bda"

    // ATTRS{idProduct}=="5411"
    //     ATTRS{idVendor}=="0bda"

    // ATTRS{idProduct}=="28c4"
    //     ATTRS{idVendor}=="1bcf"
    // ATTRS{serial}=="01.00.00"

    // const res1 = libuvc.uvc_find_device(ctx, &dev, 0x0c45, 0x6d1f, null);

    const res1 = libuvc.uvc_find_device(ctx, &dev, 0, 0, null);

    std.debug.print("res1 {?}\n", .{res1});
    std.log.info("{s}-{?}: yo", .{ @src().fn_name, @src().line });

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
    // var frame_format: libuvc.uvc_frame_format = undefined;
    var width: c_int = 640;
    var height: c_int = 480;
    var fps: c_int = 30;

    const frame_format: c_uint = switch (format_desc.*.bDescriptorSubtype) {
        libuvc.UVC_VS_FORMAT_MJPEG => libuvc.UVC_COLOR_FORMAT_MJPEG,
        libuvc.UVC_VS_FORMAT_FRAME_BASED => libuvc.UVC_FRAME_FORMAT_H264,
        else => libuvc.UVC_FRAME_FORMAT_YUYV,
    };

    if (frame_desc != null) {
        width = frame_desc.*.wWidth;
        height = frame_desc.*.wHeight;
        fps = @intCast(10000000 / frame_desc.*.dwDefaultFrameInterval);
    }

    std.debug.print("\nFirst format: {?} {?} {?} {?}\n", .{ format_desc.*, width, height, fps });

    // Try to negotiate first stream profile
    const res3 = libuvc.uvc_get_stream_ctrl_format_size(devh,
    // result stored in ctrl
    &ctrl, frame_format, width, height, fps);

    // Print out the result
    libuvc.uvc_print_stream_ctrl(&ctrl, null);

    if (res3 < 0) {
        //  device doesn't provide a matching stream
        libuvc.uvc_perror(res3, "get_mode");
        std.debug.print("device doesn't provide a matching stream\n", .{});
        return;
    }

    // /* Start the video stream. The library will call user function cb:
    //  *   cb(frame, (void *) 12345)
    //  */

    // const user_ptr: *anyopaque = undefined;
    const user_fn: *anyopaque = @constCast(&user_fun);

    const res4 = libuvc.uvc_start_streaming(devh, &ctrl, cb, user_fn, 0);

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
    std.debug.print("res5 {?}\n", .{res5});
    if (res5 == libuvc.UVC_SUCCESS) {
        std.debug.print(" ... enabled aperture priority auto exposure mode\n", .{});
    } else {
        libuvc.uvc_perror(res5, " ... uvc_set_ae_mode failed to enable auto exposure mode");
    }

    // stream for 10 seconds */
    // _ = unistd.sleep(10);
    std.time.sleep(std.time.ns_per_s * 10);

    // End the stream. Blocks until last callback is serviced */
    libuvc.uvc_stop_streaming(devh);
    std.debug.print("Done streaming.\n", .{});
}
