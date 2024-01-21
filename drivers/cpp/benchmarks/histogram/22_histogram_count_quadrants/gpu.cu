// Driver for 22_histogram_count_quadrants for CUDA and HIP
// struct Point {
//    double x, y;
// };
// 
// /* Count the number of cartesian points in each quadrant. The vector points contains a list of `Point` objects.
//    Store the counts in `bins`.
//    Use CUDA to count in parallel. The kernel is launched with at least N threads.
//    Example:
// 
//    input: [{x=1.5, y=0.1}, {x=-3, y=1.1}, {x=5, y=9}, {x=1.5, y=-1}, {x=3, y=-7}, {x=0.1, y=2}]
//    output: [3, 1, 0, 2]
// */
// __global__ void countQuadrants(const Point *points, size_t N, size_t bins[4]) {

#include <algorithm>
#include <numeric>
#include <random>
#include <vector>

#include "utilities.hpp"

#if defined(USE_CUDA)
// fix the issue where atomicAdd is not defined for size_t
static_assert(sizeof(size_t) == sizeof(unsigned long long), "size_t is not 64 bits");

__device__ __forceinline__ void atomicAdd(size_t* address, size_t val) {
   atomicAdd(reinterpret_cast<unsigned long long*>(address), val);
}
#endif

#include "generated-code.cuh"   // code generated by LLM
#include "baseline.hpp"


struct Context {
    Point *d_points;
    size_t *d_bins;
    std::vector<Point> h_points;
    std::array<size_t, 4> h_bins;
    size_t N;
    dim3 blockSize, gridSize;
};

void reset(Context *ctx) {
    for (int i = 0; i < ctx->h_points.size(); i += 1) {
        ctx->h_points[i].x = (rand() / (double) RAND_MAX) * 2.0 + 1.0;
        ctx->h_points[i].y = (rand() / (double) RAND_MAX) * 2.0 + 1.0;
    }
    ctx->h_bins.fill(0);

    COPY_H2D(ctx->d_points, ctx->h_points.data(), ctx->h_points.size());
    COPY_H2D(ctx->d_bins, ctx->h_bins.data(), ctx->h_bins.size());
}

Context *init() {
    Context *ctx = new Context();

    ctx->N = DRIVER_PROBLEM_SIZE;
    ctx->blockSize = dim3(1024);
    ctx->gridSize = dim3((ctx->N + ctx->blockSize.x - 1) / ctx->blockSize.x); // at least enough threads

    ctx->h_points.resize(ctx->N);

    ALLOC(ctx->d_points, ctx->N * sizeof(Point));
    ALLOC(ctx->d_bins, 4 * sizeof(size_t));

    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    countQuadrants<<<ctx->gridSize, ctx->blockSize>>>(ctx->d_points, ctx->N, ctx->d_bins);
}

void NO_OPTIMIZE best(Context *ctx) {
    correctCountQuadrants(ctx->h_points, ctx->h_bins);
}

bool validate(Context *ctx) {
    const size_t TEST_SIZE = 1024;
    dim3 blockSize = dim3(1024);
    dim3 gridSize = dim3((TEST_SIZE + blockSize.x - 1) / blockSize.x); // at least enough threads

    std::vector<Point> h_points(TEST_SIZE);
    std::array<size_t, 4> correct, test;

    Point *d_points;
    size_t *d_bins;
    ALLOC(d_points, TEST_SIZE * sizeof(Point));
    ALLOC(d_bins, 4 * sizeof(size_t));

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int i = 0; i < numTries; i += 1) {
        // set up input
        for (int j = 0; j < h_points.size(); j += 1) {
            h_points[j].x = (rand() / (double) RAND_MAX) * 2.0 + 1.0;
            h_points[j].y = (rand() / (double) RAND_MAX) * 2.0 + 1.0;
        }
        correct.fill(0);
        test.fill(0);

        COPY_H2D(d_points, h_points.data(), h_points.size());
        COPY_H2D(d_bins, test.data(), test.size());

        // compute correct result
        correctCountQuadrants(h_points, correct);

        // compute test result
        countQuadrants<<<gridSize, blockSize>>>(d_points, TEST_SIZE, d_bins);
        SYNC();

        // copy back
        COPY_D2H(test.data(), d_bins, test.size());
        
        if (!std::equal(correct.begin(), correct.end(), test.begin())) {
            FREE(d_points);
            FREE(d_bins);
            return false;
        }
    }

    FREE(d_points);
    FREE(d_bins);
    return true;
}

void destroy(Context *ctx) {
    FREE(ctx->d_points);
    FREE(ctx->d_bins);
    delete ctx;
}