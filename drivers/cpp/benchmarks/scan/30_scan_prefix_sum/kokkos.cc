// Driver for 30_scan_prefix_sum for Kokkos
// /* Compute the prefix sum of the vector x into output.
//    Use Kokkos to compute in parallel. Assume Kokkos is already initialized.
//    Example:
//
//    input: [1, 7, 4, 6, 6, 2]
//    output: [1, 8, 12, 18, 24, 26]
// */
// void prefixSum(Kokkos::View<const double*> const& x, Kokkos::View<double*> &output) {

#include <algorithm>
#include <numeric>
#include <random>
#include <vector>

#include "kokkos-includes.hpp"

#include "utilities.hpp"
#include "baseline.hpp"
#include "generated-code.hpp"   // code generated by LLM

struct Context {
    Kokkos::View<double*> x;
    Kokkos::View<double*> x_const;
    Kokkos::View<double*> output;
    std::vector<double> x_host;
    std::vector<double> output_host;
};

void reset(Context *ctx) {
    fillRand(ctx->x_host, -100.0, 100.0);
    copyVectorToView(ctx->x_host, ctx->x);
    ctx->x_const = ctx->x;
}

Context *init() {
    Context *ctx = new Context();
    ctx->x_host.resize(DRIVER_PROBLEM_SIZE);
    ctx->output_host.resize(DRIVER_PROBLEM_SIZE);
    ctx->x = Kokkos::View<double*>("x", DRIVER_PROBLEM_SIZE);
    ctx->output = Kokkos::View<double*>("output", DRIVER_PROBLEM_SIZE);
    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    prefixSum(ctx->x_const, ctx->output);
}

void NO_OPTIMIZE best(Context *ctx) {
    correctPrefixSum(ctx->x_host, ctx->output_host);
}

bool validate(Context *ctx) {
    const size_t TEST_SIZE = 1024;

    std::vector<double> x_host(TEST_SIZE), output_host(TEST_SIZE), test(TEST_SIZE);
    Kokkos::View<double*> x("x", TEST_SIZE), output("output", TEST_SIZE);

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int trialIter = 0; trialIter < numTries; trialIter += 1) {
        // set up input
        fillRand(x_host, -100.0, 100.0);
        copyVectorToView(x_host, x);
        Kokkos::View<const double*> x_const = x;

        // compute correct result
        correctPrefixSum(x_host, output_host);

        // compute test result
        prefixSum(x_const, output);

        // copy to vector
        copyViewToVector(output, test);

        if (!fequal(output_host, test, 1e-6)) {
            return false;
        }
    }

    return true;
}

void destroy(Context *ctx) {
    delete ctx;
}
