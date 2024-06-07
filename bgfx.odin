package bgfx

import "core:c"

VERSION :: 127

when ODIN_OS == .Windows {
  when ODIN_DEBUG && #exists("windows/bgfxDebug.lib") {
    foreign import lib {
      "windows/bgfxDebug.lib",
      "windows/bimg_decodeDebug.lib",
      "windows/bimgRelease.lib", // bimgDebug requires the `MTd` runtime
      "windows/bxDebug.lib",
      "system:User32.lib",
      "system:Gdi32.lib",
    }
  } else {
    foreign import lib {
      "windows/bgfxRelease.lib",
      "windows/bimg_decodeRelease.lib",
      "windows/bimgRelease.lib",
      "windows/bxRelease.lib",
      "system:User32.lib",
      "system:Gdi32.lib",
    }
  }
} else when ODIN_OS == .Linux {
  when ODIN_DEBUG && #exists("windows/libbgfxDebug.a") {
    foreign import lib {
      "linux/libbgfxDebug.a",
      "linux/libbimg_decodeDebug.a",
      "linux/libbimgDebug.a",
      "linux/libbxDebug.a",
      "system:stdc++",
    }
  } else {
    foreign import lib {
      "linux/libbgfxRelease.a",
      "linux/libbimg_decodeRelease.a",
      "linux/libbimgRelease.a",
      "linux/libbxRelease.a",
      "system:stdc++",
    }
  }
} else when ODIN_OS == .Darwin {

  // NOTE 2024-06-06 This is a guess, if you test this on macOS I would love to hear what libs/frameworks are required
  when ODIN_DEBUG && #exists("darwin/libbgfxDebug.a") {
  foreign import lib {
    "darwin/libbgfxDebug.a",
    "darwin/libbimg_decodeDebug.a",
    "darwin/libbimgDebug.a",
    "darwin/libbxDebug.a",
    "system:Cocoa.framework",
    "system:IOKit.framework",
    "system:OpenGL.framework",
    "system:QuartzCore.framework",
  }
  } else {
  foreign import lib {
    "darwin/libbgfxRelease.a",
    "darwin/libbimg_decodeRelease.a",
    "darwin/libbimgRelease.a",
    "darwin/libbxRelease.a",
    "system:Cocoa.framework",
    "system:IOKit.framework",
    "system:OpenGL.framework",
    "system:QuartzCore.framework",
  }
  }
} else {
  #panic("Unsupported OS!")
}

// Extra Types /////////////////////////////////////////////////////////////////////////////////////
  // These types are not part of BGFX, I added them to make some parameters' purposes more clear

  // An RGBA (or ABGR) color in the format 0x00112233
  Color :: distinct u32

  // Index into bgfx's editable palette
  PaletteIndex :: distinct u8

  // Color with background for debug messages
  ANSIColor :: bit_field u8 {
    fg : _ANSIColor_Code | 4,
    bg : _ANSIColor_Code | 4,
  }
  _ANSIColor_Code :: enum u8 {
    Clear,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Yellow,
    White,
    B_Black,
    B_Blue,
    B_Green,
    B_Cyan,
    B_Red,
    B_Magenta,
    B_Yellow,
    B_White,
  }

// Initialization and Shutdown /////////////////////////////////////////////////////////////////////

  // Initialization Parameters (bgfx_init_t)
  Init :: struct {
    type : RendererType,             // Select rendering backend (use .Auto to auto-select for platform)
    vendor_id : PCI_ID,              // Select adapter by type/vendor (use .None to auto-select)
    device_id : u16,                 // Select adapter by device id (use 0 for first device)
    capabilities : CapsFlags,        // Capabilities test mask (default is max(u64))
    debug : bool,                    // Enable device for debugging
    profile : bool,                  // Enable device for profiling
    platform_data : PlatformData,    // Platform data
    resolution : Resolution,         // Backbuffer resolution and reset parameters. See: `bgfx::Resolution`
    limits : struct {                // Configurable runtime limits parameters
      max_encoders : u16,                // Maximum number of encoder threads
      min_resource_cb_size : u32,        // Minimum resource command buffer size
      transient_bb_size : u32,           // Maximum transient vertex buffer size
      transient_ib_size : u32,           // Maximum transient index buffer size
    },
    callback : ^CallbackInterface,   // Application specific callback interface
    allocator : ^AllocatorInterface, // Custom allocator (use nil for CRT allocator)
  }

  // Backbuffer Parameters (bgfx_resolution_t)
  Resolution :: struct {
    format : TextureFormat, // Backbuffer format
    width : u32,            // Backbuffer width
    height : u32,           // Backbuffer height
    reset : ResetSettings,  // Backbuffer settings
    num_back_buffers : u8,  // Number of back buffers
    max_frame_latency : u8, // Maximum frame latency
    debug_text_scale : u8,  // Scale factor for debug text
  }

  // Vendor PCI IDs (BGFX_PCI_*)
  PCI_ID :: enum u16 {
    None                = 0x0000, // Autoselect adapter
    Software_Rasterizer = 0x0001, // Software rasterizer
    AMD                 = 0x1002, // AMD adapter
    Apple               = 0x106b, // Apple adapter
    Intel               = 0x8086, // Intel adapter
    NVIDIA              = 0x10de, // nVidia adapter
    Microsoft           = 0x1414, // Microsoft adapter
    ARM                 = 0x13b5, // ARM adapter
  }

  // Callback interface to implement application specific behavior (bgfx_callback_interface_t)
  //   Cached items are currently used for OpenGL and Direct3D 12 binary shaders
  // !!ATTENTION!! If Init.callback is set, the entire VTable should be populated (they can be stubs)
  CallbackInterface :: struct {
    using vtbl : ^CallbackVTable,
  }
  CallbackVTable :: struct {
    // This callback is called on unrecoverable errors
    //   It’s not safe to continue (Excluding Fatal.Debug_Check), inform the user and terminate the application
    // !!ATTENTION!! not thread safe and can be called from any thread
    // !!ATTENTION!! this is only called in bgfx's Debug build (or when `BX_CONFIG_DEBUG=1`)
    fatal : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                            file_path : cstring,       // [in ] File path where fatal message was generated
                            line : u16,                // [in ] Line where fatal message was generated
                            code : Fatal,              // [in ] Fatal error code
                            str : cstring),            // [in ] More information about error

    // Print debug message
    // !!ATTENTION!! not thread safe and can be called from any thread
    // !!ATTENTION!! the format of va_list data is not guaranteed across platforms
    // !!ATTENTION!! this is only called in bgfx's Debug build (or when `BX_CONFIG_DEBUG=1`)
    trace_vargs : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                  file_path : cstring,       // [in ] File path where debug message was generated
                                  line : u16,                // [in ] Line where debug message was generated
                                  format : cstring,          // [in ] printf style format
                                  _arg_list : ^c.va_list),  // [in ] Variable arguments list initialized with va_start

    // Profiler region begin
    // !!ATTENTION!! not thread safe and can be called from any thread
    profiler_begin : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                     name : cstring,            // [in ] Region name, contains dynamic string
                                     abgr : Color,              // [in ] Color of profiler region
                                     file_path : cstring,       // [in ] File path where profilerBegin was called
                                     line : u16),               // [in ] Line where profilerBegin was called

    // Profiler region begin with string literal name
    // !!ATTENTION!! not thread safe and can be called from any thread
    profiler_begin_literal : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                             name : cstring,            // [in ] Region name, contains string literal
                                             abgr : Color,              // [in ] Color of profiler region
                                             file_path : cstring,       // [in ] File path where profilerBeginLiteral was called
                                             line : u16),               // [in ] Line where profilerBeginLiteral was called

    // Profiler region end
    // !!ATTENTION!! not thread safe and can be called from any thread
    profiler_end : #type proc "c" (this : ^CallbackInterface), // [ent] Interface

    // Returns the size of a cached item
    cache_read_size : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                      id : u64,                  // [in ] Cache id
                                    ) -> (num_bytes : u32),      // [out] Number of bytes to read,
                                                                 //       or `0` if no cached item was found

    // Read cached item
    cache_read : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                 id : u64,                  // [in ] Cache id
                                 data : rawptr,             // [out] Buffer where to read data
                                 size : u32,                // [in ] Size of data to read
                               ) -> (was_read : bool),      // [out] True if data is read

    // Write cached item
    cache_write : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                  id : u64,                  // [in ] Cache id
                                  data : /*const*/ rawptr,   // [in ] Data to write
                                  size : u32),               // [in ] Size of data to write

    // Screenshot captured
    //   Screenshot format is always 4-byte BGRA
    screen_shot : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                  file_path : cstring,       // [in ] File path
                                  width : u32,               // [in ] Image width
                                  height : u32,              // [in ] Image height
                                  pitch : u32,               // [in ] Number of bytes to skip between the start of each horizontal line of the image
                                  data : /*const*/ rawptr,   // [in ] Image data
                                  size : u32,                // [in ] Image size
                                  yflip : bool),             // [in ] If `true`, image origin is bottom left

    // Called when a video capture begins
    capture_begin : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                    width : u32,               // [in ] Image width
                                    height : u32,              // [in ] Image height
                                    pitch : u32,               // [in ] Number of bytes to skip between the start of each horizontal line of the image
                                    format : TextureFormat,    // [in ] Texture format
                                    yflip : bool),             // [in ] If `true`, image origin is bottom left

    // Called when a video capture ends
    capture_end : #type proc "c" (this : ^CallbackInterface),

    // Captured frame
    capture_frame : #type proc "c" (this : ^CallbackInterface, // [ent] Interface
                                    data : /*const*/ rawptr,  // [in ] Image data
                                    size : u32),              // [in ] Image size
  }

  // Fatal Error (bgfx_fatal_t)
  Fatal :: enum i32 {
    Debug_Check,              // An assert failed (or another "minor" fatal error)
    Invalid_Shader,           // A shader's creation failed
    Unable_To_Initialize,     // Renderer backend failed to initialize
    Unable_To_Create_Texture, // NOTE 2024-06-06 This is not used
    Device_Lost,              // Direct3D failed to flip the back buffer
  }

  // Abstract allocator interface (bx_allocator_interface_t)
  AllocatorInterface :: struct {
    using vtbl : ^AllocatorVTable,
  }
  AllocatorVTable :: struct {
    /// Allocates, resizes, or frees memory block
    //    Allocate memory block: ptr == nil && size > 0
    //    Resize memory block:   ptr != nil && size > 0
    //    Free memory block:     ptr != nil && size == 0
    // !!ATTENTION!! Allocator must be thread safe
    realloc : #type proc "c" (this : ^AllocatorInterface, // [ent] Interface
                              ptr : rawptr,               // [in ] If `nil`, allocate a new block
                                                          //       If not `nil` resize/delete
                              size : uint,                // [in ] Size of memory to allocate/resize
                                                          //       If `0` delete memory block
                              align : uint,               // [in ] Alignment
                              file : cstring,             // [in ] Debug file path info
                              line : u32,                 // [in ] Debug file line info
                            ) -> (mem : rawptr),          // [out] Allocated memory
  }

  @(link_prefix="bgfx_")
  foreign lib {

    // Fill Init with default values
    init_ctor :: proc(
        init : ^Init) --- // [out] Pointer to structure to be initialized

    // Initialize the bgfx library
    init :: proc(
        init : /* const */ ^Init = nil, // [in ] Initialization parameters
      ) -> (success : bool) ---         // [out] If initialization was successful

    // Shutdown bgfx library
    shutdown :: proc() ---

  }

// Updating ////////////////////////////////////////////////////////////////////////////////////////

  // Backbuffer Settings (BGFX_RESET_*)
  ResetSettings :: bit_field u32 {
    _ : u8 | 1,                        // fullscreen: Not supported yet
    _ : u8 | 3,
    msaa : _ResetSettings_MSAA | 3,    // MSAA setting
    vsync : bool | 1,                  // Enable V-Sync
    max_anisotropy : bool | 1,         // Turn on/off max anisotropy
    capture : bool | 1,                // Begin screen capture
    _ : u8 | 3,
    flush_after_render : bool | 1,     // Flush rendering after submitting to GPU
    _flip_after_render : bool | 1,     // Swaps frames at the end of render, instead of before (only effective if BGFX_CONFIG_MULTITHREADED=0)
    srgb_backbuffer : bool | 1,        // Enable sRGB backbuffer
    hdr10 : bool | 1,                  // Enable HDR10 rendering
    hidpi : bool | 1,                  // Enable HiDPI rendering
    depth_clamp : bool | 1,            // Enable depth clamp
    suspend : bool | 1,                // Suspend rendering
    transparent_backbuffer : bool | 1, // !!ATTENTION!! Check Caps.supported for `.Transparent_Backbuffer`
  }
  _ResetSettings_MSAA :: enum {
    Disabled, // No MSAA
    x2,       // Enable 2x MSAA
    x4,       // Enable 4x MSAA
    x8,       // Enable 8x MSAA
    x16,      // Enable 16x MSAA
  }

  @(link_prefix="bgfx_")
  foreign lib {

    // Update and rebuild back-buffer
    //   This call doesn’t change the window size, it just resizes the back-buffer
    reset :: proc(
        width : u32,                                       // [in ] Back-buffer width
        height : u32,                                      // [in ] Back-buffer height
        flags := ResetSettings{},                          // [in ] Back-buffer flags
        format := max(TextureFormat)+TextureFormat(1)) --- // [in ] Back-buffer format

    // Advance to next frame
    //   When using multithreaded renderer, this call just swaps internal buffers, kicks render thread, and returns
    //   In singlethreaded renderer this call does frame rendering
    frame :: proc(
        capture := false,           // [in ] Capture frame with graphics debugger
      ) -> (frame_number : u32) --- // [out] Current frame number
                                    //       This might be used in conjunction with double/multi buffering data outside the library and passing it to library via makeRef()

  }

// Debug ///////////////////////////////////////////////////////////////////////////////////////////

  // Debug Flags (BGFX_DEBUG_*)
  DebugFlags :: bit_set[_DebugFlag; u32]
  _DebugFlag :: enum {
    Wireframe, // Enable wireframe for all primitives
    IFH,       // Enable infinitely fast hardware test
               //   No draw calls will be submitted to driver
               //   It's useful when profiling to quickly assess bottleneck between CPU and GPU
    Stats,     // Enable statistics display
    Text,      // Enable debug text display
    Profiler,  // Enable profiler
               //   This causes per-view statistics to be collected, available through ViewStats
               //   This is unrelated to the profiler functions in CallbackInterface
  }

  @(link_prefix="bgfx_")
  foreign lib {

    // Set debug flags
    set_debug :: proc(
        debug : DebugFlags) --- // Debug flags

    // Clear internal debug text buffer
    dbg_text_clear :: proc(
        attr := ANSIColor(0), // [in ] Background color
        small := false) ---   // [in ] Default 8x16 or 8x8 font

    // Print into internal debug text character-buffer (VGA-compatible text mode)
    dbg_text_printf :: proc(
        x, y : u16,                 // [in ] 2D position from top-left
        attr : ANSIColor,           // [in ] VGA text color palette
        format : cstring,           // [in ] printf style format
        #c_vararg args : ..any) --- // [in ] additional arguments for format string

    // NOTE 2024-06-04 Odin has no way to construct a va_list
    /*
    // Print into internal debug text character-buffer (VGA-compatible text mode)
    dbg_text_vprintf :: proc(
        x, y : u16,               // [in ] 2D position from top-left
        attr : ANSIColor,         // [in ] VGA text color palette
        format : cstring,         // [in ] printf style format
        arg_list : c.va_list) --- // [in ] additional arguments for format string
    */

    // Draw image into internal debug text buffer
    dbg_text_image :: proc(
        x, y : u16,                // [in ] 2D Position from top-left
        width, height : u16,       // [in ] Image width and height
        data : /* const */ rawptr, // [in ] Raw image data (character/attribute raw encoding)
        pitch : u16) ---           // [in ] Image pitch in bytes

  }

// Querying Information ////////////////////////////////////////////////////////////////////////////

  // Renderer:

    // Renderer Backend Type (bgfx_renderer_type_t)
    RendererType :: enum i32 {
      Noop,         // No rendering
      AGC,          // AGC (ps5)
      Direct_3D_11, // Direct3D 11.0
      Direct_3D_12, // Direct3D 12.0
      GNM,          // GNM (ps4)
      Metal,        // Metal
      NVN,          // NVN (switch)
      OpenGL_ES,    // OpenGL ES 2.0+
      OpenGL,       // OpenGL 2.1+
      Vulkan,       // Vulkan
      Auto,         // Automatically select (BGFX_RENDERER_TYPE_COUNT)
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Returns supported backend API renderers
      get_supported_renderers :: proc(
          max := u8(0),                    // [in ] Maximum elements in enum array
          renderers : ^RendererType = nil, // [out] Array where supported renderers will be written
                                           //       !!NOTE!! Originally called `_enum`
        ) -> (num_renderers : u8) ---      // [out] Number of supported renderers

      // Returns name of renderer
      get_renderer_name :: proc(
          type : RendererType,    // [in ] Renderer backend
        ) -> (name : cstring) --- // [out] Name of renderer

      // Returns current renderer backend API type
      // !!ATTENTION!! Only use after init()
      get_renderer_type :: proc() -> (renderer : RendererType) --- // [out] Current renderer backend

    }

  // Capabilities:

    // Renderer capabilities (bgfx_caps_t)
    Caps :: struct {
      rendererType : RendererType,                     // Renderer backend type
      supported : CapsFlags,                           // Supported functionality
      vendorId : PCI_ID,                               // Selected GPU vendor PCI id
      deviceId : u16,                                  // Selected GPU device id
      homogeneousDepth : bool,                         // True when NDC depth is in [-1, 1] range, otherwise its [0, 1]
      originBottomLeft : bool,                         // True when NDC origin is at bottom left
      numGPUs : u8,                                    // Number of enumerated GPUs
      gpu : [4]struct {                                // Enumerated GPUs (bgfx_caps_gpu_t)
        vendor_id : PCI_ID,                                // Vendor PCI id
        device_id : u16,                                   // Device id
      },
      limits : struct {                                // Renderer runtime limits (bgfx_caps_limits_t)
        maxDrawCalls : u32,                                // Maximum number of draw calls
        maxBlits : u32,                                    // Maximum number of blit calls
        maxTextureSize : u32,                              // Maximum texture size
        maxTextureLayers : u32,                            // Maximum texture layers
        maxViews : u32,                                    // Maximum number of views
        maxFrameBuffers : u32,                             // Maximum number of frame buffer handles
        maxFBAttachments : u32,                            // Maximum number of frame buffer attachments
        maxPrograms : u32,                                 // Maximum number of program handles
        maxShaders : u32,                                  // Maximum number of shader handles
        maxTextures : u32,                                 // Maximum number of texture handles
        maxTextureSamplers : u32,                          // Maximum number of texture samplers
        maxComputeBindings : u32,                          // Maximum number of compute bindings
        maxVertexLayouts : u32,                            // Maximum number of vertex format layouts
        maxVertexStreams : u32,                            // Maximum number of vertex streams
        maxIndexBuffers : u32,                             // Maximum number of index buffer handles
        maxVertexBuffers : u32,                            // Maximum number of vertex buffer handles
        maxDynamicIndexBuffers : u32,                      // Maximum number of dynamic index buffer handles
        maxDynamicVertexBuffers : u32,                     // Maximum number of dynamic vertex buffer handles
        maxUniforms : u32,                                 // Maximum number of uniform handles
        maxOcclusionQueries : u32,                         // Maximum number of occlusion query handles
        maxEncoders : u32,                                 // Maximum number of encoder threads
        minResourceCbSize : u32,                           // Minimum resource command buffer size
        transientVbSize : u32,                             // Maximum transient vertex buffer size
        transientIbSize : u32,                             // Maximum transient index buffer size
      },
      formats : [TextureFormat]CapsFormatTextureFlags, // Supported texture format capabilities
    }

    // Supported functionality (BGFX_CAPS_*)
    CapsFlags :: bit_set[_CapsFlag; u64]
    _CapsFlag :: enum {
      Alpha_To_Coverage,         // Alpha to coverage is supported
      Blend_Independent,         // Blend independent is supported
      Compute,                   // Compute shaders are supported
      Conservative_Raster,       // Conservative rasterization is supported
      Draw_Indirect,             // Draw indirect is supported
      Fragment_Depth,            // Fragment depth is available in fragment shader
      Fragment_Ordering,         // Fragment ordering is available in fragment shader
      Graphics_Debugger,         // Graphics debugger is present
      Hdr10,                     // HDR10 rendering is supported
      Hidpi,                     // HiDPI rendering is supported
      Image_RW,                  // Image Read/Write is supported
      Index32,                   // 32-bit indices are supported
      Instancing,                // Instancing is supported
      Occlusion_Query,           // Occlusion query is supported
      Renderer_Multithreaded,    // Renderer is on separate thread
      Swap_Chain,                // Multiple windows are supported
      Texture_2D_Array,          // 2D texture array is supported
      Texture_3D,                // 3D textures are supported
      Texture_Blit,              // Texture blit is supported
      Transparent_Backbuffer,    // Transparent back buffer supported
      _,                         // reserved (BGFX_CAPS_TEXTURE_COMPARE_RESERVED)
      Texture_Compare_LEqual,    // Texture compare less equal mode is supported
      Texture_Cube_Array,        // Cubemap texture array is supported
      Texture_Direct_Access,     // CPU direct access to GPU texture memory
      Texture_Read_Back,         // Read-back texture is supported
      Vertex_Attrib_Half,        // Vertex attribute half-float is supported
      Vertex_Attrib_Uint10,      // Vertex attribute 10_10_10_2 is supported
      Vertex_ID,                 // Rendering with VertexID only is supported
      Primitive_ID,              // PrimitiveID is available in fragment shader
      Viewport_Layer_Array,      // Viewport layer is available in vertex shader
      Draw_Indirect_Count,       // Draw indirect with indirect count is supported
    }

    // Texture format capability flags (BGFX_CAPS_FORMAT_TEXTURE_*)
    CapsFormatTextureFlags :: bit_set[_CapsFormatTextureFlag; u16]
    _CapsFormatTextureFlag :: enum {
      Tex_2D,               // Texture format is supported
      Tex_2D_SRGB,          // Texture as sRGB format is supported
      Tex_2D_Emulated,      // Texture format is emulated
      Tex_3D,               // Texture format is supported
      Tex_3D_SRGB,          // Texture as sRGB format is supported
      Tex_3D_Emulated,      // Texture format is emulated
      Tex_Cube,             // Texture format is supported
      Tex_Cube_SRGB,        // Texture as sRGB format is supported
      Tex_Cube_Emulated,    // Texture format is emulated
      Cap_Vertex,           // Texture format can be used from vertex shader
      Cap_Image_Read,       // Texture format can be used as image and read from
      Cap_Image_Write,      // Texture format can be used as image and written to
      Cap_Framebuffer,      // Texture format can be used as frame buffer
      Cap_Framebuffer_MSAA, // Texture format can be used as MSAA frame buffer
      Cap_MSAA,             // Texture can be sampled as MSAA
      Cap_Mip_Autogen,      // Texture format supports auto-generated mips
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Returns renderer capabilities
      // !!ATTENTION!! Only use after init()
      get_caps :: proc() -> (/* const */ capabilities : ^Caps) --- // [out] Pointer to static Caps structure

    }

  // Statistics:

    // Render Statistics/Debug Data (bgfx_stats_t)
    Stats :: struct {
      cpu_time_frame : i64,             // CPU time between two frame() calls (see Stats.cpu_timer_freq)
      cpu_time_begin : i64,             // Render thread CPU submit begin time (see Stats.cpu_timer_freq)
      cpu_time_end : i64,               // Render thread CPU submit end time (see Stats.cpu_timer_freq)
      cpu_timer_freq : i64,             // CPU high-res timer frequency (cpu timestamps/second)
      gpu_time_begin : i64,             // GPU frame begin time (see Stats.gpu_timer_freq)
      gpu_time_end : i64,               // GPU frame end time (see Stats.gpu_timer_freq)
      gpu_timer_freq : i64,             // GPU igh-res timer frequency (gpu timestamps/second)
      wait_render : i64,                // Time spent waiting for render backend thread to finish issuing draw commands to underlying graphics API
      wait_submit : i64,                // Time spent waiting for submit thread to advance to next frame
      num_draw : u32,                   // Number of draw calls submitted
      num_compute : u32,                // Number of compute calls submitted
      num_blit : u32,                   // Number of blit calls submitted
      max_gpu_latency : u32,            // GPU driver latency (number of frames in flight)
      gpu_frame_num : u32,              // Frame which generated GPU times
      num_dynamic_index_buffers : u16,  // Number of used dynamic index buffers
      num_dynamic_vertex_buffers : u16, // Number of used dynamic vertex buffers
      num_frame_buffers : u16,          // Number of used frame buffers
      num_index_buffers : u16,          // Number of used index buffers
      num_occlusion_queries : u16,      // Number of used occlusion queries
      num_programs : u16,               // Number of used programs
      num_shaders : u16,                // Number of used shaders
      num_textures : u16,               // Number of used textures
      num_uniforms : u16,               // Number of used uniforms
      num_vertex_buffers : u16,         // Number of used vertex buffers
      num_vertex_layouts : u16,         // Number of used vertex layouts
      texture_memory_used : i64,        // Estimate of texture memory used
      rt_memory_used : i64,             // Estimate of render target memory used
      transient_vb_used : i32,          // Amount of transient vertex buffer used
      transient_ib_used : i32,          // Amount of transient index buffer used
      num_prims : [Topology]u32,        // Number of primitives rendered
      gpu_memory_max : i64,             // Maximum available GPU memory for application
      gpu_memory_used : i64,            // Amount of GPU memory used by the application
      width : u16,                      // Backbuffer width in pixels
      height : u16,                     // Backbuffer height in pixels
      text_width : u16,                 // Debug text width in characters
      text_height : u16,                // Debug text height in characters
      num_views : u16,                  // Number of view stats
      view_stats : [^]ViewStats,        // Array of View stats
      num_encoders : u8,                // Number of encoders used during frame
      encoder_stats : [^]EncoderStats,  // Array of encoder stats
    }

    // View Stats (bgfx_view_stats_t)
    ViewStats :: struct {
      name : [256]u8,       // View name
      view : ViewID,        // View id
      cpu_time_begin : i64, // CPU (submit) begin time (see Stats.cpu_timer_freq)
      cpu_time_end : i64,   // CPU (submit) end time (see Stats.cpu_timer_freq)
      gpu_time_begin : i64, // GPU begin time (see Stats.gpu_timer_freq)
      gpu_time_end : i64,   // GPU end time (see Stats.gpu_timer_freq)
      gpu_frame_num : u32,  // Frame which generated GPU times
    }

    // Encoder Stats (bgfx_encoder_stats_t)
    EncoderStats :: struct {
      cpu_time_begin : i64, // Encoder thread CPU submit begin time
      cpu_time_end : i64,   // Encoder thread CPU submit end time
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Returns performance counters
      //   Returned pointer is valid until frame() is called
      get_stats :: proc() -> (/* const */ stats : ^Stats) --- // [out] Pointer to performance counters

    }

// Platform Specific ///////////////////////////////////////////////////////////////////////////////
  // These are platform specific APIs
  // It is only necessary to use these APIs in conjunction with creating windows

    // Renderer Status (bgfx_render_frame_t)
    RenderFrame :: enum i32 {
      No_Context, // Renderer context is not created yet
      Render,     // Renderer context is created and rendering
      Timeout,    // Renderer context wait for main thread signal timed out without rendering
      Exiting,    // Renderer context is getting destroyed
    }

    // Platform Data (bgfx_platform_data_t)
    PlatformData :: struct {
      ndt : rawptr,                  // Native display type (*nix specific)
      nwh : rawptr,                  // Native window handle (set to `nil` for headless)
      ctx : rawptr,                  // Graphics API context/device (if `nil` bgfx will create it)
      back_buffer : rawptr,          // Back-buffer/render target view (if `nil` bgfx will create it)
      back_buffer_DS : rawptr,       // Depth/stencil buffer/surface (if `nil` bgfx will create it)
      type : NativeWindowHandleType, // Required for platforms with more than one window type (Linux)
    }

    // Native Window Handle Type (bgfx_native_window_handle_type_t)
    NativeWindowHandleType :: enum i32 {
      Default, // Platform default handle type (X11 on Linux)
      Wayland, // Wayland
    }

    // Internal Data (bgfx_internal_data_t)
    InternalData :: struct {
      caps : ^Caps, // Renderer capabilities
      ctx : rawptr, // Graphics API context (GL context, Vulkan device, D3D device, ...)
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Blocks until timeout or frame() is called
      // !!ATTENTION!! Should only be used on platforms that don't allow creating a separate rendering thread
      //               If it is called before init(), a rendering thread will not be created
      render_frame :: proc(
          msecs := i32(-1),             // [in ] Timeout in milliseconds (`-1` to disable timeout)
        ) -> (status : RenderFrame) --- // [out] Current renderer status

      // Set platform data
      // !!ATTENTION!! Must be called before init()
      set_platform_data :: proc(
          data : /* const */ ^PlatformData) --- // [in ] Platform data

      // Get internal data for interop
      //   It’s expected you understand some bgfx internals before you use this call
      // !!ATTENTION!! Must only be called by the render thread
      get_internal_data :: proc() -> (internal : /* const */ ^InternalData) --- // [out] Internal data

      // Override internal texture with externally created texture
      //   It’s expected you understand some bgfx internals before you use this call
      //   Previously created internal texture will released
      // !!ATTENTION!! Must only be called by the render thread
      override_internal_texture_ptr :: proc(
          handle : TextureHandle,    // [in ] Texture handle
          ptr : uintptr,             // [in ] Native API pointer to texture
        ) -> (texture : uintptr) --- // [out] Native API pointer, or `nil` if it is not create yet

      // Override internal texture by creating a new texture
      //   It’s expected you understand some bgfx internals before you use this call
      //   Previously created internal texture will released
      // !!ATTENTION!! Must only be called by the render thread
      override_internal_texture :: proc(
          handle : TextureHandle,     // [in ] Texture handle
          width : u16,                // [in ] Width
          height : u16,               // [in ] Height
          num_mips : u8,              // [in ] Number of mip-maps
          format : TextureFormat,     // [in ] Texture format
          flags := TextureSettings{}, // [in ] Texture settings
        ) -> (texture : uintptr) ---  // [out] Native API pointer, or `nil` if it is not create yet

    }

// Miscellaneous ///////////////////////////////////////////////////////////////////////////////////

  // Primative Topology (bgfx_topology_t)
  Topology :: enum i32 {
    Tri_List,   // Triangle list
    Tri_Strip,  // Triangle strip
    Line_List,  // Line list
    Line_Strip, // Line stripF
    Point_List, // Point list
  }

  // Topology Conversion Function (bgfx_topology_convert_t)
  TopologyConvert :: enum i32 {
    Tri_List_Flip_Winding,   // Flip winding order of triangle list
    Tri_Strip_Flip_Winding,  // Flip winding order of triangle strip
    Tri_List_To_Line_List,   // Convert triangle list to line list
    Tri_Strip_To_Tri_List,   // Convert triangle strip to triangle list
    Line_Strip_To_Line_List, // Convert line strip to line list
  }

  // Topology Sort Order (bgfx_topology_sort_t)
  TopologySort :: enum i32 {
    Direction_Front_To_Back_Min,
    Direction_Front_To_Back_Avg,
    Direction_Front_To_Back_Max,
    Direction_Back_To_Front_Min,
    Direction_Back_To_Front_Avg,
    Direction_Back_To_Front_Max,
    Distance_Front_To_Back_Min,
    Distance_Front_To_Back_Avg,
    Distance_Front_To_Back_Max,
    Distance_Back_To_Front_Min,
    Distance_Back_To_Front_Avg,
    Distance_Back_To_Front_Max,
  }

  // Transformation Matrices Data (bgfx_transform_t)
  Transform :: struct {
    data : [^]matrix[4, 4]f32, // Pointer to first 4x4 matrix
    num : u16,                 // Number of matrices
  }

  // Discard Flags (BGFX_DISCARD_*)
  DiscardFlags :: bit_set[_DiscardFlag; u8]
  _DiscardFlag :: enum {
    Bindings,       // Discard texture sampler and buffer bindings
    Index_Buffer,   // Discard index buffer
    Instance_Data,  // Discard instance data
    State,          // Discard state and uniform bindings
    Transform,      // Discard transform
    Vertex_Streams, // Discard vertex streams
  }

  // Set palette color value (procedure overload)
  set_palette_color :: proc{ set_palette_color_rgba8, set_palette_color_float }

  @(link_prefix="bgfx_")
  foreign lib {

    // Pack vertex attribute into vertex stream format
    vertex_pack :: proc(
        input : /* const */ [4]f32,         // [in ] Value to be packed into vertex stream
        input_normalized : bool,            // [in ] True if input value is already normalized
        attr : Attrib,                      // [in ] Attribute to pack
        layout : /* const */ ^VertexLayout, // [in ] Vertex stream layout
        data : rawptr,                      // [in ] Destination vertex stream where data will be packed
        index := u32(0)) ---                // [in ] Vertex index that will be modified

    // Unpack vertex attribute from vertex stream format
    vertex_unpack :: proc(
        output : [4]f32,                    // [out] Result of unpacking
        attr : Attrib,                      // [in ] Attribute to unpack
        layout : /* const */ ^VertexLayout, // [in ] Vertex stream layout
        data : /* const */ rawptr,          // [in ] Source vertex stream from where data will be unpacked
        index := u32(0)) ---                // [in ] Vertex index that will be unpacked

    // Converts vertex stream data from one vertex stream format to another
    vertex_convert :: proc(
        dst_layout : /* const */ ^VertexLayout, // [in ] Destination vertex stream layout
        dst_data : rawptr,                      // [in ] Destination vertex stream
        src_layout : /* const */ ^VertexLayout, // [in ] Source vertex stream layout
        src_data : /* const */ rawptr,          // [in ] Source vertex stream data
        num := u32(1)) ---                      // [in ] Number of vertices to convert from source to destination

    // Weld vertices
    weld_vertices :: proc(
        output : rawptr,                    // [out] Welded vertices remapping table, the size of buffer must be the same as number of vertices
        layout : /* const */ ^VertexLayout, // [in ] Vertex stream layout
        data : /* const */ rawptr,          // [in ] Vertex stream
        num : u32,                          // [in ] Number of vertices in vertex stream
        index32 : bool,                     // [in ] Set to `true` if input indices are 32-bit
        epsilon := f32(0.001),              // [in ] Error tolerance for vertex position comparison
      ) -> (num_vertices : u32) ---         // [out] Number of unique vertices after vertex welding

    // Convert index buffer for use with different primitive topologies
    topology_convert :: proc(
        conversion : TopologyConvert, // [in ] Conversion type
        dst : rawptr,                 // [in ] Destination index buffer
                                      //       If `nil` function will return number of indices after conversion
        dst_size : u32,               // [in ] Destination index buffer size in bytes
                                      //       It must be large enough to contain output indices
                                      //       If destination size is insufficient index buffer will be truncated
        indices : /* const */ rawptr, // [in ] Source indices
        num_indices : u32,            // [in ] Number of input indices
        index32 : bool,               // [in ] Set to `true` if input indices are 32-bit
      ) -> (num_vertices : u32) ---   // [out] Number of output indices after conversion

    // Sort indices
    topology_sort_tri_list :: proc(
        sort : TopologySort,           // [in ] Sort order
        dst : rawptr,                  // [in ] Destination index buffer
        dst_size : u32,                // [in ] Destination index buffer in bytes
                                       //       It must be large enough to contain output indices
                                       //       If destination size is insufficient index buffer will be truncated
        dir : /* const */ [3]f32,      // [in ] Direction (vector must be normalized)
        pos : /* const */ [3]f32,      // [in ] Position
        vertices : /* const */ rawptr, // [in ] Pointer to first vertex represented as float x, y, z
                                       //       Must contain at least number of vertices referenced by index buffer
        stride : u32,                  // [in ] Vertex stride
        indices : /* const */ rawptr,  // [in ] Source indices
        num_indices : u32,             // [in ] Number of input indices
        index32 : bool) ---            // [in ] Set to `true` if input indices are 32-bit

    // Set palette color value
    set_palette_color_rgba8 :: proc(
        index : PaletteIndex, // [in ] Index into palette
        rgba : Color) ---     // [in ] Packed 32-bit RGBA value

    // Set palette color value
    @(link_name="bgfx_set_palette_color")
    set_palette_color_float :: proc(
        index : PaletteIndex,         // [in ] Index into palette
        rgba : /* const */[4]f32) --- // [in ] RGBA floating point value

    // Request screen shot of window back buffer
    // !!ATTENTION!! CallbackInterface.screen_shot must be implemented
    request_screen_shot :: proc(
        handle : FrameBufferHandle, // [in ] Frame buffer handle
                                    //       If handle is `.Invalid` request will be made for main window back buffer
        file_path : cstring) ---    // [in ] Will be passed to screen_shot() callback

  }

// Views ///////////////////////////////////////////////////////////////////////////////////////////
  // Views are the primary sorting mechanism in bgfx
  //   They represent buckets of draw and compute calls, or what are often known as ‘passes’
  // When compute calls and draw calls occupy the same bucket, the compute calls will be sorted to execute first
  //   Compute calls are always executed in order of submission, while draw calls are sorted by internal state if the View is not in sequential mode
  //   In most cases where the z-buffer is used, this change in order does not affect the desired output
  //   When draw call order needs to be preserved (e.g. when rendering GUIs), Views can be set to use sequential mode with set_view_mode()
  //   Sequential order is less efficient, because it doesn’t allow state change optimization, and should be avoided when possible
  // By default, Views are sorted by their View ID, in ascending order
  //   For dynamic renderers where the right order might not be known until the last moment, View IDs can be changed to use arbitrary ordering with set_view_order()
  // A View’s state is preserved between frames

  // Opaque View Handle (bgfx_view_id_t)
  ViewID :: distinct u16

  // Draw Call Sort Order (bgfx_view_mode_t)
  ViewMode :: enum i32 {
    Default,          // Default sort order
    Sequential,       // Sort in the same order in which submit calls were called
    Depth_Ascending,  // Sort draw call depth in ascending order
    Depth_Descending, // Sort draw call depth in descending order
  }

  // Backbuffer Ratio (bgfx_backbuffer_ratio_t)
  BackbufferRatio :: enum i32 {
    Equal,     // Equal to backbuffer
    Half,      // One half size of backbuffer
    Quarter,   // One quarter size of backbuffer
    Eigth,     // One eighth size of backbuffer
    Sixteenth, // One sixteenth size of backbuffer
    Double,    // Double size of backbuffer
  }

  // Clear Flags (BGFX_CLEAR_*)
  ClearFlags :: bit_set[_ClearFlag; u16]
  _ClearFlag :: enum {
    Color,           // Clear color
    Depth,           // Clear depth
    Stencil,         // Clear stencil
    Discard_Color_0, // Discard frame buffer attachment 0
    Discard_Color_1, // Discard frame buffer attachment 1
    Discard_Color_2, // Discard frame buffer attachment 2
    Discard_Color_3, // Discard frame buffer attachment 3
    Discard_Color_4, // Discard frame buffer attachment 4
    Discard_Color_5, // Discard frame buffer attachment 5
    Discard_Color_6, // Discard frame buffer attachment 6
    Discard_Color_7, // Discard frame buffer attachment 7
    Discard_Depth,   // Discard frame buffer depth attachment
    Discard_Stecil,  // Discard frame buffer stencil attachment
  }

  // Set view rectangle (procedure overload)
  //   Draw primitive outside view will be clipped
  set_view_rect :: proc{ set_view_rect_simple, set_view_rect_ratio }

  @(link_prefix="bgfx_")
  foreign lib {

    // Set view name
    //   In graphics debugger view name will appear as:
    //     "nnnce <view name>"
    //      ^  ^^ ^
    //      |  |+-- eye (L/R)
    //      |  +--- compute (C)
    //      +------ view id
    // !!ATTENTION!! This is debug only feature
    set_view_name :: proc(
        id : ViewID,         // [in ] View id
        name : cstring,      // [in ] View name
        len := max(i32)) --- // [in ] View name length
                             //       If length is max(i32) name is treated as zero-terminated

    // Set view rectangle
    //   Draw primitive outside view will be clipped
    @(link_name="bgfx_set_view_rect")
    set_view_rect_simple :: proc(
        id : ViewID,      // [in ] View id
        x, y : u16,       // [in ] 2D position from the top-left corner of the window
        width : u16,      // [in ] Width of view port region
        height : u16) --- // [in ] Height of view port region

    // Set view rectangle
    //   Draw primitive outside view will be clipped
    set_view_rect_ratio :: proc(
        id : ViewID,                 // [in ] View id
        x, y : u16,                  // [in ] 2D position from the top-left corner of the window
        ratio : BackbufferRatio) --- // [in ] Width and height will be set in respect to back-buffer size

    // Set view scissor
    //   Draw primitive outside view will be clipped
    //   When x, y, width and height are set to 0, scissor will be disabled
    set_view_scissor :: proc(
        id : ViewID,          // [in ] View id
        x := u16(0),          // [in ] X position from the left of the window
        y := u16(0),          // [in ] Y position from the top of the window
        width := u16(0),      // [in ] Width of scissor region
        height := u16(0)) --- // [in ] Height of scissor region

    // Set view clear flags
    set_view_clear :: proc(
        id : ViewID,               // [in ] View id
        flags : ClearFlags,        // [in ] Clear flags
        rgba := Color(0x000000FF), // [in ] Color clear value
        depth := f32(1.0),         // [in ] Depth clear value
        stencil := u8(0)) ---      // [in ] Stencil clear value

    // Set view clear flags with different clear color for each frame buffer texture
    //   set_palette_color() must be used to set up a clear color palette
    set_view_clear_mrt :: proc(
        id : ViewID,                 // [in ] View id
        flags : ClearFlags,          // [in ] Clear flags
        depth : f32,                 // [in ] Depth clear value
        stencil : u8,                // [in ] Stencil clear value
        c0 := max(PaletteIndex),     // [in ] Palette index for frame buffer attachment 0
        c1 := max(PaletteIndex),     // [in ] Palette index for frame buffer attachment 1
        c2 := max(PaletteIndex),     // [in ] Palette index for frame buffer attachment 2
        c3 := max(PaletteIndex),     // [in ] Palette index for frame buffer attachment 3
        c4 := max(PaletteIndex),     // [in ] Palette index for frame buffer attachment 4
        c5 := max(PaletteIndex),     // [in ] Palette index for frame buffer attachment 5
        c6 := max(PaletteIndex),     // [in ] Palette index for frame buffer attachment 6
        c7 := max(PaletteIndex)) --- // [in ] Palette index for frame buffer attachment 7

    // Set view sorting mode
    //   View mode must be set prior calling submit() for the view
    set_view_mode :: proc(
        id : ViewID,                  // [in ] View id
        mode := ViewMode.Default) --- // [in ] View sort mode

    // Set view frame buffer
    //   Not persistent after reset() call
    set_view_frame_buffer :: proc(
        id : ViewID,                    // [in ] View id
        handle : FrameBufferHandle) --- // [in ] Frame buffer handle
                                        //       Passing `.Invalid` will draw primitives from this view into default back buffer

    // Set view’s view matrix and projection matrix, all draw primitives in this view will use these two matrices
    set_view_transform :: proc(
        id : ViewID,                            // [in ] View id
        view : /* const */ ^matrix[4,4]f32,     // [in ] View matrix
        proj : /* const */ ^matrix[4,4]f32) --- // [in ] Projection matrix

    // Post submit view reordering
    set_view_order :: proc(
        id := ViewID(0),                       // [in ] First view id
        num := max(u16),                       // [in ] Number of views to remap
        order : /* const */ ^ViewID = nil) --- // [in ] View remap id table, if `nil` will reset views to default state

    // Reset all view settings to default
    reset_view :: proc(
        id : ViewID) --- // [in ] View id

  }

// Encoder /////////////////////////////////////////////////////////////////////////////////////////
  // API for multi-threaded submission
  // Draw state is not preserved between two draw calls
  //   All state is cleared after calling encoder_submit()

  // Encoders are used for submitting draw calls from multiple threads (bgfx_encoder_t)
  //   Only one encoder per thread should be used
  //   Use encoder_begin() to obtain an encoder for a thread
  Encoder :: distinct rawptr

  @(link_prefix="bgfx_")
  foreign lib {

    // Begin submitting draw calls from thread
    encoder_begin :: proc(
        for_thread := false,       // [in ] Explicitly request an encoder for a worker thread
      ) -> (encoder : Encoder) --- // [out] Encoder

    // End submitting draw calls from thread
    encoder_end :: proc(
        encoder : Encoder) ---  // [ent] Encoder

  }

  // Miscellaneous:

    @(link_prefix="bgfx_")
    foreign lib {

      // Submit an empty primitive for rendering
      //   Uniforms and draw state will be applied but no geometry will be submitted
      //   These empty draw calls will sort before ordinary draw calls
      //   Useful in cases when no other draw/compute primitive is submitted to view, but it’s desired to execute clear view
      encoder_touch :: proc(
          this : Encoder,  // [ent] Encoder
          id : ViewID) --- // [in ] View id

      // Discard all previously set state for draw or compute call
      encoder_discard :: proc(
          this : Encoder,               // [ent] Encoder
          flags := ~DiscardFlags{}) --- // [in ] Draw/compute states to discard

    }

  // Debug:

    @(link_prefix="bgfx_")
    foreign lib {

      // Sets a debug marker
      //   This allows you to group graphics calls together for easy browsing in graphics debugging tools
      encoder_set_marker :: proc(
          this : Encoder,      // [ent] Encoder
          name : cstring,      // [in ] Marker name
          len := max(i32)) --- // [in ] Marker name length
                               //       If length is max(i32) name is treated as zero-terminated

    }

  // State:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set render states for draw primitive
      encoder_set_state :: proc(
          this : Encoder,            // [ent] Encoder
          state : StateSettings,     // [in ] State settings
          rgba := BlendFactor{}) --- // [in ] Sets blend factor used for StateSettings.blend_func_* of `.Factor` and `.Inv_Factor`
                                     //       When StateSettings.blend_independent is set, this is blend settings for render target's 1, 2, and 3

    }

  // Stencil:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set stencil test state
      encoder_set_stencil :: proc(
          this : Encoder,               // [ent] Encoder
          fstencil : Stencil,           // [in ] Front stencil state
          bstencil := STENCIL_NONE) --- // [in ] Back stencil state
                                        //       If back is set to STENCIL_NONE fstencil is applied to both front and back facing primitives

    }

  // Scissor:
    // If the Scissor rectangle needs to be changed for every draw call in a View, use set_scissor()
    // Otherwise, use set_view_scissor()

    // Set scissor for draw primitive (procedure overload)
    //   To scissor for all primitives in view see set_view_scissor()
    encoder_set_scissor :: proc{ encoder_set_scissor_simple, encoder_set_scissor_cached }

    @(link_prefix="bgfx_")
    foreign lib {

      // Set scissor for draw primitive
      @(link_name="bgfx_encoder_set_scissor")
      encoder_set_scissor_simple :: proc(
          this : Encoder,            // [ent] Encoder
          x, y : u16,                // [in ] 2D position from top-left of the window
          width : u16,               // [in ] Width of scissor region
          height : u16,              // [in ] Height of scissor region
        ) -> (cache_index : u16) --- // [out] Scissor cache index

      // Set scissor from cache for draw primitive
      encoder_set_scissor_cached :: proc(
          this : Encoder,        // [ent] Encoder
          cache := max(u16)) --- // [in ] Index in scissor cache
                                 //       If max(u16) use the view scissor instead

    }

  // Transform:

    // Set model matrix for draw primitive (procedure overload)
    //   If it is not called, model will be rendered with identity model matrix
    encoder_set_transform :: proc{ encoder_set_transform_simple, encoder_set_transform_cached }

    @(link_prefix="bgfx_")
    foreign lib {

      // Reserve `num` matrices in internal matrix cache
      encoder_alloc_transform :: proc(
          this : Encoder,            // [ent] Encoder
          transform : ^Transform,    // [out] Pointer to Transform structure
          num : u16,                 // [in ] Number of matrices
        ) -> (cache_index : u32) --- // [out] Index into matrix cache

      // Set model matrix for draw primitive
      @(link_name="bgfx_encoder_set_transform")
      encoder_set_transform_simple :: proc(
          this : Encoder,                      // [ent] Encoder
          mtx : /* const */ [^]matrix[4,4]f32, // [in ] Pointer to first matrix in array
          num := u16(1),                       // [in ] Number of matrices in array
        ) -> (cache_index : u32) ---           // [out] Index into cache in case the same model matrix has to be used for other draw primitive call

      // Set model matrix from matrix cache for draw primitive
      encoder_set_transform_cached :: proc(
          this : Encoder,    // [ent] Encoder
          cache : u32,       // [in ] Index in matrix cache
          num := u16(1)) --- // [in ] Number of matrices from cache

    }

  // Conditional Rendering:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set condition for rendering
      encoder_set_condition :: proc(
          this : Encoder,                // [ent] Encoder
          handle : OcclusionQueryHandle, // [in ] Occlusion query handle
          visible : bool) ---            // [in ] Render if occlusion query is visible

    }

  // Buffers:

    // Set index buffer for draw primitive (procedure overload)
    encoder_set_index_buffer :: proc{ encoder_set_index_buffer_simple, encoder_set_dynamic_index_buffer, encoder_set_transient_index_buffer }

    // Set vertex buffer for draw primitive (procedure overload)
    encoder_set_vertex_buffer :: proc{ encoder_set_vertex_buffer_simple, encoder_set_dynamic_vertex_buffer, encoder_set_transient_vertex_buffer }

    // Set instance data buffer for draw primitive (procedure overload)
    encoder_set_instance_data_buffer :: proc{ encoder_set_instance_data_buffer_simple, encoder_set_instance_data_from_vertex_buffer, encoder_set_instance_data_from_dynamic_vertex_buffer }

    @(link_prefix="bgfx_")
    foreign lib {

      // Set index buffer for draw primitive
      @(link_name="bgfx_encoder_set_index_buffer")
      encoder_set_index_buffer_simple :: proc(
          this : Encoder,              // [ent] Encoder
          handle : IndexBufferHandle,  // [in ] Index buffer
          first_index := u32(0),       // [in ] First index to render
          num_indices := max(u32)) --- // [in ] Number of indices to render

      // Set index buffer for draw primitive
      encoder_set_dynamic_index_buffer :: proc(
          this : Encoder,                    // [ent] Encoder
          handle : DynamicIndexBufferHandle, // [in ] Dynamic index buffer
          first_index := u32(0),             // [in ] First index to render
          num_indices := max(u32)) ---       // [in ] Number of indices to render

      // Set index buffer for draw primitive
      encoder_set_transient_index_buffer :: proc(
          this : Encoder,                          // [ent] Encoder
          tib : /* const */ ^TransientIndexBuffer, // [in ] Transient index buffer
          first_index := u32(0),                   // [in ] First index to render
          num_indices := max(u32)) ---             // [in ] Number of indices to render

      // Set vertex buffer for draw primitive
      @(link_name="bgfx_encoder_set_vertex_buffer_with_layout")
      encoder_set_vertex_buffer_simple :: proc(
          this : Encoder,                                  // [ent] Encoder
          stream : u8,                                     // [in ] Vertex stream
          handle : VertexBufferHandle,                     // [in ] Vertex buffer
          start_vertex := u32(0),                          // [in ] First vertex to render
          num_vertices := max(u32),                        // [in ] Number of vertices to render
          layout_handle := VertexLayoutHandle.Invalid) --- // [in ] Vertex layout for aliasing vertex buffer

      // Set vertex buffer for draw primitive
      @(link_name="encoder_set_dynamic_vertex_buffer_with_layout")
      encoder_set_dynamic_vertex_buffer :: proc(
          this : Encoder,                                  // [ent] Encoder
          stream : u8,                                     // [in ] Vertex stream
          handle : DynamicVertexBufferHandle,              // [in ] Dynamic vertex buffer
          start_vertex := u32(0),                          // [in ] First vertex to render
          num_vertices := max(u32),                        // [in ] Number of vertices to render
          layout_handle := VertexLayoutHandle.Invalid) --- // [in ] Vertex layout for aliasing vertex buffer

      // Set vertex buffer for draw primitive
      @(link_name="encoder_set_transient_vertex_buffer_with_layout")
      encoder_set_transient_vertex_buffer :: proc(
          this : Encoder,                                  // [ent] Encoder
          stream : u8,                                     // [in ] Vertex stream
          tvb : /* const */ ^TransientVertexBuffer,        // [in ] Transient vertex buffer
          start_vertex := u32(0),                          // [in ] First vertex to render
          num_vertices := max(u32),                        // [in ] Number of vertices to render
          layout_handle := VertexLayoutHandle.Invalid) --- // [in ] Vertex layout for aliasing vertex buffer

      // Set number of vertices for auto generated vertices use in conjunction with gl_VertexID
      //   !!ATTENTION!! Check Caps.supported for `.Vertex_ID`
      encoder_set_vertex_count :: proc(
          this : Encoder,         // [ent] Encoder
          num_vertices : u32) --- // [in ] Number of vertices

      // Set instance data buffer for draw primitive
      @(link_name="bgfx_encoder_set_instance_data_buffer")
      encoder_set_instance_data_buffer_simple :: proc(
          this : Encoder,                        // [ent] Encoder
          idb : /* const */ ^InstanceDataBuffer, // [in ] Transient instance data buffer
          start : u32,                           // [in ] First instance data
          num : u32) ---                         // [in ] Number of data instances

      // Set instance data buffer for draw primitive
      encoder_set_instance_data_from_vertex_buffer :: proc(
          this : Encoder,              // [ent] Encoder
          handle : VertexBufferHandle, // [in ] Vertex buffer
          start_vertex : u32,          // [in ] First instance data
          num : u32) ---               // [in ] Number of data instances

      // Set instance data buffer for draw primitive
      encoder_set_instance_data_from_dynamic_vertex_buffer :: proc(
          this : Encoder,                     // [ent] Encoder
          handle : DynamicVertexBufferHandle, // [in ] Dynamic vertex buffer
          start_vertex : u32,                 // [in ] First instance data
          num : u32) ---                      // [in ] Number of data instances

      // Set number of instances for auto generated instances use in conjunction with gl_InstanceID
      //   !!ATTENTION!! Check Caps.supported for `.Vertex_ID` and `.Instancing`
      encoder_set_instance_count :: proc(
          this : Encoder,          // [ent] Encoder
          num_instances : u32) --- // [in ] Number of instances

    }

  // Textures:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set texture stage for draw primitive
      encoder_set_texture :: proc(
          this : Encoder,                           // [ent] Encoder
          stage : u8,                               // [in ] Texture unit
          sampler : UniformHandle,                  // [in ] Program sampler
          handle : TextureHandle,                   // [in ] Texture handle
          flags := SamplerSettings(0xFFFFFFFF)) --- // [in ] Texture sampling mode, default max(u32) value uses settings from texture

    }

  // Uniforms:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set shader uniform parameter for draw primitive
      encoder_set_uniform :: proc(
          this : Encoder,             // [ent] Encoder
          handle : UniformHandle,     // [in ] Uniform
          value : /* const */ rawptr, // [in ] Pointer to uniform data
          num := u16(1)) ---          // [in ] Number of elements
                                      //       Passing max(u16) will use the num passed on uniform creation

    }

  // Submit:
    // In Views, all draw commands are executed after blit and compute commands

    // Submit primitive for rendering (procedure overload)
    encoder_submit :: proc{ encoder_submit_simple, encoder_submit_occlusion_query, encoder_submit_indirect, encoder_submit_indirect_count }

    @(link_prefix="bgfx_")
    foreign lib {

      // Submit primitive for rendering
      @(link_name="bgfx_encoder_submit")
      encoder_submit_simple :: proc(
          this : Encoder,               // [ent] Encoder
          id : ViewID,                  // [in ] View id
          program : ProgramHandle,      // [in ] Program
          depth := u32(0),              // [in ] Depth for sorting
          flags := ~DiscardFlags{}) --- // [in ] Discard or preserve states

      // Submit primitive with occlusion query for rendering
      encoder_submit_occlusion_query :: proc(
          this : Encoder,                         // [ent] Encoder
          id : ViewID,                            // [in ] View id
          program : ProgramHandle,                // [in ] Program
          occlusion_query : OcclusionQueryHandle, // [in ] Occlusion query
          depth := u32(0),                        // [in ] Depth for sorting
          flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

      // Submit primitive for rendering with index and instance data info from indirect buffer
      // !!ATTENTION!! Check Caps.supported for `.Draw_Indirect`
      encoder_submit_indirect :: proc(
          this : Encoder,                         // [ent] Encoder
          id : ViewID,                            // [in ] View id
          program : ProgramHandle,                // [in ] Program
          indirect_handle : IndirectBufferHandle, // [in ] Indirect buffer
          start := u32(0),                        // [in ] First element in indirect buffer
          num := u32(1),                          // [in ] Number of draws
          depth := u32(0),                        // [in ] Depth for sorting
          flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

      // Submit primitive for rendering with index and instance data info and draw count from indirect buffers
      // !!ATTENTION!! Check Caps.supported for `.Draw_Indirect_Count`
      encoder_submit_indirect_count :: proc(
          this : Encoder,                         // [ent] Encoder
          id : ViewID,                            // [in ] View id
          program : ProgramHandle,                // [in ] Program
          indirect_handle : IndirectBufferHandle, // [in ] Indirect buffer
          start : u32,                            // [in ] First element in indirect buffer
          num_handle : IndexBufferHandle,         // [in ] Buffer for number of draws
                                                  //       Must be created with .draw_indirect and .index_32 set to `true`
          num_index := u32(0),                    // [in ] Element in number buffer
          num_max := max(u32),                    // [in ] Max number of draws
          depth := u32(0),                        // [in ] Depth for sorting
          flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

    }

  // Compute:
    // Compute state is not preserved between compute dispatches
    //   All state is cleared after calling dispatch()

    // Buffers:

      // Set compute buffer (procedure overload)
      encoder_set_compute_buffer :: proc{ encoder_set_compute_index_buffer, encoder_set_compute_vertex_buffer, encoder_set_compute_dynamic_index_buffer, encoder_set_compute_dynamic_vertex_buffer, encoder_set_compute_indirect_buffer }

      @(link_prefix="bgfx_")
      foreign lib {

        // Set compute index buffer
        encoder_set_compute_index_buffer :: proc(
            this : Encoder,             // [ent] Encoder
            stage : u8,                 // [in ] Compute stage
            handle : IndexBufferHandle, // [in ] Index buffer handle
            access : Access) ---        // [in ] Buffer access

        // Set compute vertex buffer
        encoder_set_compute_vertex_buffer :: proc(
            this : Encoder,              // [ent] Encoder
            stage : u8,                  // [in ] Compute stage
            handle : VertexBufferHandle, // [in ] Vertex buffer handle
            access : Access) ---         // [in ] Buffer access

        // Set compute dynamic index buffer
        encoder_set_compute_dynamic_index_buffer :: proc(
            this : Encoder,                    // [ent] Encoder
            stage : u8,                        // [in ] Compute stage
            handle : DynamicIndexBufferHandle, // [in ] Dynamic index buffer handle
            access : Access) ---               // [in ] Buffer access

        // Set compute dynamic vertex buffer
        encoder_set_compute_dynamic_vertex_buffer :: proc(
            this : Encoder,                     // [ent] Encoder
            stage : u8,                         // [in ] Compute stage
            handle : DynamicVertexBufferHandle, // [in ] Dynamic vertex buffer handle
            access : Access) ---                // [in ] Buffer access

        // Set compute indirect buffer
        encoder_set_compute_indirect_buffer :: proc(
            this : Encoder,                // [ent] Encoder
            stage : u8,                    // [in ] Compute stage
            handle : IndirectBufferHandle, // [in ] Indirect buffer handle
            access : Access) ---           // [in ] Buffer access

      }

    // Images:

      @(link_prefix="bgfx_")
      foreign lib {

        // Set compute image from texture
        encoder_set_image :: proc(
            this : Encoder,                                    // [ent] Encoder
            stage : u8,                                        // [in ] Texture unit
            handle : TextureHandle,                            // [in ] Texture handle
            mip : u8,                                          // [in ] Mip level
            access : Access,                                   // [in ] Texture access
            format := max(TextureFormat)+TextureFormat(1)) --- // [in ] Texture format

      }

    // Dispatch
      // In Views, all draw commands are executed after blit and compute commands

      // Dispatch compute (procedure overload)
      encoder_dispatch :: proc{ encoder_dispatch_simple, encoder_dispatch_indirect}

      @(link_prefix="bgfx_")
      foreign lib {

        // Dispatch compute
        @(link_name="bgfx_encoder_dispatch")
        encoder_dispatch_simple :: proc(
            this : Encoder,               // [ent] Encoder
            id : ViewID,                  // [in ] View id
            program : ProgramHandle,      // [in ] Compute program
            num_x := u32(1),              // [in ] Number of groups X
            num_y := u32(1),              // [in ] Number of groups Y
            num_z := u32(1),              // [in ] Number of groups Z
            flags := ~DiscardFlags{}) --- // [in ] Discard or preserve states

        // Dispatch compute indirect
        encoder_dispatch_indirect :: proc(
            this : Encoder,                         // [ent] Encoder
            id : ViewID,                            // [in ] View id
            program : ProgramHandle,                // [in ] Compute program
            indirect_handle : IndirectBufferHandle, // [in ] Indirect buffer
            start := u32(0),                        // [in ] First element in indirect buffer
            num := u32(1),                          // [in ] Number of dispatches
            flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

      }

  // Blit:

    @(link_prefix="bgfx_")
    foreign lib {

      // Blit texture 2D region between two 2D textures
      // !!ATTENTION!! Destination texture must be created with .blit_dst set to `true`
      encoder_blit :: proc(
          this : Encoder,        // [ent] Encoder
          id : ViewID,           // [in ] View id
          dst : TextureHandle,   // [in ] Destination texture handle
          dst_mip : u8,          // [in ] Destination texture mip level
          dst_x : u16,           // [in ] Destination texture X position
          dst_y : u16,           // [in ] Destination texture Y position
          dst_z : u16,           // [in ] If texture is 2D, this should be 0
                                 //       If texture is cube, this is the cube face
                                 //       If texture is 3D, this is the Z position
          src : TextureHandle,   // [in ] Source texture handle
          src_mip := u8(0),      // [in ] Source texture mip level
          src_x := u16(0),       // [in ] Source texture X position
          src_y := u16(0),       // [in ] Source texture Y position
          src_z := u16(0),       // [in ] If texture is 2D, this should be 0
                                 //       If texture is cube, this is the cube face
                                 //       If texture is 3D, this is the Z position
          width := max(u16),     // [in ] Width of region
          height := max(u16),    // [in ] Height of region
          depth := max(u16)) --- // [in ] If texture is 3D this represents depth of region, otherwise it's unused

    }

// Draw ////////////////////////////////////////////////////////////////////////////////////////////
  // Draw state is not preserved between two draw calls
  //   All state is cleared after calling submit()

  // Miscellaneous:

    @(link_prefix="bgfx_")
    foreign lib {

      // Submit an empty primitive for rendering
      //   Uniforms and draw state will be applied but no geometry will be submitted
      //   These empty draw calls will sort before ordinary draw calls
      //   Useful in cases when no other draw/compute primitive is submitted to view, but it’s desired to execute clear view
      touch :: proc(
          id : ViewID) --- // [in ] View id

      // Discard all previously set state for draw or compute call
      discard :: proc(
          flags := ~DiscardFlags{}) --- // [in ] Draw/compute states to discard

    }

  // Debug:

    @(link_prefix="bgfx_")
    foreign lib {

      // Sets a debug marker
      //   This allows you to group graphics calls together for easy browsing in graphics debugging tools
      set_marker :: proc(
          name : cstring,      // [in ] Marker name
          len := max(i32)) --- // [in ] Marker name length
                               //       If length is max(i32) name is treated as zero-terminated

      // Set shader debug name
      set_shader_name :: proc(
          handle : ShaderHandle, // [in ] Shader handle
          name : cstring,        // [in ] Shader name
          len : i32) ---         // [in ] Shader name length
                                 //       If length is max(i32) name is treated as zero-terminated


      // Set texture debug name
      set_texture_name :: proc(
          handle : TextureHandle, // [in ] Texture handle
          name : cstring,         // [in ] Texture name
          len : i32) ---          // [in ] Texture name length
                                  //       If length is max(i32) name is treated as zero-terminated

    }

  // State:

    // State Settings (BGFX_STATE_*)
    StateSettings :: bit_field u64 {
      write_r : bool | 1,                           // Enable red write
      write_g : bool | 1,                           // Enable green write
      write_b : bool | 1,                           // Enable blue write
      write_a : bool | 1,                           // Enable alpha write
      depth_test : _StateSettings_DepthTest | 4,    // Depth test state
      _ : u8 | 4,
      // !!ATTENTION!! if any function is enabled, they must all be enabled:
      func_src_rgb : _BlendState_BlendFunction | 4, // Weight function for source color
      func_dst_rgb : _BlendState_BlendFunction | 4, // Weight function for destination color
      func_src_a : _BlendState_BlendFunction | 4,   // Weight function for source alpha
      func_dst_a : _BlendState_BlendFunction | 4,   // Weight function for destination alpha
      equation_rgb : _BlendState_BlendEquation | 3, // Equation for color blending
      equation_a : _BlendState_BlendEquation | 3,   // Equation for alpha blending
      blend_independent : bool | 1,                 // Enable blend independent
      blend_alpha_to_coverage : bool | 1,           // Enable alpha to coverage
      cull_cw : bool | 1,                           // Cull clockwise triangles
      cull_ccw : bool | 1,                          // Cull counter-clockwise triangles
      write_z : bool | 1,                           // Enable depth write
      front_ccw : bool | 1,                         // Front counter-clockwise (default is clockwise)
      alpha_ref : u8 | 8,                           // Alpha reference value
      pt : _StateSettings_PrimativeType | 3,        // Primitive type
      _ : u8 | 1,
      point_size : u8 | 4,                          // Point size value
      msaa : bool | 1,                              // Enable MSAA rasterization
      line_aa : bool | 1,                           // Enable line AA rasterization
      conservative_raster : bool | 1,               // Enable conservative rasterization
      _ : u8 | 5,
    }
    _StateSettings_DepthTest :: enum { Disabled, Less, LEqual, Equal, GEqual, Greater, Not_Equal, Never, Always }
    _StateSettings_PrimativeType :: enum { Tri_List, Tri_Strip, Line_List, Line_Strip, Point_List }
    _BlendState_BlendFunction :: enum {
      Disabled,
      Zero,           // 0, 0, 0, 0
      One,            // 1, 1, 1, 1
      Src_Color,      // Rs, Gs, Bs, As
      Inv_Src_Color,  // 1-Rs, 1-Gs, 1-Bs, 1-As
      Src_Alpha,      // As, As, As, As
      Inv_Src_Alpha,  // 1-As, 1-As, 1-As, 1-As
      Dst_Alpha,      // Ad, Ad, Ad, Ad
      Inv_Dst_Alpha,  // 1-Ad, 1-Ad, 1-Ad ,1-Ad
      Dst_Color,      // Rd, Gd, Bd, Ad
      Inv_Dst_Color,  // 1-Rd, 1-Gd, 1-Bd, 1-Ad
      Src_Alpha_Sat,  // f, f, f, 1; f = min(As, 1-Ad)
      Factor,         // Blend factor
      Inv_Factor,     // 1-Blend factor
    }
    _BlendState_BlendEquation :: enum {
      Add,     // Blend add: src + dst
      Sub,     // Blend subtract: src - dst
      Rev_Sub, // Blend reverse subtract: dst - src
      Min,     // Blend min: min(src, dst)
      Max,     // Blend max: max(src, dst)
    }

    //                                          |MSAA            WRITE_Z|   |CULL_CW                        DEPTH_LESS| A B G R
    STATE_DEFAULT :: StateSettings( 0b00000_0_0_1_0000_0_000_00000000_0_1_0_1_0_0_000_000_0000_0000_0000_0000_0000_0001_1_1_1_1 )

    // Color + Independent Blend (u32 - no direct bgfx analogue)
    BlendFactor :: struct #raw_union {
      // Reference value for "Factor" BlendFunction:
      rgba : Color,

      // Render Target blend states for when StateSettings.blend_independent is set:
      using _ : bit_field u32 {
        // Framebuffer attachment 1:
        RT1_src : _BlendState_BlendFunction | 4,       // Weight function for source color + alpha
        RT1_dst : _BlendState_BlendFunction | 4,       // Weight function for destination color + alpha
        RT1_equation : _BlendState_BlendEquation | 3,  // Equation for color + alpha blending

        // Framebuffer attachment 2:
        RT2_src : _BlendState_BlendFunction | 4,       // Weight function for source color + alpha
        RT2_dst : _BlendState_BlendFunction | 4,       // Weight function for destination color + alpha
        RT2_equation : _BlendState_BlendEquation | 3,  // Equation for color + alpha blending

        // Framebuffer attachment 3:
        RT3_src : _BlendState_BlendFunction | 4,       // Weight function for source color + alpha
        RT3_dst : _BlendState_BlendFunction | 4,       // Weight function for destination color + alpha
        // NOTE (2024-05-20) BlendEq. is 3 bits, this is a bgfx bug:
        RT3_equation : _BlendState_BlendEquation | 2,  // Equation for color + alpha blending
      },
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Set render states for draw primitive
      set_state :: proc(
          state : StateSettings,     // [in ] State settings
          rgba := BlendFactor{}) --- // [in ] Sets blend factor used for StateSettings.blend_func_* of `.Factor` and `.Inv_Factor`
                                     //       When StateSettings.blend_independent is set, this is blend settings for render target's 1, 2, and 3

    }

  // Stencil:

    Stencil :: bit_field u32 {
      ref : u8 | 8,                       // Stencil reference value
      rmask : u8 | 8,                     // Stencil read mask
                                          // NOTE (2024-05-22) bgfx has no write mask
      test : _Stencil_Test | 4,           // Stencil test comparison
      op_fail_s : _Stencil_Operation | 4, // When stencil test fails
      op_fail_z : _Stencil_Operation | 4, // When stencil test passes, but depth test fails
      op_pass_z : _Stencil_Operation | 4, // When stencil and depth test pass
    }
    _Stencil_Test :: enum { Disabled, Less, LEqual, Equal, GEqual, Greater, Not_Equal, Never, Always }
    _Stencil_Operation :: enum { Zero, Keep, Replace, Increment_Wrap, Increment_Clamp, Decrement_Wrap, Decrement_Clamp, Invert }

    STENCIL_NONE :: Stencil(0)

    @(link_prefix="bgfx_")
    foreign lib {

      // Set stencil test state
      set_stencil :: proc(
          fstencil : Stencil,           // [in ] Front stencil state
          bstencil := STENCIL_NONE) --- // [in ] Back stencil state
                                        //       If back is set to STENCIL_NONE fstencil is applied to both front and back facing primitives

    }

  // Scissor:
    // If the Scissor rectangle needs to be changed for every draw call in a View, use set_scissor()
    // Otherwise, use set_view_scissor()

    // Set scissor for draw primitive (procedure overload)
    //   To scissor for all primitives in view see set_view_scissor()
    set_scissor :: proc{ set_scissor_simple, set_scissor_cached }

    @(link_prefix="bgfx_")
    foreign lib {

      // Set scissor for draw primitive
      @(link_name="bgfx_set_scissor")
      set_scissor_simple :: proc(
          x, y : u16,                // [in ] 2D position from top-left of the window
          width : u16,               // [in ] Width of scissor region
          height : u16,              // [in ] Height of scissor region
        ) -> (cache_index : u16) --- // [out] Scissor cache index

      // Set scissor from cache for draw primitive
      set_scissor_cached :: proc(
          cache := max(u16)) --- // [in ] Index in scissor cache
                                 //       If max(u16) use the view scissor instead

    }

  // Transform:

    // Set model matrix for draw primitive (procedure overload)
    //   If it is not called, model will be rendered with identity model matrix
    set_transform :: proc{ set_transform_simple, set_transform_cached }

    @(link_prefix="bgfx_")
    foreign lib {

      // Reserve `num` matrices in internal matrix cache
      alloc_transform :: proc(
          transform : ^Transform,    // [out] Pointer to Transform structure
          num : u16,                 // [in ] Number of matrices
        ) -> (cache_index : u32) --- // [out] Index into matrix cache

      // Set model matrix for draw primitive
      @(link_name="bgfx_set_transform")
      set_transform_simple :: proc(
          mtx : /* const */ [^]matrix[4,4]f32, // [in ] Pointer to first matrix in array
          num := u16(1),                       // [in ] Number of matrices in array
        ) -> (cache_index : u32) ---           // [out] Index into cache in case the same model matrix has to be used for other draw primitive call

      // Set model matrix from matrix cache for draw primitive
      set_transform_cached :: proc(
          cache : u32,       // [in ] Index in matrix cache
          num := u16(1)) --- // [in ] Number of matrices from cache

    }

  // Conditional Rendering:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set condition for rendering
      set_condition :: proc(
          handle : OcclusionQueryHandle, // [in ] Occlusion query handle
          visible : bool) ---            // [in ] Render if occlusion query is visible

    }

  // Buffers:

    // Transient Index Buffer (bgfx_transient_index_buffer_t)
    TransientIndexBuffer :: struct {
      data : [^]u8,               // Pointer to data
      size : u32,                 // Data size
      start_index : u32,          // First index
      handle : IndexBufferHandle, // Index buffer handle
      is_index_16 : bool,         // Index buffer format is 16-bits if true, otherwise it is 32-bit
    }

    // Transient Vertex Buffer (bgfx_transient_vertex_buffer_t)
    TransientVertexBuffer :: struct {
      data : [^]u8,                       // Pointer to data
      size : u32,                         // Data size
      start_vertex : u32,                 // First vertex
      stride : u16,                       // Vertex stride
      handle : VertexBufferHandle,        // Vertex buffer handle
      layout_handle : VertexLayoutHandle, // Vertex layout handle
    }

    // Instance Data Buffer (bgfx_instance_data_buffer_t)
    InstanceDataBuffer :: struct {
      data : [^]u8,                // Pointer to data
      size : u32,                  // Data size
      offset : u32,                // Offset in vertex buffer
      num : u32,                   // Number of instances
      stride : u16,                // Vertex buffer stride
      handle : VertexBufferHandle, // Vertex buffer object handle
    }

    // Set index buffer for draw primitive (procedure overload)
    set_index_buffer :: proc{ set_index_buffer_simple, set_dynamic_index_buffer, set_transient_index_buffer }

    // Set vertex buffer for draw primitive (procedure overload)
    set_vertex_buffer :: proc{ set_vertex_buffer_simple, set_dynamic_vertex_buffer, set_transient_vertex_buffer }

    // Set instance data buffer for draw primitive (procedure overload)
    set_instance_data_buffer :: proc{ set_instance_data_buffer_simple, set_instance_data_from_vertex_buffer, set_instance_data_from_dynamic_vertex_buffer }

    @(link_prefix="bgfx_")
    foreign lib {

      // Set index buffer for draw primitive
      @(link_name="bgfx_set_index_buffer")
      set_index_buffer_simple :: proc(
          handle : IndexBufferHandle,  // [in ] Index buffer
          first_index := u32(0),       // [in ] First index to render
          num_indices := max(u32)) --- // [in ] Number of indices to render

      // Set index buffer for draw primitive
      set_dynamic_index_buffer :: proc(
          handle : DynamicIndexBufferHandle, // [in ] Dynamic index buffer
          first_index := u32(0),             // [in ] First index to render
          num_indices := max(u32)) ---       // [in ] Number of indices to render

      // Set index buffer for draw primitive
      set_transient_index_buffer :: proc(
          tib : /* const */ ^TransientIndexBuffer, // [in ] Transient index buffer
          first_index := u32(0),                   // [in ] First index to render
          num_indices := max(u32)) ---             // [in ] Number of indices to render

      // Set vertex buffer for draw primitive
      @(link_name="bgfx_set_vertex_buffer_with_layout")
      set_vertex_buffer_simple :: proc(
          stream : u8,                                     // [in ] Vertex stream
          handle : VertexBufferHandle,                     // [in ] Vertex buffer
          start_vertex := u32(0),                          // [in ] First vertex to render
          num_vertices := max(u32),                        // [in ] Number of vertices to render
          layout_handle := VertexLayoutHandle.Invalid) --- // [in ] Vertex layout for aliasing vertex buffer

      // Set vertex buffer for draw primitive
      @(link_name="bgfx_set_dynamic_vertex_buffer_with_layout")
      set_dynamic_vertex_buffer :: proc(
          stream : u8,                                     // [in ] Vertex stream
          handle : DynamicVertexBufferHandle,              // [in ] Dynamic vertex buffer
          start_vertex := u32(0),                          // [in ] First vertex to render
          num_vertices := max(u32),                        // [in ] Number of vertices to render
          layout_handle := VertexLayoutHandle.Invalid) --- // [in ] Vertex layout for aliasing vertex buffer

      // Set vertex buffer for draw primitive
      @(link_name="bgfx_set_transient_vertex_buffer_with_layout")
      set_transient_vertex_buffer :: proc(
          stream : u8,                                     // [in ] Vertex stream
          tvb : /* const */ ^TransientVertexBuffer,        // [in ] Transient vertex buffer
          start_vertex := u32(0),                          // [in ] First vertex to render
          num_vertices := max(u32),                        // [in ] Number of vertices to render
          layout_handle := VertexLayoutHandle.Invalid) --- // [in ] Vertex layout for aliasing vertex buffer

      // Set number of vertices for auto generated vertices use in conjunction with gl_VertexID
      //   !!ATTENTION!! Check Caps.supported for `.Vertex_ID`
      set_vertex_count :: proc(
          num_vertices : u32) --- // [in ] Number of vertices

      // Set instance data buffer for draw primitive
      @(link_name="bgfx_set_instance_data_buffer")
      set_instance_data_buffer_simple :: proc(
          idb : /* const */ ^InstanceDataBuffer, // [in ] Transient instance data buffer
          start : u32,                           // [in ] First instance data
          num : u32) ---                         // [in ] Number of data instances

      // Set instance data buffer for draw primitive
      set_instance_data_from_vertex_buffer :: proc(
          handle : VertexBufferHandle, // [in ] Vertex buffer
          start_vertex : u32,          // [in ] First instance data
          num : u32) ---               // [in ] Number of data instances

      // Set instance data buffer for draw primitive
      set_instance_data_from_dynamic_vertex_buffer :: proc(
          handle : DynamicVertexBufferHandle, // [in ] Dynamic vertex buffer
          start_vertex : u32,                 // [in ] First instance data
          num : u32) ---                      // [in ] Number of data instances

      // Set number of instances for auto generated instances use in conjunction with gl_InstanceID
      //   !!ATTENTION!! Check Caps.supported for `.Vertex_ID` and `.Instancing`
      set_instance_count :: proc(
          num_instances : u32) --- // [in ] Number of instances

    }

  // Textures:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set texture stage for draw primitive
      set_texture :: proc(
          stage : u8,                               // [in ] Texture unit
          sampler : UniformHandle,                  // [in ] Program sampler
          handle : TextureHandle,                   // [in ] Texture handle
          flags := SamplerSettings(0xFFFFFFFF)) --- // [in ] Texture sampling mode, default max(u32) value uses settings from texture

    }

  // Uniforms:

    @(link_prefix="bgfx_")
    foreign lib {

      // Set shader uniform parameter for draw primitive
      set_uniform :: proc(
          handle : UniformHandle,     // [in ] Uniform
          value : /* const */ rawptr, // [in ] Pointer to uniform data
          num := u16(1)) ---          // [in ] Number of elements
                                      //       Passing max(u16) will use the num passed on uniform creation

    }

  // Submit:
    // In Views, all draw commands are executed after blit and compute commands

    // Submit primitive for rendering (procedure overload)
    submit :: proc{ submit_simple, submit_occlusion_query, submit_indirect, submit_indirect_count }

    @(link_prefix="bgfx_")
    foreign lib {

      // Submit primitive for rendering
      @(link_name="bgfx_submit")
      submit_simple :: proc(
          id : ViewID,                  // [in ] View id
          program : ProgramHandle,      // [in ] Program
          depth := u32(0),              // [in ] Depth for sorting
          flags := ~DiscardFlags{}) --- // [in ] Discard or preserve states

      // Submit primitive with occlusion query for rendering
      submit_occlusion_query :: proc(
          id : ViewID,                            // [in ] View id
          program : ProgramHandle,                // [in ] Program
          occlusion_query : OcclusionQueryHandle, // [in ] Occlusion query
          depth := u32(0),                        // [in ] Depth for sorting
          flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

      // Submit primitive for rendering with index and instance data info from indirect buffer
      // !!ATTENTION!! Check Caps.supported for `.Draw_Indirect`
      submit_indirect :: proc(
          id : ViewID,                            // [in ] View id
          program : ProgramHandle,                // [in ] Program
          indirect_handle : IndirectBufferHandle, // [in ] Indirect buffer
          start := u32(0),                        // [in ] First element in indirect buffer
          num := u32(1),                          // [in ] Number of draws
          depth := u32(0),                        // [in ] Depth for sorting
          flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

      // Submit primitive for rendering with index and instance data info and draw count from indirect buffers
      // !!ATTENTION!! Check Caps.supported for `.Draw_Indirect_Count`
      submit_indirect_count :: proc(
          id : ViewID,                            // [in ] View id
          program : ProgramHandle,                // [in ] Program
          indirect_handle : IndirectBufferHandle, // [in ] Indirect buffer
          start : u32,                            // [in ] First element in indirect buffer
          num_handle : IndexBufferHandle,         // [in ] Buffer for number of draws
                                                  //       Must be created with .draw_indirect and .index_32 set to `true`
          num_index := u32(0),                    // [in ] Element in number buffer
          num_max := max(u32),                    // [in ] Max number of draws
          depth := u32(0),                        // [in ] Depth for sorting
          flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

    }

  // Compute:
    // Compute state is not preserved between compute dispatches
    //   All state is cleared after calling dispatch()

    // Buffers:

      // Compute Buffer Access Mode (bgfx_access_t)
      Access :: enum i32 {
        Read,
        Write,
        Read_Write,
      }

      // Set compute buffer (procedure overload)
      set_compute_buffer :: proc{ set_compute_index_buffer, set_compute_vertex_buffer, set_compute_dynamic_index_buffer, set_compute_dynamic_vertex_buffer, set_compute_indirect_buffer }

      @(link_prefix="bgfx_")
      foreign lib {

        // Set compute index buffer
        set_compute_index_buffer :: proc(
            stage : u8,                 // [in ] Compute stage
            handle : IndexBufferHandle, // [in ] Index buffer handle
            access : Access) ---        // [in ] Buffer access

        // Set compute vertex buffer
        set_compute_vertex_buffer :: proc(
            stage : u8,                  // [in ] Compute stage
            handle : VertexBufferHandle, // [in ] Vertex buffer handle
            access : Access) ---         // [in ] Buffer access

        // Set compute dynamic index buffer
        set_compute_dynamic_index_buffer :: proc(
            stage : u8,                        // [in ] Compute stage
            handle : DynamicIndexBufferHandle, // [in ] Dynamic index buffer handle
            access : Access) ---               // [in ] Buffer access

        // Set compute dynamic vertex buffer
        set_compute_dynamic_vertex_buffer :: proc(
            stage : u8,                         // [in ] Compute stage
            handle : DynamicVertexBufferHandle, // [in ] Dynamic vertex buffer handle
            access : Access) ---                // [in ] Buffer access

        // Set compute indirect buffer
        set_compute_indirect_buffer :: proc(
            stage : u8,                    // [in ] Compute stage
            handle : IndirectBufferHandle, // [in ] Indirect buffer handle
            access : Access) ---           // [in ] Buffer access

      }

    // Images:

      @(link_prefix="bgfx_")
      foreign lib {

        // Set compute image from texture
        set_image :: proc(
            stage : u8,                                        // [in ] Texture unit
            handle : TextureHandle,                            // [in ] Texture handle
            mip : u8,                                          // [in ] Mip level
            access : Access,                                   // [in ] Texture access
            format := max(TextureFormat)+TextureFormat(1)) --- // [in ] Texture format

      }

    // Dispatch
      // In Views, all draw commands are executed after blit and compute commands

      // Dispatch compute (procedure overload)
      dispatch :: proc{ dispatch_simple, dispatch_indirect}

      @(link_prefix="bgfx_")
      foreign lib {

        // Dispatch compute
        @(link_name="bgfx_dispatch")
        dispatch_simple :: proc(
            id : ViewID,                  // [in ] View id
            program : ProgramHandle,      // [in ] Compute program
            num_x := u32(1),              // [in ] Number of groups X
            num_y := u32(1),              // [in ] Number of groups Y
            num_z := u32(1),              // [in ] Number of groups Z
            flags := ~DiscardFlags{}) --- // [in ] Discard or preserve states

        // Dispatch compute indirect
        dispatch_indirect :: proc(
            id : ViewID,                            // [in ] View id
            program : ProgramHandle,                // [in ] Compute program
            indirect_handle : IndirectBufferHandle, // [in ] Indirect buffer
            start := u32(0),                        // [in ] First element in indirect buffer
            num := u32(1),                          // [in ] Number of dispatches
            flags := ~DiscardFlags{}) ---           // [in ] Discard or preserve states

      }

  // Blit:

    @(link_prefix="bgfx_")
    foreign lib {

      // Blit texture 2D region between two 2D textures
      // !!ATTENTION!! Destination texture must be created with .blit_dst set to `true`
      blit :: proc(
          id : ViewID,           // [in ] View id
          dst : TextureHandle,   // [in ] Destination texture handle
          dst_mip : u8,          // [in ] Destination texture mip level
          dst_x : u16,           // [in ] Destination texture X position
          dst_y : u16,           // [in ] Destination texture Y position
          dst_z : u16,           // [in ] If texture is 2D, this should be 0
                                 //       If texture is cube, this is the cube face
                                 //       If texture is 3D, this is the Z position
          src : TextureHandle,   // [in ] Source texture handle
          src_mip := u8(0),      // [in ] Source texture mip level
          src_x := u16(0),       // [in ] Source texture X position
          src_y := u16(0),       // [in ] Source texture Y position
          src_z := u16(0),       // [in ] If texture is 2D, this should be 0
                                 //       If texture is cube, this is the cube face
                                 //       If texture is 3D, this is the Z position
          width := max(u16),     // [in ] Width of region
          height := max(u16),    // [in ] Height of region
          depth := max(u16)) --- // [in ] If texture is 3D this represents depth of region, otherwise it's unused

    }

// Resources ///////////////////////////////////////////////////////////////////////////////////////

  // Handles:
    // These are opaque handles to internal resources

    _Handle :: enum u16 {
      Invalid = max(u16), // Sentinel value for invalid resource
    }

    DynamicIndexBufferHandle :: distinct _Handle
    DynamicVertexBufferHandle :: distinct _Handle
    FrameBufferHandle :: distinct _Handle
    IndexBufferHandle :: distinct _Handle
    IndirectBufferHandle :: distinct _Handle
    OcclusionQueryHandle :: distinct _Handle
    ProgramHandle :: distinct _Handle
    ShaderHandle :: distinct _Handle
    TextureHandle :: distinct _Handle
    UniformHandle :: distinct _Handle
    VertexBufferHandle :: distinct _Handle
    VertexLayoutHandle :: distinct _Handle

    // Set debug name by handle (procedure overload)
    set_name :: proc{ set_shader_name, set_texture_name, set_vertex_buffer_name, set_index_buffer_name, set_frame_buffer_name }

    // Destroy something by handle (procedure overload)
    destroy :: proc{ destroy_shader, destroy_program, destroy_uniform, destroy_vertex_layout, destroy_vertex_buffer, destroy_dynamic_vertex_buffer, destroy_index_buffer, destroy_dynamic_index_buffer, destroy_texture, destroy_frame_buffer, destroy_indirect_buffer, destroy_occlusion_query }

  // Buffer Settings (BGFX_BUFFER_*)
    BufferSettings :: bit_field u16 {
      compute_format : _BufferSettings_Format | 4, // Vector type
      compute_type : _BufferSettings_Type | 2,     // Component type
      _ : u8 | 2,
      compute_read : bool | 1,                     // Buffer will be read by shader
      compute_write : bool | 1,                    // Buffer will be used for writing, it cannot be updated by the CPU
      draw_indirect : bool | 1,                    // Buffer will be used for storing draw indirect commands
      allow_resize : bool | 1,                     // Allow DYNAMIC Index/Vertex Buffers to resize during update
      index_32 : bool | 1,                         // Index buffer contains 32-bit indices
    }
    _BufferSettings_Format :: enum {
      Auto,    // Automatically selects the format and type for a buffer
      b8_x1,   // 1 8-bit value
      b8_x2,   // 2 8-bit values
      b8_x4,   // 4 8-bit values
      b16_x1,  // 1 16-bit value
      b16_x2,  // 2 16-bit values
      b16_x4,  // 4 16-bit values
      b32_x1,  // 1 32-bit value
      b32_x2,  // 2 32-bit values
      b32_x4,  // 4 32-bit values
    }
    _BufferSettings_Type :: enum {
      // NOTE 2024-06-06 Don't use `0`, but most renderer backends will treat `0` and `Int` as the same type
      Int = 1, // Type `int`
      UInt,    // Type `uint`
      Float,   // Type `float`
    }

  // Memory:

    // BGFX Mapped Memory (bgfx_memory_t)
    // !!ATTENTION!! Do not create this struct; use: alloc(), copy(), make_ref(), or make_ref_release()
    Memory :: struct {
      data : [^]u8, // Pointer to data
      size : u32,   // Data size
    }

    // Make reference to data to pass to bgfx (procedure overload)
    //   Unlike alloc(), this call doesn’t allocate memory for data, it just copies the `data` pointer
    make_ref :: proc{ make_ref_static, make_ref_release }

    @(link_prefix="bgfx_")
    foreign lib {

      // Allocate buffer to pass to bgfx calls
      //   Data will be freed inside bgfx
      alloc :: proc(
          size : u32,                           // [in ] Size to allocate
        ) -> (/* const */ memory : ^Memory) --- // [out] New allocated memory

      // Allocate buffer and copy data into it
      //   Data will be freed inside bgfx
      copy :: proc(
          data : /* const */ rawptr,             // [in ] Pointer to data to be copied
          size : u32,                            // [in ] Size of data to be copied
        ) -> (/* const */ memory : ^Memory) ---  // [out] New allocated memory

      // Make reference to data to pass to bgfx
      // !!ATTENTION!! You must make sure `data` is available for at least 2 frame() calls
      @(link_name="bgfx_make_ref")
      make_ref_static :: proc(
          data : /* const */ rawptr, // [in ] Pointer to data to be copied
          size : u32,                // [in ] Size of data
        ) -> (/* const */ memory : ^Memory) ---  // [out] New allocated memory

      // Make reference to data to pass to bgfx
      //   The `release_fn` function pointer is used to release this memory after it’s consumed
      // !!ATTENTION!! `release_fn` must be thread safe and able to be called from any thread
      make_ref_release :: proc(
          data : /* const */ rawptr,                                      // [in ] Pointer to data to be copied
          size : u32,                                                     // [in ] Size of data
          release_fn : #type proc "c" (ptr : rawptr, user_data : rawptr), // [in ] Callback function to release memory after use
          user_data : rawptr = nil,                                       // [in ] User data to be passed to callback function
        ) -> (/* const */ memory : ^Memory) ---                                       // [out] New allocated memory

    }

  // Shaders and Programs:
    // !!ATTENTION!! Shaders must be compiled with offline command line too shaderc

    // Create program (procedure overload)
    create_program :: proc{ create_program_vert_frag, create_compute_program }

    @(link_prefix="bgfx_")
    foreign lib {

      // Create shader from memory buffer
      // !!ATTENTION!! Shader binary is obtained by compiling shader offline with shaderc command line tool
      create_shader :: proc(
          mem : /* const */ ^Memory,     // [in ] Shader memory
        ) -> (shader : ShaderHandle) --- // [out] Shader handle

      // Returns the number of uniforms and uniform handles used inside a shader
      // !!ATTENTION!! Only non-predefined uniforms are returned
      get_shader_uniforms :: proc(
          handle : ShaderHandle,             // [in ] Shader handle
          uniforms : [^]UniformHandle = nil, // [out] UniformHandle array where data will be stored
          max := u16(0),                     // [in ] Maximum capacity of array
        ) -> (num_uniforms : u16) ---        // [out] Number of uniforms used by shader

      // Destroy shader
      //   Once a shader program is created with `handle`, it is safe to destroy that shader
      destroy_shader :: proc(
          handle : ShaderHandle) --- // [in ] Shader handle

      // Create program with vertex and fragment shaders
      @(link_name="bgfx_create_program")
      create_program_vert_frag :: proc(
          vsh : ShaderHandle,              // [in ] Vertex shader
          fsh : ShaderHandle,              // [in ] Fragment shader
          destroy_shaders := false,        // [in ] If true, shaders will be destroyed when program is destroyed
        ) -> (program : ProgramHandle) --- // [out] Program handle if vertex shader output and fragment shader input are matching
                                           //       Otherwise returns `.Invalid`

      // Create program with compute shader
      create_compute_program :: proc(
          csh : ShaderHandle,              // [in ] Compute shader
          destroy_shaders := false,          // [in ] If true, shader will be destroyed when program is destroyed
        ) -> (program : ProgramHandle) --- // [out] Program handle

      // Destroy program
      destroy_program :: proc(
          handle : ProgramHandle) --- // [in ] Program handle

    }

  // Uniforms:

    // Uniform Type (bgfx_uniform_type_t)
    UniformType :: enum i32 {
      Sampler,     // Sampler
      // Reserved, // Do not use
      Vec4 = 2,    // 4 floats vector
      Mat3,        // 3x3 matrix
      Mat4,        // 4x4 matrix
    }

    // Uniform Info (bgfx_uniform_info_t)
    UniformInfo :: struct {
      name : [256]u8,     // Uniform name
      type : UniformType, // Uniform type
      num : u16,          // Number of elements in array
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Create shader uniform parameter
      // !!ATTENTION!! Uniform names are unique
      //               It’s valid to call create_uniform() multiple times with the same uniform name
      //               The library will always return the same handle, but the handle reference count will be incremented
      //               This means that the same number of destroy_uniform must be called to properly destroy the uniform
      /*   Predefined Uniforms (in bgfx_shader.sh):
            # u_viewRect      vec4   - view rectangle for current view, in pixels (x, y, width, height)
            # u_viewTexel     vec4   - inverse width and height (1.0/width, 1.0/height, ?, ?)
            # u_view          mat4   - view matrix
            # u_invView       mat4   - inverted view matrix
            # u_proj          mat4   - projection matrix
            # u_invProj       mat4   - inverted projection matrix
            # u_viewProj      mat4   - concatenated view projection matrix
            # u_invViewProj   mat4   - concatenated inverted view projection matrix
            # u_model         mat4[] - array of model matrices, the array is sized `BGFX_CONFIG_MAX_BONES` as configure when the library was compiled (default is 32)
            # u_modelView     mat4   - concatenated model view matrix, only first model matrix from array is used
            # u_modelViewProj mat4   - concatenated model view projection matrix
            # u_alphaRef      float  - alpha reference value for alpha test */
      create_uniform :: proc(
          name : cstring,                  // [in ] Uniform name in shader
          type : UniformType,              // [in ] Type of uniform
          num := u16(1),                   // [in ] Number of elements in array
        ) -> (uniform : UniformHandle) --- // [out] Handle to uniform object

      // Retrieve uniform info
      get_uniform_info :: proc(
          handle : UniformHandle,  // [in ] Handle to uniform object
          info : ^UniformInfo) --- // [out] Uniform info

      // Destroy shader uniform parameter
      destroy_uniform :: proc(
          handle : UniformHandle) --- // [in ] Handle to uniform object

    }

  // Vertex Buffers:

    // Vertex Layout (bgfx_vertex_layout_t)
    VertexLayout :: struct {
      hash : u32,               // Murmur hash of struct, holds RendererType while building
      stride : u16,             // Distance between vertices in bytes
      offset : [Attrib]u16,     // Position in bytes of attribute in vertex
      attributes : [Attrib]u16, // Encoded vertex attribute (0b0000000in0ttt0cc i=as_int, n=normalized, t=type, c=num)
    }

    // Vertex Attribute (bgfx_attrib_t)
    Attrib :: enum i32 {
      Position,   // a_position
      Normal,     // a_normal
      Tangent,    // a_tangent
      Bitangent,  // a_bitangent
      Color_0,    // a_color0
      Color_1,    // a_color1
      Color_2,    // a_color2
      Color_3,    // a_color3
      Indices,    // a_indices
      Weight,     // a_weight
      Texcoord_0, // a_texcoord0
      Texcoord_1, // a_texcoord1
      Texcoord_2, // a_texcoord2
      Texcoord_3, // a_texcoord3
      Texcoord_4, // a_texcoord4
      Texcoord_5, // a_texcoord5
      Texcoord_6, // a_texcoord6
      Texcoord_7, // a_texcoord7
    }

    // Vertex Attribute Type (bgfx_attrib_type_t)
    AttribType :: enum i32 {
      Uint8,  // Uint8
      Uint10, // Uint10
              // !!ATTENTION!! Check Caps.supported for `.Vertex_Attrib_Uint10`
      Int16,  // Int16
      Half,   // Half float
              // !!ATTENTION!! Check Caps.supported for `.Vertex_Attrib_Half`
      Float,  // Float
    }

    // Create dynamic vertex buffer (procedure overload)
    create_dynamic_vertex_buffer :: proc{ create_dynamic_vertex_buffer_empty, create_dynamic_vertex_buffer_mem }

    @(link_prefix="bgfx_")
    foreign lib {

      // Create vertex layout
      create_vertex_layout :: proc(
          layout : /* const */ ^VertexLayout,         // [in ] Vertex layout
        ) -> (layout_handle : VertexLayoutHandle) --- // [out] Handle to layout

      // Destroy vertex layout
      destroy_vertex_layout :: proc(
          layout_handle : VertexLayoutHandle) --- // [in ] Vertex layout

      // Create static vertex buffer
      create_vertex_buffer :: proc(
          mem : /* const */ ^Memory,                  // [in ] Vertex buffer data
          layout : /* const */ ^VertexLayout,         // [in ] Vertex layout
          flags := BufferSettings{},                  // [in ] Buffer creation settings
        ) -> (buffer_handle : VertexBufferHandle) --- // [out] Static vertex buffer handle

      // Set static vertex buffer debug name
      set_vertex_buffer_name :: proc(
          handle : VertexBufferHandle, // [in ] Static vertex buffer handle
          name : cstring,              // [in ] Static vertex buffer name
          len := max(i32)) ---         // [in ] Static vertex buffer name length
                                       //       If length is max(i32) name is treated as zero-terminated

      // Destroy static vertex buffer
      destroy_vertex_buffer :: proc(
          handle : VertexBufferHandle) --- // [in ] Static vertex buffer handle

      // Start VertexLayout
      vertex_layout_begin :: proc(
          this : ^VertexLayout,               // [ent] The layout being started
          renderer_type := RendererType.Noop, // [in ] Renderer backend type
        ) -> (self : ^VertexLayout) ---       // [out] Returns itself

      // Finalized VertexLayout
      vertex_layout_end :: proc(
          this : ^VertexLayout) --- // [ent] The layout being modified

      // Add attribute to VertexLayout
      //   Must be called between vertex_layout_begin() and vertex_layout_end()
      vertex_layout_add :: proc(
          this : ^VertexLayout,         // [ent] The layout being modified
          attrib : Attrib,              // [in ] Attribute semantics
          num : u8,                     // [in ] Number of elements 1, 2, 3 or 4
          type : AttribType,            // [in ] Element type
          normalized := false,          // [in ] When using fixed point AttribType (f.e. Uint8) value will be normalized for vertex shader usage
                                        //       When normalized is set to true, Uint8 value in range 0-255 will be in range 0.0-1.0 in vertex shader
          as_int := false,              // [in ] Packaging rule for vertex_pack, vertex_unpack, and vertex_convert for Uint8 and Int16
                                        //       Unpacking code must be implemented inside vertex shader
        ) -> (self : ^VertexLayout) --- // [out] Returns itself

      // Skip num bytes in vertex stream
      vertex_layout_skip :: proc(
          this : ^VertexLayout,         // [ent] The layout being modified
          num : u8,                     // [in ] Number of bytes to skip
        ) -> (self : ^VertexLayout) --- // [out] Returns itself

      // Retrieve an added attribute
      vertex_layout_decode :: proc(
          this : /* const */ ^VertexLayout, // [ent] The layout being read
          attrib : Attrib,                  // [in ] Attribute semantics
          num : ^u8,                        // [out] Number of elements
          type : ^AttribType,               // [out] Element type
          normalized : ^bool,               // [out] If value is normalized
          as_int : ^bool) ---               // [out] Packaging rule

      // Checks if VertexLayout contains attribute
      vertex_layout_has :: proc(
          this : /* const */ ^VertexLayout,  // [ent] The layout being read
          attrib : Attrib,                   // [in ] Attribute semantics
        ) -> (contains_attribute : bool) --- // [out] If VertexLayout contains attribute

      // Create empty dynamic vertex buffer
      @(link_name="bgfx_create_dynamic_vertex_buffer")
      create_dynamic_vertex_buffer_empty :: proc(
          num : u32,                                         // [in ] Number of vertices
          layout : /* const */ ^VertexLayout,                // [in ] Vertex layout
          flags := BufferSettings{},                         // [in ] Buffer creation settings
        ) -> (buffer_handle : DynamicVertexBufferHandle) --- // [out] Dynamic vertex buffer handle

      // Create dynamic vertex buffer and initialize it
      create_dynamic_vertex_buffer_mem :: proc(
          mem : /* const */ ^Memory,                         // [in ] Vertex buffer data
          layout : /* const */ ^VertexLayout,                // [in ] Vertex layout
          flags := BufferSettings{},                         // [in ] Buffer creation settings
        ) -> (buffer_handle : DynamicVertexBufferHandle) --- // [out] Dynamic vertex buffer handle

      // Update dynamic vertex buffer
      update_dynamic_vertex_buffer :: proc(
          handle : DynamicVertexBufferHandle, // [in ] Dynamic vertex buffer handle
          start_vertex : u32,                 // [in ] Start vertex
          mem : /* const */ ^Memory) ---      // [in ] Vertex buffer data

      // Destroy dynamic vertex buffer
      destroy_dynamic_vertex_buffer :: proc(
          handle : DynamicVertexBufferHandle) --- // [in ] Dynamic vertex buffer handle

      // Returns number of available vertices
      get_avail_transient_vertex_buffer :: proc(
          num : u32,                          // [in ] Number of required vertices
          layout : /* const */ ^VertexLayout, // [in ] Vertex layout
        ) -> (num_vertices : u32) ---         // [out] Number of requested vertices or maximum available

      // Allocate transient vertex buffer
      alloc_transient_vertex_buffer :: proc(
          tvb : ^TransientVertexBuffer,           // [out] Will be filled, valid for the duration of frame, and can be reused for multiple draw calls
          num : u32,                              // [in ] Number of vertices to allocate
          layout : /* const */ ^VertexLayout) --- // [in ] Vertex layout

    }

  // Index Buffers:

    // Create dynamic index buffer (procedure overload)
    create_dynamic_index_buffer :: proc{ create_dynamic_index_buffer_empty, create_dynamic_index_buffer_mem }

    @(link_prefix="bgfx_")
    foreign lib {

      // Create static index buffer
      create_index_buffer :: proc(
          mem : /* const */ ^Memory,                 // [in ] Index buffer data
          flags := BufferSettings{},                 // [in ] Buffer creation settings
        ) -> (buffer_handle : IndexBufferHandle) --- // [out] Static index buffer handle

      // Set static index buffer debug name
      set_index_buffer_name :: proc(
          handle : IndexBufferHandle, // [in ] Static index buffer handle
          name : cstring,             // [in ] Static index buffer name
          len := max(i32)) ---        // [in ] Static index buffer name length
                                      //       If length is max(i32) name is treated as zero-terminated

      // Destroy static index buffer
      destroy_index_buffer :: proc(
          handle : IndexBufferHandle) --- // [in ] Static index buffer handle

      // Create empty dynamic index buffer
      @(link_name="bgfx_create_dynamic_index_buffer")
      create_dynamic_index_buffer_empty :: proc(
          num : u32,                                        // [in ] Number of indices
          flags := BufferSettings{},                        // [in ] Buffer creation settings
        ) -> (buffer_handle : DynamicIndexBufferHandle) --- // [out] Dynamic index buffer handle

      // Create a dynamic index buffer and initialize it
      create_dynamic_index_buffer_mem :: proc(
          mem : /* const */ ^Memory,                        // [in ] Index buffer data
          flags := BufferSettings{},                        // [in ] Buffer creation settings
        ) -> (buffer_handle : DynamicIndexBufferHandle) --- // [out] Dynamic index buffer handle

      // Update dynamic index buffer
      update_dynamic_index_buffer :: proc(
          handle : DynamicIndexBufferHandle, // [in ] Dynamic index buffer handle
          start_index : u32,                 // [in ] Start index
          mem : /* const */ ^Memory) ---     // [in ] Index buffer data

      // Destroy dynamic index buffer
      destroy_dynamic_index_buffer :: proc(
          handle : DynamicIndexBufferHandle) --- // [in ] Dynamic index buffer handle

      // Returns number of available indices
      get_avail_transient_index_buffer :: proc(
          num : u32,                 // [in ] Number of required indices
          index32 := false,          // [in ] Set to `true` if input indices will be 32-bit
        ) -> (num_indices : u32) --- // [out] Number of requested indices or maximum available

      // Allocate transient index buffer
      alloc_transient_index_buffer :: proc(
          tib : ^TransientIndexBuffer, // [out] Will be filled, valid for the duration of frame, and can be reused for multiple draw calls
          num : u32,                   // [in ] Number of indices to allocate
          index32 := false) ---        // [in ] Set to `true` if input indices will be 32-bit

      // Check for required space and allocate transient vertex and index buffers
      alloc_transient_buffers :: proc(
          tvb : ^TransientVertexBuffer,       // [out] Will be filled, valid for the duration of frame, and can be reused for multiple draw calls
          layout : /* const */ ^VertexLayout, // [in ] Vertex layout
          num_vertices : u32,                 // [in ] Number of vertices to allocate
          tib : ^TransientIndexBuffer,        // [out] Will be filled, valid for the duration of frame, and can be reused for multiple draw calls
          num_indices : u32,                  // [in ] Number of indices to allocate
          index32 := false,                   // [in ] Set to `true` if input indices will be 32-bit
        ) -> (success : bool) ---             // [out] Returns `true` if both buffers were allocated

    }

  // Textures:

    // Texture Format (bgfx_texture_format_t)
      // !!ATTENTION!! Check Caps.formats for which formats are supported
    TextureFormat :: enum i32 {
      // Compressed Formats:
        BC1,       // DXT1 R5G6B5A1
        BC2,       // DXT3 R5G6B5A4
        BC3,       // DXT5 R5G6B5A8
        BC4,       // LATC1/ATI1 R8
        BC5,       // LATC2/ATI2 RG8
        BC6H,      // BC6H RGB16F
        BC7,       // BC7 RGB 4-7 bits per color channel, 0-8 bits alpha
        ETC1,      // ETC1 RGB8
        ETC2,      // ETC2 RGB8
        ETC2A,     // ETC2 RGBA8
        ETC2A1,    // ETC2 RGB8A1
        PTC12,     // PVRTC1 RGB 2BPP
        PTC14,     // PVRTC1 RGB 4BPP
        PTC12A,    // PVRTC1 RGBA 2BPP
        PTC14A,    // PVRTC1 RGBA 4BPP
        PTC22,     // PVRTC2 RGBA 2BPP
        PTC24,     // PVRTC2 RGBA 4BPP
        ATC,       // ATC RGB 4BPP
        ATCE,      // ATCE RGBA 8 BPP explicit alpha
        ATCI,      // ATCI RGBA 8 BPP interpolated alpha
        ASTC4X4,   // ASTC 4x4 8.0 BPP
        ASTC5X4,   // ASTC 5x4 6.40 BPP
        ASTC5X5,   // ASTC 5x5 5.12 BPP
        ASTC6X5,   // ASTC 6x5 4.27 BPP
        ASTC6X6,   // ASTC 6x6 3.56 BPP
        ASTC8X5,   // ASTC 8x5 3.20 BPP
        ASTC8X6,   // ASTC 8x6 2.67 BPP
        ASTC8X8,   // ASTC 8x8 2.00 BPP
        ASTC10X5,  // ASTC 10x5 2.56 BPP
        ASTC10X6,  // ASTC 10x6 2.13 BPP
        ASTC10X8,  // ASTC 10x8 1.60 BPP
        ASTC10X10, // ASTC 10x10 1.28 BPP
        ASTC12X10, // ASTC 12x10 1.07 BPP
        ASTC12X12, // ASTC 12x12 0.89 BPP
      // Color Formats:
        /* RGBA16S
           ^   ^ ^
           |   | +-- [ ]Unorm
           |   |     [F]loat
           |   |     [S]norm
           |   |     [I]nt
           |   |     [U]int
           |   +---- Number of bits per component
           +-------- Components */
        Unknown,
        R1,
        A8,
        R8,
        R8I,
        R8U,
        R8S,
        R16,
        R16I,
        R16U,
        R16F,
        R16S,
        R32I,
        R32U,
        R32F,
        RG8,
        RG8I,
        RG8U,
        RG8S,
        RG16,
        RG16I,
        RG16U,
        RG16F,
        RG16S,
        RG32I,
        RG32U,
        RG32F,
        RGB8,
        RGB8I,
        RGB8U,
        RGB8S,
        RGB9E5F,
        BGRA8,
        RGBA8,
        RGBA8I,
        RGBA8U,
        RGBA8S,
        RGBA16,
        RGBA16I,
        RGBA16U,
        RGBA16F,
        RGBA16S,
        RGBA32I,
        RGBA32U,
        RGBA32F,
        B5G6R5,
        R5G6B5,
        BGRA4,
        RGBA4,
        BGR5A1,
        RGB5A1,
        RGB10A2,
        RG11B10F,
      // Depth Formats:
        Unknown_Depth,
        D16,
        D24,
        D24S8,
        D32,
        D16F,
        D24F,
        D32F,
        D0S8,
    }

    // Texture Settings (BGFX_TEXTURE_*)
    TextureSettings :: struct #packed { // 64 bits
      using sampler : SamplerSettings,          // Lower 32 are sampler flags
      using _ : bit_field u32 {
        _ : u8 | 3,
        msaa_sample : bool | 1,                 // Texture will be used for MSAA sampling
        rt : _TextureSettings_RenderTarget | 3, // Render target enabled, and MSAA settings
        rt_write_only : bool | 1,               // Render target will be used for writing
        _ : u8 | 4,
        compute_write : bool | 1,               // Texture will be used for compute write
        srbg : bool | 1,                        // Sample texture as sRGB
        blit_dst : bool | 1,                    // Texture will be used as blit destination
        read_back : bool | 1,                   // Texture will be used for read back from GPU
      }
    }
    _TextureSettings_RenderTarget :: enum { Disabled, No_MSAA, MSAA_x2, MSAA_x4, MSAA_x8, MSAA_x16 }

    // Sampler Settings (BGFX_SAMPLER_*)
    SamplerSettings :: bit_field u32 {
      u_wrap :_SamplerSettings_WrapMode | 2,         // Wrap U mode
      v_wrap :_SamplerSettings_WrapMode | 2,         // Wrap V mode
      w_wrap :_SamplerSettings_WrapMode | 2,         // Wrap W mode
      min_point : _SamplerSettings_SamplingMode | 1, // Min sampling mod
      min_anisotropic : bool | 1,                    // Min anisotropic filtering
      mag_point : _SamplerSettings_SamplingMode | 1, // Mag sampling mod
      mag_anisotropic : bool | 1,                    // Mag anisotropic filtering
      mip_point : _SamplerSettings_SamplingMode | 1, // Mip sampling mod
      _ : u8 | 4,
      compare : _SamplerSettings_Compare | 4,        // Depth comparison
      sample_stencil : bool | 1,                     // Sample stencil instead of depth
      _ : u8 | 3,
      border_color : PaletteIndex | 4,               // Border color (palette index)
    }
    _SamplerSettings_WrapMode :: enum { Repeat, Mirror, Clamp, Border }
    _SamplerSettings_SamplingMode :: enum { Linear, Point }
    _SamplerSettings_Compare :: enum { Disabled, Less, LEqual, Equal, GEqual, Greater, Not_Equal, Never, Always }

    TEXTURE_SETTINGS_UV_CLAMP :: TextureSettings{ sampler = SamplerSettings(0b0000_000_0_0000_0000_0_0_0_0_0_00_10_10) }

    // Texture Info (bgfx_texture_info_t)
    TextureInfo :: struct {
      format : TextureFormat, // Texture format
      storage_size : u32,     // Total amount of bytes required to store texture
      width : u16,            // Texture width
      height : u16,           // Texture height
      depth : u16,            // Texture depth
      num_layers : u16,       // Number of layers in texture array
      num_mips : u8,          // Number of MIP maps
      bits_per_pixel : u8,    // Format bits per pixel
      cube_map : bool,        // Texture is cubemap
    }

    // Cube Map Sides (BGFX_CUBE_MAP_*)
    /*           +----------+
                 |-z       2|
                 | ^  +y    |
                 | |        |
                 | +---->+x |
      +----------+----------+----------+----------+
      |+y       1|+y       4|+y       0|+y       5|
      | ^  -x    | ^  +z    | ^  +x    | ^  -z    |
      | |        | |        | |        | |        |
      | +---->+z | +---->+x | +---->-z | +---->-x |
      +----------+----------+----------+----------+
                 |+z       3|
                 | ^  -y    |
                 | |        |
                 | +---->+x |
                 +----------+ */
    CubeMap :: enum u8 {
      Positive_X = 0, // Cubemap +x
      Negative_X = 1, // Cubemap -x
      Positive_Y = 2, // Cubemap +y
      Negative_Y = 3, // Cubemap -y
      Positive_Z = 4, // Cubemap +z
      Negative_Z = 5, // Cubemap -z
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Validate texture parameters
      is_texture_valid :: proc(
          depth : u16,             // [in ] Depth dimension of volume texture
          cube_map : bool,         // [in ] Indicates that texture contains cubemap
          num_layers : u16,        // [in ] Number of layers in texture array
          format : TextureFormat,  // [in ] Texture format
          flags : TextureSettings, // [in ] Texture settings (no SamplerSettings)
        ) -> (valid : bool) ---    // [out] Returns `true` if a texture with the same parameters can be created

      // Calculate amount of memory required for texture
      calc_texture_size :: proc(
          info : ^TextureInfo,        // [out] Resulting texture info structure
          width : u16,                // [in ] Width
          height : u16,               // [in ] Height
          depth : u16,                // [in ] Depth dimension of volume texture
          cube_map : bool,            // [in ] Indicates that texture contains cubemap
          has_mips : bool,            // [in ] Indicates that texture contains full mip-map chain
          num_layers : u16,           // [in ] Number of layers in texture array
          format : TextureFormat) --- // [in ] Texture format

      // Create texture from memory buffer
      create_texture :: proc(
          mem : /* const */ ^Memory,              // [in ] DDS, KTX or PVR texture data
          flags := TextureSettings{},             // [in ] Texture creation and sampler settings
          skip := u8(0),                          // [in ] Skip top level mips when parsing texture
          info : ^TextureInfo = nil,              // [out] When not `nil` it returns parsed texture information
        ) -> (texture_handle : TextureHandle) --- // [out] Texture handle

      // Create 2D texture
      create_texture_2d :: proc(
          width : u16,                            // [in ] Width
          height : u16,                           // [in ] Height
          has_mips : bool,                        // [in ] Indicates that texture contains full mip-map chain
          num_layers : u16,                       // [in ] Number of layers in texture array
                                                  //       Must be 1 if Caps.supported does not have `.Texture_2D_Array`
          format : TextureFormat,                 // [in ] Texture format
          flags := TextureSettings{},             // [in ] Texture creation and sampler settings
          mem : /* const */ ^Memory = nil,        // [in ] Texture data
                                                  //       If not `nil`, created texture will be immutable
                                                  //       If `nil` content of the texture is uninitialized
                                                  //       When num_layers is more than 1, expected memory layout is texture and all mips together for each array element
        ) -> (texture_handle : TextureHandle) --- // [out] Texture handle

      // Create texture with size based on back-buffer ratio
      //   Texture will maintain ratio if back buffer resolution changes
      create_texture_2d_scaled :: proc(
          ratio : BackbufferRatio,                // [in ] Frame buffer size in respect to back-buffer size
          has_mips : bool,                        // [in ] Indicates that texture contains full mip-map chain
          num_layers : u16,                       // [in ] Number of layers in texture array
                                                  //       Must be 1 if Caps.supported does not have `.Texture_2D_Array`
          format : TextureFormat,                 // [in ] Texture format
          flags := TextureSettings{},             // [in ] Texture creation and sampler settings
        ) -> (texture_handle : TextureHandle) --- // [out] Texture handle

      // Update 2D texture
      update_texture_2d :: proc(
          handle : TextureHandle,    // [in ] Texture handle
          layer : u16,               // [in ] Layers in texture array
          mip : u8,                  // [in ] Mip level
          x : u16,                   // [in ] X offset in texture
          y : u16,                   // [in ] Y offset in texture
          width : u16,               // [in ] Width of texture block
          height : u16,              // [in ] Height of texture block
          mem : /* const */ ^Memory, // [in ] Texture update data
          pitch := max(u16)) ---     // [in ] Pitch of input image (bytes)
                                     //       When max(u16), it will be calculated internally based on width

      // Create 3D texture
      create_texture_3d :: proc(
          width : u16,                            // [in ] Width
          height : u16,                           // [in ] Height
          depth : u16,                            // [in ] Depth
          has_mips : bool,                        // [in ] Indicates that texture contains full mip-map chain
          format : TextureFormat,                 // [in ] Texture format
          flags := TextureSettings{},             // [in ] Texture creation and sampler settings
          mem : /* const */ ^Memory = nil,        // [in ] Texture data
                                                  //       If not `nil`, created texture will be immutable
                                                  //       If `nil` content of the texture is uninitialized
        ) -> (texture_handle : TextureHandle) --- // [out] Texture handle

      // Update 3D texture
      update_texture_3d :: proc(
          handle : TextureHandle,        // [in ] Texture handle
          mip : u8,                      // [in ] Mip level
          x : u16,                       // [in ] X offset in texture
          y : u16,                       // [in ] Y offset in texture
          z : u16,                       // [in ] Z offset in texture
          width : u16,                   // [in ] Width of texture block
          height : u16,                  // [in ] Height of texture block
          depth : u16,                   // [in ] Depth of texture block
          mem : /* const */ ^Memory) --- // [in ] Texture update data

      // Create Cube texture
      create_texture_cube :: proc(
          size : u16,                             // [in ] Cube side size
          has_mips : bool,                        // [in ] Indicates that texture contains full mip-map chain
          num_layers : u16,                       // [in ] Number of layers in texture array
                                                  //       Must be 1 if Caps.supported does not have `.Texture_2D_Array`
          format : TextureFormat,                 // [in ] Texture format
          flags := TextureSettings{},             // [in ] Texture creation and sampler flags
          mem : /* const */ ^Memory = nil,        // [in ] Texture data
                                                  //       If not `nil`, created texture will be immutable
                                                  //       If `nil` content of the texture is uninitialized
                                                  //       When num_layers is more than 1, expected memory layout is texture and all mips together for each array element
        ) -> (texture_handle : TextureHandle) --- // [out] Texture handle

      // Update Cube texture
      update_texture_cube :: proc(
          handle : TextureHandle,    // [in ] Texture handle
          layer : u16,               // [in ] Layers in texture array
          side : CubeMap,            // [in ] Cubemap side
          mip : u8,                  // [in ] Mip level
          x : u16,                   // [in ] X offset in texture
          y : u16,                   // [in ] Y offset in texture
          width : u16,               // [in ] Width of texture block
          height : u16,              // [in ] Height of texture block
          mem : /* const */ ^Memory, // [in ] Texture update data
          pitch := max(u16)) ---     // [in ] Pitch of input image (bytes)
                                     //       When max(u16), it will be calculated internally based on width

      // Read back texture content
      //   !!ATTENTION!! Check Caps.formats for `.Cap_Image_Read`
      //   !!ATTENTION!! Texture must be created with .read_back set to `true`
      read_texture :: proc(
          handle : TextureHandle,     // [in ] Texture handle
          data : rawptr,              // [in ] Destination buffer
          mip := u8(0),               // [in ] Mip level
        ) -> (frame_number : u32) --- // [out] Frame number when the result will be available, see frame()

      // Returns texture direct access pointer
      //   This feature is available on GPUs that have unified memory architecture (UMA) support
      // !!ATTENTION!! Check Caps.supported for `.Texture_Direct_Access`
      get_direct_access_ptr :: proc(
          handle : TextureHandle,            // [in ] Texture handle
        ) -> (texture_data_ptr : rawptr) --- // [out] Pointer to texture memory
                                             //       If returned pointer is `nil` direct access is not available for this texture
                                             //       If pointer is max(uintptr) sentinel value it means texture is pending creation
                                             //       Pointer returned can be cached and it will be valid until texture is destroyed

      // Destroy texture
      destroy_texture :: proc(
          handle : TextureHandle) --- // [in ] Texture handle

    }

  // Frame Buffers:

    // Frame Buffer Attachment Info (bgfx_attachment_t)
    Attachment :: struct {
      access : Access,        // Attachment access
      handle : TextureHandle, // Render target texture handle
      mip : u16,              // Mip level
      layer : u16,            // Cubemap side `u16(CubeMap.*)` or depth layer/slice to use
      num_layers : u16,       // Number of texture layer/slice(s) in array to use
      resolve : ResolveFlags, // Initialization flags
    }

    // Frame Buffer Initialization Flags (BGFX_RESOLVE_*)
    ResolveFlags :: bit_set[_ResolveFlag; u8]
    _ResolveFlag :: enum {
      Auto_Gen_Mips, // Auto-generate mip maps on resolve
    }

    // Create frame buffer (procedure overload)
    create_frame_buffer :: proc{ create_frame_buffer_simple, create_frame_buffer_scaled, create_frame_buffer_from_handles, create_frame_buffer_from_nwh, create_frame_buffer_from_attachment }

    @(link_prefix="bgfx_")
    foreign lib {

      // Initialize frame buffer attachment
      attachment_init :: proc(
          this : ^Attachment,                            // [ent] The attachment being initialized
          handle : TextureHandle,                        // [in ] Render target texture handle
          access := Access.Write,                        // [in ] Access mode
          layer := u16(0),                               // [in ] Cubemap side `u16(CubeMap.*)` or depth layer/slice to use
          num_layers := u16(1),                          // [in ] Number of texture layer/slice(s) in array to use
          mip := u16(0),                                 // [in ] Mip level
          resolve := ResolveFlags{ .Auto_Gen_Mips }) --- // [in ] Resolve flags

      // Validate frame buffer parameters
      is_frame_buffer_valid :: proc(
          num : u8,                             // [in ] Number of attachments
          attachment : /* const */ ^Attachment, // [in ] Attachment texture info
        ) -> (valid : bool) ---                 // [out] Returns `true` if a frame buffer with the same parameters can be created

      // Create frame buffer (simple)
      @(link_name="bgfx_create_frame_buffer")
      create_frame_buffer_simple :: proc(
          width : u16,                                     // [in ] Texture width
          height : u16,                                    // [in ] Texture height
          format : TextureFormat,                          // [in ] Texture format
          texture_flags := TEXTURE_SETTINGS_UV_CLAMP,      // [in ] Texture creation and sampler settings
        ) -> (frame_buffer_handle : FrameBufferHandle) --- // [out] Handle to frame buffer object

      // Create frame buffer with size based on back-buffer ratio
      //   Frame buffer will maintain ratio if back buffer resolution changes
      create_frame_buffer_scaled :: proc(
          ratio : BackbufferRatio,                         // [in ] Frame buffer size in respect to back-buffer size
          format : TextureFormat,                          // [in ] Texture format
          texture_flags := TEXTURE_SETTINGS_UV_CLAMP,      // [in ] Texture creation and sampler settings
        ) -> (frame_buffer_handle : FrameBufferHandle) --- // [out] Handle to frame buffer object

      // Create MRT frame buffer from texture handles (simple)
      create_frame_buffer_from_handles :: proc(
          num : u8,                                        // [in ] Number of texture attachments
          handles : /* const */ ^TextureHandle,            // [in ] Texture attachments
          destroy_texture := false,                        // [in ] If `true`, textures will be destroyed when frame buffer is destroyed
        ) -> (frame_buffer_handle : FrameBufferHandle) --- // [out] Handle to frame buffer object

      // Create frame buffer for multiple window rendering
      // !!ATTENTION!! Frame buffer cannot be used for sampling
      create_frame_buffer_from_nwh :: proc(
          nwh : rawptr,                                        // [in ] OS’ target native window handle
          width : u16,                                         // [in ] Window back buffer width
          height : u16,                                        // [in ] Window back buffer height
          format := max(TextureFormat)+TextureFormat(1),       // [in ] Window back buffer color format
          depth_format := max(TextureFormat)+TextureFormat(1), // [in ] Window back buffer depth format
        ) -> (frame_buffer_handle : FrameBufferHandle) ---     // [out] Handle to frame buffer object

      // Create MRT frame buffer from texture handles with specific layer and mip level
      create_frame_buffer_from_attachment :: proc(
          num : u8,                                        // [in ] Number of texture attachments
          attachment : /* const */ [^]Attachment,          // [in ] Attachment texture info
          destroy_texture := false,                        // [in ] If `true`, textures will be destroyed when frame buffer is destroyed
        ) -> (frame_buffer_handle : FrameBufferHandle) --- // [out] Handle to frame buffer object

      // Obtain texture handle of frame buffer attachment
      get_texture :: proc(
          handle : FrameBufferHandle,             // [in ] Frame buffer handle
          attachment := u8(0),                    // [in ] Frame buffer attachment index
        ) -> (texture_handle : TextureHandle) --- // [out] Returns `.Invalid` if attachment index is not correct, or frame buffer is created with native window handle

      // Set frame buffer debug name
      set_frame_buffer_name :: proc(
          handle : FrameBufferHandle, // [in ] Frame buffer handle
          name : cstring,             // [in ] Frame buffer name
          len := max(i32)) ---        // [in ] Frame buffer name length
                                      //       If length is max(i32) name is treated as zero-terminated

      // Destroy frame buffer
      destroy_frame_buffer :: proc(
          handle : FrameBufferHandle) --- // [in ] Frame buffer handle

    }

  // Instance Buffers:

    @(link_prefix="bgfx_")
    foreign lib {

      // Returns maximum available instance buffer slots
      get_avail_instance_data_buffer :: proc(
          num : u32,               // [in ] Number of required instances
          stride : u16,            // [in ] Stride per instance
        ) -> (num_slots : u32) --- // [out] Number of requested instance buffer slots or maximum available

      // Allocate instance data buffer
      alloc_instance_data_buffer :: proc(
          idb : ^InstanceDataBuffer, // [out] Will be filled, valid for the duration of frame, and can be reused for multiple draw calls
          num : u32,                 // [in ] Number of instances
          stride : u16) ---          // [in ] Instance stride
                                     //       !!ATTENTION!! Must be multiple of 16

    }

  // Indirect Buffers:

    @(link_prefix="bgfx_")
    foreign lib {

      // Create draw indirect buffer
      create_indirect_buffer :: proc(
          num : u32,                                    // [in ] Number of indirect calls
        ) -> (buffer_handle : IndirectBufferHandle) --- // [out] Indirect buffer handle

      // Destroy draw indirect buffer
      destroy_indirect_buffer :: proc(
          handle : IndirectBufferHandle) --- // [in ] Indirect buffer handle

    }

  // Occlusion Query:

    // Occlusion Query Result (bgfx_occlusion_query_result_t)
    OcclusionQueryResult :: enum i32 {
      Invisible, // Query failed test
      Visibile,  // Query passed test
      No_Result, // Query result is not available yet
    }

    @(link_prefix="bgfx_")
    foreign lib {

      // Create occlusion query
      create_occlusion_query :: proc() -> (occlusion_query : OcclusionQueryHandle) --- // [out] Handle to occlusion query object

      // Retrieve occlusion query result from previous frame
      get_result :: proc(
          handle : OcclusionQueryHandle,                   // [in ] Handle to occlusion query object
          result : ^i32 = nil,                             // [out] Number of pixels that passed test
                                                           //       This argument can be `nil` if result of occlusion query is not needed
        ) -> (occlusion_result : OcclusionQueryResult) --- // [out] Occlusion query result

      // Destroy occlusion query
      destroy_occlusion_query :: proc(
          handle : OcclusionQueryHandle) --- // [in ] Handle to occlusion query object

    }
