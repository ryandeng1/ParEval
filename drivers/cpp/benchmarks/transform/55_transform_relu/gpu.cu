// Driver for 52_transform_relu
// /* Compute the ReLU function on every element of x. Elements less than zero become zero,
//    while elements greater than zero stay the same.
//    Use Kokkos to compute in parallel. Assume Kokkos has already been initialized.
//    Example:
// 
//    input: [-1.8, 24.0, 1.2, 0.0, -5.1, -0.2, 4.5]
//    output: [0, 24.0, 1.2, 0, 0, 0, 4.5]
// */
// void relu(Kokkos::View<double*> &x) {

#include <algorithm>
#include <numeric>
#include <random>
#include <vector>

#include "utilities.hpp"
#include "baseline.hpp"
#include "generated-code.cuh"   // code generated by LLM


struct Context {
    double *x;
    size_t N;
    std::vector<double> cpuX;
    dim3 blockSize, gridSize;
};

void reset(Context *ctx) {
    fillRand(ctx->cpuX, -50.0, 50.0);
    COPY_H2D(ctx->x, ctx->cpuX.data(), ctx->N * sizeof(double));
}

Context *init() {
    Context *ctx = new Context();

    ctx->N = DRIVER_PROBLEM_SIZE;
    ctx->blockSize = dim3(1024);
    ctx->gridSize = dim3((ctx->N + ctx->blockSize.x - 1) / ctx->blockSize.x); // at least enough threads

    ALLOC(ctx->x, ctx->N * sizeof(double));
    ctx->cpuX.resize(ctx->N);

    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    relu<<<ctx->gridSize,ctx->blockSize>>>(ctx->x, ctx->N);
}

void NO_OPTIMIZE best(Context *ctx) {
    correctRelu(ctx->cpuX);
}

bool validate(Context *ctx) {

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int i = 0; i < numTries; i += 1) {
        std::vector<double> input(1024);
        fillRand(input, -50.0, 50.0);

        // compute correct result
        std::vector<double> correctResult = input;
        correctRelu(correctResult);

        // compute test result
        double *testResultDevice;
        ALLOC(testResultDevice, input.size() * sizeof(double));
        COPY_H2D(testResultDevice, input.data(), input.size() * sizeof(double));
        dim3 blockSize = dim3(1024);
        dim3 gridSize = dim3((input.size() + blockSize.x - 1) / blockSize.x); // at least enough threads
        relu<<<gridSize,blockSize>>>(testResultDevice, input.size());
        SYNC();

        std::vector<double> testResult(input.size());
        COPY_D2H(testResult.data(), testResultDevice, testResult.size() * sizeof(double));
        FREE(testResultDevice);
        
        if (!fequal(correctResult, testResult, 1e-6)) {
            return false;
        }
    }

    return true;
}

void destroy(Context *ctx) {
    FREE(ctx->x);
    delete ctx;
}

