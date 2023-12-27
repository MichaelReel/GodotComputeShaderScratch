#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer MyDataBuffer {
    float data[];
}
my_data_buffer;

// Separate buffers for image data
layout (set = 0, binding = 1, rgba8) restrict uniform readonly image2D inputImage;
layout (set = 0, binding = 2, rgba8) restrict uniform writeonly image2D outputImage;

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    my_data_buffer.data[gl_GlobalInvocationID.x] *= 2.0;

    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    vec4 oldColor = imageLoad(inputImage, pos);
    vec4 newColor = vec4(1.0) - oldColor;
    newColor.a = 1.0;
    imageStore(outputImage, pos, newColor);
}