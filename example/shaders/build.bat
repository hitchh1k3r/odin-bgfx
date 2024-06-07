@set BGFX_SRC_PATH="C:/bgfx/src/"

shaderc -f unlit.vert -o unlit_vert_dx11.bin -i %BGFX_SRC_PATH% --type v -p s_4_0
shaderc -f unlit.frag -o unlit_frag_dx11.bin -i %BGFX_SRC_PATH% --type f -p s_4_0

shaderc -f unlit.vert -o unlit_vert_dx12.bin -i %BGFX_SRC_PATH% --type v -p s_5_0
shaderc -f unlit.frag -o unlit_frag_dx12.bin -i %BGFX_SRC_PATH% --type f -p s_5_0

shaderc -f unlit.vert -o unlit_vert_metal.bin -i %BGFX_SRC_PATH% --type v -p metal
shaderc -f unlit.frag -o unlit_frag_metal.bin -i %BGFX_SRC_PATH% --type f -p metal

shaderc -f unlit.vert -o unlit_vert_vulkan.bin -i %BGFX_SRC_PATH% --type v -p spirv
shaderc -f unlit.frag -o unlit_frag_vulkan.bin -i %BGFX_SRC_PATH% --type f -p spirv

shaderc -f unlit.vert -o unlit_vert_opengl.bin -i %BGFX_SRC_PATH% --type v -p 120
shaderc -f unlit.frag -o unlit_frag_opengl.bin -i %BGFX_SRC_PATH% --type f -p 120

shaderc -f unlit.vert -o unlit_vert_opengles.bin -i %BGFX_SRC_PATH% --type v -p 100_es
shaderc -f unlit.frag -o unlit_frag_opengles.bin -i %BGFX_SRC_PATH% --type f -p 100_es

@pause
