#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0) restrict buffer MyDataBuffer {
    ivec2 data[];
}
my_data_buffer;

// Separate buffers for image data
layout (set = 0, binding = 1, r8) restrict uniform image2D inputImage;

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    ivec2 pos = my_data_buffer.data[gl_GlobalInvocationID.x];

    // ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    float oldColor = imageLoad(inputImage, pos).r;
    float newColor = 1.0 - oldColor;

    imageStore(inputImage, pos, vec4(newColor));
}