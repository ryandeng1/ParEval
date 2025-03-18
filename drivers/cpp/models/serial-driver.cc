/* Main driver for generated serial C++ code. This relies on five externally available
* functions:
*
*   - init() -- returns a pointer to a context object
*   - compute(Context *ctx) -- runs the benchmark
*   - best(Context *ctx) -- runs the best sequential code
*   - validate(Context *ctx) -- returns true if the benchmark is valid
*   - reset(Context *ctx) -- resets the benchmark
*   - destroy(Context *ctx) -- frees the context object
*
* These functions are defined in the driver for the given benchmark and handle
* the data and calling the generated code.
*/
#include <chrono>
#include <cstdio>
#include <string>
#include <cfloat>
#include <random>
#include <nanobench.h>

class Context;
extern "C++" {
    /* todo -- these could all be in a class, but I'm not sure if virtual 
       overloading would incur a noticable overhead here. */
    Context *init();
    void compute(Context *ctx);
    void best(Context *ctx);
    bool validate(Context *ctx, std::mt19937& engine);
    void reset(Context *ctx, std::mt19937& engine);
    void destroy(Context *ctx);
}

int main(int argc, char **argv) {

    /* initialize settings from arguments */
    if (argc > 2) {
        printf("Usage: %s <?niter>\n", argv[0]);
        exit(1);
    }

    int NITER = 10;
    if (argc > 1) {
        NITER = std::stoi(std::string(argv[1]));
    }

    /* initialize */
    Context *ctx = init();

    std::mt19937 engine;

    for (int i = 0; i < NITER; i += 1) {
        engine.seed(i);

        const bool isValid = validate(ctx, engine);
        if (!isValid) {
            printf("Validation: FAIL\n");
            destroy(ctx);
            return 0;
        }
    }

    printf("Validation: PASS\n");

    // validate 
    /*
    const bool isValid = validate(ctx);
    printf("Validation: %s\n", isValid ? "PASS" : "FAIL");
    if (!isValid) {
        destroy(ctx);
        return 0;
    }
    */

    const int NUM_WARMUP_ITER = 3;

    /*
    for (int i = 0; i < NUM_WARMUP_ITER; i++) {
        engine.seed(i);
        reset(ctx, engine);
        compute(ctx);
    }

    // benchmark
    double totalTime = 0.0;
    for (int i = 0; i < NITER; i += 1) {
        engine.seed(i);
        reset(ctx, engine);

        auto start = std::chrono::high_resolution_clock::now();
        compute(ctx);
        auto end = std::chrono::high_resolution_clock::now();
        totalTime += std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
        // totalTime += std::chrono::duration_cast<std::chrono::duration<double>>(end - start).count();
        // reset(ctx);
    }
    // convert back to seconds
    totalTime = totalTime / 1e6;
    printf("Time: %.*f\n", DBL_DIG-1, totalTime / NITER);

    for (int i = 0; i < NUM_WARMUP_ITER; i++) {
	engine.seed(i);
        reset(ctx, engine);
        best(ctx);
    }

    // benchmark best 
    totalTime = 0.0;
    for (int i = 0; i < NITER; i += 1) {
        engine.seed(i);
        reset(ctx, engine);

        auto start = std::chrono::high_resolution_clock::now();
        best(ctx);
        auto end = std::chrono::high_resolution_clock::now();
        totalTime += std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
        // totalTime += std::chrono::duration_cast<std::chrono::duration<double>>(end - start).count();
        // reset(ctx);
    }

    // convert back to seconds
    totalTime = totalTime / 1e6;
    printf("BestSequential: %.*f\n", DBL_DIG-1, totalTime / NITER);
    */

    ankerl::nanobench::Bench bench_llm;
    for (int i = 0; i < NITER; i += 1) {
	engine.seed(i);
        reset(ctx, engine);

	bench_llm.run("llm code", [&]() {
	    compute(ctx);
	});
    }

    std::vector<double> runtimes_llm;
    for (int i = 0; i < NITER; i++) {
    	auto const& r_llm = bench_llm.results()[i];
    	auto time_llm = r_llm.median(ankerl::nanobench::Result::Measure::elapsed);
	runtimes_llm.push_back(time_llm);
    }

    auto avg_time_llm = std::reduce(runtimes_llm.begin(), runtimes_llm.end()) / static_cast<double>(NITER);

    printf("Time: %.17g\n", avg_time_llm);

    ankerl::nanobench::Bench bench_baseline;
    for (int i = 0; i < NITER; i += 1) {
	engine.seed(i);
        reset(ctx, engine);

	bench_baseline.run("baseline code", [&]() {
	    best(ctx);
	});
    }

    std::vector<double> runtimes_baseline;
    for (int i = 0; i < NITER; i++) {
    	auto const& r_baseline = bench_baseline.results()[i];
    	auto time_baseline = r_baseline.median(ankerl::nanobench::Result::Measure::elapsed);
	runtimes_baseline.push_back(time_baseline);
    }

    auto avg_time_baseline = std::reduce(runtimes_baseline.begin(), runtimes_baseline.end()) / static_cast<double>(NITER);

    printf("BestSequential: %.*f\n", DBL_DIG-1, avg_time_baseline);

    /* cleanup */
    destroy(ctx);

    return 0;
}

