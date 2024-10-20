// Driver for 56_transform_map_function
// bool isPowerOfTwo(int x) {
//     return (x > 0) && !(x & (x - 1));
// }
// 
// /* Apply the isPowerOfTwo function to every value in x and store the results in mask.
//    Example:
//    
//    input: [8, 0, 9, 7, 15, 64, 3]
//    output: [true, false, false, false, false, true, false]
// */
// void mapPowersOfTwo(std::vector<int> const& x, std::vector<bool> &mask) {

#include <algorithm>
#include <numeric>
#include <random>
#include <vector>

#include "utilities.hpp"
#include "generated-code.hpp"   // code generated by LLM
#include "baseline.hpp"

struct Context {
    std::vector<int> x;
    std::vector<bool> mask;
};

void reset(Context *ctx) {
    fillRand(ctx->x, 1, 1025);
    BCAST(ctx->x, INT);
}

Context *init() {
    Context *ctx = new Context();
    ctx->x.resize(DRIVER_PROBLEM_SIZE);
    ctx->mask.resize(DRIVER_PROBLEM_SIZE);
    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    mapPowersOfTwo(ctx->x, ctx->mask);
}

void NO_OPTIMIZE best(Context *ctx) {
    correctMapPowersOfTwo(ctx->x, ctx->mask);
}

bool validate(Context *ctx) {

    int rank;
    GET_RANK(rank);

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int i = 0; i < numTries; i += 1) {
        std::vector<int> input(1024);
        fillRand(input, 1, 1025);
        BCAST(input, INT);

        // compute correct result
        std::vector<bool> correctResult(input.size());
        correctMapPowersOfTwo(input, correctResult);

        // compute test result
        std::vector<bool> testResult(input.size());
        mapPowersOfTwo(input, testResult);
        SYNC();
        
        bool isCorrect = true;
        if (IS_ROOT(rank) && !std::equal(correctResult.begin(), correctResult.end(), testResult.begin())) {
            isCorrect = false;
        }
        BCAST_PTR(&isCorrect, 1, CXX_BOOL);
        if (!isCorrect) {
            return false;
        }
    }

    return true;
}

void destroy(Context *ctx) {
    delete ctx;
}


