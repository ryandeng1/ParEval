// Driver for 13_geometry_closest_pair_2d for CUDA and HIP
// struct Point {
//     double x, y;
// };
//
// __device__ double distance(Point const& p1, Point const& p2) {
//     return sqrt(pow(p2.x-p1.x, 2) + pow(p2.y-p1.y, 2));
// }
//
// /* Compute the distance between the closest two points in the vector points.
//    Store the result in distance.
//    Use CUDA to compute in parallel. The kernel is launched with at least as many threads as points.
//    Example:
//
//    input: [{2, 3}, {12, 30}, {40, 50}, {5, 1}, {12, 10}, {3, 4}]
//    output: 1.41421
// */
// __global__ void closestPair(const Point *points, size_t numPoints, double *distance) {

#include <algorithm>
#include <numeric>
#include <random>
#include <vector>

#include "utilities.hpp"
#include "generated-code.cuh"   // code generated by LLM
#include "baseline.hpp"


struct Context {
    std::vector<Point> h_points;
    std::vector<double> h_x, h_y;
    Point *d_points;
    double *d_distance;

    size_t N;
    dim3 blockSize, gridSize;
};

void reset(Context *ctx) {
    fillRand(ctx->h_x, -1000.0, 1000.0);
    fillRand(ctx->h_y, -1000.0, 1000.0);
    for (size_t i = 0; i < ctx->N; i++) {
        ctx->h_points[i].x = ctx->h_x[i];
        ctx->h_points[i].y = ctx->h_y[i];
    }

    COPY_H2D(ctx->d_points, ctx->h_points.data(), ctx->N * sizeof(Point));
    FREE(ctx->d_distance);
    ALLOC(ctx->d_distance, sizeof(double));
}

Context *init() {
    Context *ctx = new Context();

    ctx->N = DRIVER_PROBLEM_SIZE;
    ctx->blockSize = dim3(1024);
    ctx->gridSize = dim3((ctx->N + ctx->blockSize.x - 1) / ctx->blockSize.x); // at least enough threads

    ctx->h_points.resize(ctx->N);
    ctx->h_x.resize(ctx->N);
    ctx->h_y.resize(ctx->N);
    ALLOC(ctx->d_points, ctx->N * sizeof(Point));
    ALLOC(ctx->d_distance, sizeof(double));

    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    closestPair<<<ctx->gridSize, ctx->blockSize>>>(ctx->d_points, ctx->N, ctx->d_distance);
}

void NO_OPTIMIZE best(Context *ctx) {
    double distance = correctClosestPair(ctx->h_points);
    (void)distance;
}

bool validate(Context *ctx) {
    const size_t TEST_SIZE = 1024;
    dim3 blockSize = dim3(1024);
    dim3 gridSize = dim3((TEST_SIZE + blockSize.x - 1) / blockSize.x); // at least enough threads

    std::vector<Point> points(TEST_SIZE);
    std::vector<double> x(TEST_SIZE), y(TEST_SIZE);
    double correct = 0.0, test = 0.0;

    Point *d_points;
    double *d_distance;
    ALLOC(d_points, TEST_SIZE * sizeof(Point));
    ALLOC(d_distance, sizeof(double));

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int trialIter = 0; trialIter < numTries; trialIter += 1) {
        // set up input
        fillRand(x, -1000.0, 1000.0);
        fillRand(y, -1000.0, 1000.0);
        test = 0.0;
        correct = 0.0;

        for (size_t i = 0; i < points.size(); i++) {
            points[i].x = x[i];
            points[i].y = y[i];
        }

        COPY_H2D(d_points, points.data(), points.size() * sizeof(Point));
        COPY_H2D(d_distance, &test, sizeof(double));

        // compute correct result
        correct = correctClosestPair(points);

        // compute test result
        closestPair<<<gridSize, blockSize>>>(d_points, TEST_SIZE, d_distance);
        SYNC();

        // copy back
        COPY_D2H(&test, d_distance, sizeof(double));

        if (std::abs(correct - test) > 1e-4) {
            FREE(d_points);
            FREE(d_distance);
            return false;
        }
    }

    FREE(d_points);
    FREE(d_distance);
    return true;
}

void destroy(Context *ctx) {
    FREE(ctx->d_points);
    FREE(ctx->d_distance);
    delete ctx;
}