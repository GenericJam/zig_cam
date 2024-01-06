const std = @import("std");

const libuvc = @cImport({
    @cInclude("libuvc/libuvc.h");
});

const stdio = @cImport({
    @cInclude("stdio.h");
});

const unistd = @cImport({
    @cInclude("unistd.h");
});

// This callback function runs once per frame. Use it to perform any
// quick processing you need, or have it put the frame into your application's
// input queue. If this function takes too long, you'll start losing frames.
fn cb(frame: [*c]libuvc.uvc_frame_t, ptr: ?*anyopaque) callconv(.C) void {
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

    // We'll convert the image from YUV/JPEG to BGR, so allocate space
    const bgr = libuvc.uvc_allocate_frame(frame.*.width * frame.*.height * 3);

    defer libuvc.uvc_free_frame(bgr);

    if (bgr == null) {
        std.debug.print("unable to allocate bgr frame!\n", .{});
        return;
    }

    std.debug.print("callback! frame_format = {?}, width = {?}, height = {?}, length = {?}, frame_format = {?}\n", .{ frame.*.frame_format, frame.*.width, frame.*.height, frame.*.data_bytes, frame_format });

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
        libuvc.UVC_COLOR_FORMAT_YUYV => {
            // /* Do the BGR conversion */
            const ret = libuvc.uvc_any2bgr(frame, bgr);
            if (ret < 0) {
                libuvc.uvc_perror(ret, "uvc_any2bgr");

                return;
            }
        },

        else => null,
    };

    if (frame.*.sequence % 30 == 0) {
        std.debug.print(" * got image {?}\n", .{frame.*.sequence});
    }

    //   /* Call a user function:
    //    *
    //    * my_type *my_obj = (*my_type) ptr;
    //    * my_user_function(ptr, bgr);
    //    * my_other_function(ptr, bgr->data, bgr->width, bgr->height);
    //    */

    //   /* Call a C++ method:
    //    *
    //    * my_type *my_obj = (*my_type) ptr;
    //    * my_obj->my_func(bgr);
    //    */

    //   /* Use opencv.highgui to display the image:
    //    *
    //    * cvImg = cvCreateImageHeader(
    //    *     cvSize(bgr->width, bgr->height),
    //    *     IPL_DEPTH_8U,
    //    *     3);
    //    *
    //    * cvSetData(cvImg, bgr->data, bgr->width * 3);
    //    *
    //    * cvNamedWindow("Test", CV_WINDOW_AUTOSIZE);
    //    * cvShowImage("Test", cvImg);
    //    * cvWaitKey(10);
    //    *
    //    * cvReleaseImageHeader(&cvImg);
    //    */

}

pub fn main() !void {
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

    const res1 = libuvc.uvc_find_device(ctx, &dev, 0, 0, null);
    std.debug.print("res1 {?}\n", .{res1});
    std.log.info("{s}-{?}: yo", .{ @src().fn_name, @src().line });

    // Close the UVC context. This closes and cleans up any existing device handles,
    // and it closes the libusb context if one was not provided.
    defer libuvc.uvc_exit(ctx);
    // Release the device descriptor
    defer libuvc.uvc_unref_device(dev);

    // Release our handle on the device
    defer libuvc.uvc_close(devh);

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
    const res4 = libuvc.uvc_start_streaming(devh, &ctrl, cb, @ptrFromInt(12345), 0);

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
