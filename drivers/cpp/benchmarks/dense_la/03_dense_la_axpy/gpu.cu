// Driver for 03_dense_la_axpy for CUDA and HIP
// /* Compute z = alpha*x+y where x and y are vectors. Store the result in z.
//    Use CUDA to compute in parallel. The kernel is launched with at least as many threads as values in x.
//    Example:
//    
//    input: x=[1, -5, 2, 9] y=[0, 4, 1, -1] alpha=2
//    output: z=[2, -6, 5, 17]
// */
// __global__ void axpy(double alpha, const double *x, const double *y, double *z, size_t N) {

#include <algorithm>
#include <numeric>
#include <random>
#include <vector>

#include "utilities.hpp"
#include "baseline.hpp"
#include "generated-code.cuh"   // code generated by LLM


struct Context {
    double alpha;
    double *d_x, *d_y, *d_z;
    std::vector<double> h_x, h_y, h_z;
    size_t N;
    dim3 blockSize, gridSize;
};

void reset(Context *ctx) {
    fillRand(ctx->h_x, -1.0, 1.0);
    fillRand(ctx->h_y, -1.0, 1.0);

    COPY_H2D(ctx->d_x, ctx->h_x.data(), ctx->N * sizeof(double));
    COPY_H2D(ctx->d_y, ctx->h_y.data(), ctx->N * sizeof(double));
}

Context *init() {
    Context *ctx = new Context();

    ctx->N = DRIVER_PROBLEM_SIZE;
    ctx->blockSize = dim3(1024);
    ctx->gridSize = dim3((ctx->N + ctx->blockSize.x - 1) / ctx->blockSize.x); // at least enough threads

    ctx->alpha = 2.0;
    ctx->h_x.resize(ctx->N);
    ctx->h_y.resize(ctx->N);
    ctx->h_z.resize(ctx->N);

    ALLOC(ctx->d_x, ctx->N * sizeof(double));
    ALLOC(ctx->d_y, ctx->N * sizeof(double));
    ALLOC(ctx->d_z, ctx->N * sizeof(double));

    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    axpy<<<ctx->gridSize, ctx->blockSize>>>(ctx->alpha, ctx->d_x, ctx->d_y, ctx->d_z, ctx->N);
}

void NO_OPTIMIZE best(Context *ctx) {
    correctAxpy(ctx->alpha, ctx->h_x, ctx->h_y, ctx->h_z);
}

bool validate(Context *ctx) {
    const size_t TEST_SIZE = 1024;
    dim3 blockSize = dim3(1024);
    dim3 gridSize = dim3((TEST_SIZE + blockSize.x - 1) / blockSize.x); // at least enough threads

    double alpha = 2.0;
    double *d_x, *d_y, *d_z;
    std::vector<double> h_x(TEST_SIZE), h_y(TEST_SIZE), correct(TEST_SIZE), test(TEST_SIZE);

    ALLOC(d_x, TEST_SIZE * sizeof(double));
    ALLOC(d_y, TEST_SIZE * sizeof(double));
    ALLOC(d_z, TEST_SIZE * sizeof(double));

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int trialIter = 0; trialIter < numTries; trialIter += 1) {
        // set up input
        fillRand(h_x, -1.0, 1.0);
        fillRand(h_y, -1.0, 1.0);

        COPY_H2D(d_x, h_x.data(), TEST_SIZE * sizeof(double));
        COPY_H2D(d_y, h_y.data(), TEST_SIZE * sizeof(double));

        // compute correct result
        correctAxpy(alpha, h_x, h_y, correct);

        // compute test result
        axpy<<<gridSize, blockSize>>>(alpha, d_x, d_y, d_z, TEST_SIZE);
        SYNC();

        COPY_D2H(test.data(), d_z, TEST_SIZE * sizeof(double));
        
        if (!fequal(correct, test, 1e-6)) {
            FREE(d_x);
            FREE(d_y);
            FREE(d_z);
            return false;
        }
    }

    FREE(d_x);
    FREE(d_y);
    FREE(d_z);
    return true;
}

void destroy(Context *ctx) {
    FREE(ctx->d_x);
    FREE(ctx->d_y);
    FREE(ctx->d_z);
    delete ctx;
}
