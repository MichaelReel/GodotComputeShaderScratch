#[compute]
#version 450

const float erosionAmount = 0.005;

// Invocations in the (x, y, z) dimension
layout(local_size_x = 10, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0) restrict buffer MyDataBuffer {
    ivec2 data[];
}
my_data_buffer;

// Separate buffers for image data
layout (set = 0, binding = 1, r8) restrict uniform image2D inputImage;

ivec2 lowest_of_nine(ivec2 middle) {
    float lowest = imageLoad(inputImage, middle).r;
    ivec2 dir = ivec2(0);
    for (int i=-1; i<=1; i++) {
        for (int j=-1; j<=1; j++) {
            ivec2 offset = ivec2(j, i);
            float comp = imageLoad(inputImage, middle + offset).r;
            if (comp < lowest) {
                lowest = comp;
                dir.xy = offset;
            }
        }
    }
    return dir;
}

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups

    ivec2 pos = my_data_buffer.data[gl_GlobalInvocationID.x];

    ivec2 offset = lowest_of_nine(pos);
    while (offset != ivec2(0)) {
        // Move pos and get the next lowest point
        pos += offset;
        offset = lowest_of_nine(pos);

        // Erode the height at the position
        float oldHeight = imageLoad(inputImage, pos).r;
        float newHeight = max(0.0, oldHeight - erosionAmount);
        imageStore(inputImage, pos, vec4(newHeight));
    }


}