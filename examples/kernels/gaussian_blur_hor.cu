__device__ float4 readx(const unsigned short * in_half, int x, int y, int w)
{
    return make_float4(__half2float(in_half[4 * (x + y * w) + 0]),
                       __half2float(in_half[4 * (x + y * w) + 1]),
                       __half2float(in_half[4 * (x + y * w) + 2]),
                       __half2float(in_half[4 * (x + y * w) + 3]));
}

__device__ float weightx(int i, int x, float invdx2)
{
    return exp(-invdx2*((i-x)*(i-x)));
}

__global__ void
gaussian_blur_hor(const unsigned short * in_half,
                  unsigned short * out_half,
                  const int n,
                  const int width,
                  const int height)
{
    const int x = blockIdx.x * blockDim.x + threadIdx.x;
    const int y = blockIdx.y * blockDim.y + threadIdx.y;

    // array index
    const int idx = x + width * y;

    // inside image bounds check
    if (x >= width || y >= height) {
        return;
    }

    // kernel code
    float4 out = make_float4(0, 0, 0, 0);
    const float invdx2 = 1.0/(width*width);
    float totWeight = 0;
    float w;
    for(int i = x - n; i <= x + n; ++i)  {
            if (x>= 0 && x < width) {
                w = weightx(i, x, invdx2);
                out += w * readx(in_half, i, y, width);
                totWeight += w;
            }
    }
    out /= totWeight;

    // float to half conversion
    out_half[4 * idx + 0] = __float2half_rn(out.x);
    out_half[4 * idx + 1] = __float2half_rn(out.y);
    out_half[4 * idx + 2] = __float2half_rn(out.z);
    out_half[4 * idx + 3] = __float2half_rn(out.w);
}
