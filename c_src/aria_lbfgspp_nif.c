/* SPDX-License-Identifier: MIT
 * Copyright (c) 2025-present K. S. Ernest (iFire) Lee
 */

#include <erl_nif.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>

// Forward declarations
static ERL_NIF_TERM init_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM set_initial_point_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM optimize_step_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM cleanup_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM test_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

// NIF function table
static ErlNifFunc nif_funcs[] = {
    {"test_nif", 0, test_nif},
    {"init_nif", 8, init_nif},
    {"set_initial_point_nif", 2, set_initial_point_nif},
    {"optimize_step_nif", 4, optimize_step_nif},
    {"cleanup_nif", 1, cleanup_nif}
};

// Resource type for LBFGS++ handle
typedef struct {
    void* solver;  // Placeholder for LBFGS++ solver
    int dimension;
    double* current_point;
    int iterations;
    double gradient_norm;
} lbfgspp_resource_t;

static ErlNifResourceType* LBFGSPP_RESOURCE = NULL;

// Helper functions
static int get_double(ErlNifEnv* env, ERL_NIF_TERM term, double* dp) {
    return enif_get_double(env, term, dp);
}

static int get_int(ErlNifEnv* env, ERL_NIF_TERM term, int* ip) {
    return enif_get_int(env, term, ip);
}

static ERL_NIF_TERM make_double(ErlNifEnv* env, double d) {
    return enif_make_double(env, d);
}

static ERL_NIF_TERM make_ok_tuple(ErlNifEnv* env, ERL_NIF_TERM value) {
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), value);
}

static ERL_NIF_TERM make_error_tuple(ErlNifEnv* env, const char* reason) {
    return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_string(env, reason, ERL_NIF_LATIN1));
}

// NIF implementations
static ERL_NIF_TERM test_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM init_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    int dimension;
    double epsilon, delta, max_step, epsilon_rel;
    int max_iterations, m, past;

    if (!get_int(env, argv[0], &dimension) ||
        !get_double(env, argv[1], &epsilon) ||
        !get_int(env, argv[2], &max_iterations) ||
        !get_int(env, argv[3], &m) ||
        !get_int(env, argv[4], &past) ||
        !get_double(env, argv[5], &delta) ||
        !get_double(env, argv[6], &max_step) ||
        !get_double(env, argv[7], &epsilon_rel)) {
        return make_error_tuple(env, "invalid_arguments");
    }

    if (dimension <= 0) {
        return make_error_tuple(env, "invalid_dimension");
    }

    // Allocate resource
    lbfgspp_resource_t* resource = enif_alloc_resource(LBFGSPP_RESOURCE, sizeof(lbfgspp_resource_t));
    if (!resource) {
        return make_error_tuple(env, "allocation_failed");
    }

    // Initialize resource
    resource->dimension = dimension;
    resource->solver = NULL;  // TODO: Initialize actual LBFGS++ solver
    resource->current_point = (double*)enif_alloc(dimension * sizeof(double));
    if (!resource->current_point) {
        enif_release_resource(resource);
        return make_error_tuple(env, "allocation_failed");
    }
    memset(resource->current_point, 0, dimension * sizeof(double));
    resource->iterations = 0;
    resource->gradient_norm = 0.0;

    // Create resource term
    ERL_NIF_TERM resource_term = enif_make_resource(env, resource);
    enif_release_resource(resource);

    return make_ok_tuple(env, resource_term);
}

static ERL_NIF_TERM set_initial_point_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    lbfgspp_resource_t* resource;
    if (!enif_get_resource(env, argv[0], LBFGSPP_RESOURCE, (void**)&resource)) {
        return make_error_tuple(env, "invalid_handle");
    }

    unsigned int list_len;
    if (!enif_get_list_length(env, argv[1], &list_len) || list_len != resource->dimension) {
        return make_error_tuple(env, "invalid_point_dimension");
    }

    ERL_NIF_TERM head, tail = argv[1];
    for (unsigned int i = 0; i < list_len; i++) {
        if (!enif_get_list_cell(env, tail, &head, &tail)) {
            return make_error_tuple(env, "invalid_point_list");
        }
        if (!get_double(env, head, &resource->current_point[i])) {
            return make_error_tuple(env, "invalid_point_value");
        }
    }

    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM optimize_step_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    lbfgspp_resource_t* resource;
    if (!enif_get_resource(env, argv[0], LBFGSPP_RESOURCE, (void**)&resource)) {
        return make_error_tuple(env, "invalid_handle");
    }

    double objective_value;
    if (!get_double(env, argv[1], &objective_value)) {
        return make_error_tuple(env, "invalid_objective_value");
    }

    unsigned int gradient_len;
    if (!enif_get_list_length(env, argv[2], &gradient_len) || gradient_len != resource->dimension) {
        return make_error_tuple(env, "invalid_gradient_dimension");
    }

    double* gradient = (double*)enif_alloc(resource->dimension * sizeof(double));
    if (!gradient) {
        return make_error_tuple(env, "allocation_failed");
    }

    ERL_NIF_TERM head, tail = argv[2];
    for (unsigned int i = 0; i < gradient_len; i++) {
        if (!enif_get_list_cell(env, tail, &head, &tail)) {
            enif_free(gradient);
            return make_error_tuple(env, "invalid_gradient_list");
        }
        if (!get_double(env, head, &gradient[i])) {
            enif_free(gradient);
            return make_error_tuple(env, "invalid_gradient_value");
        }
    }

    // TODO: Call actual LBFGS++ optimize step
    // For now, implement a simple gradient descent step
    double step_size = 0.01;
    for (int i = 0; i < resource->dimension; i++) {
        resource->current_point[i] -= step_size * gradient[i];
    }

    // Calculate gradient norm
    double grad_norm = 0.0;
    for (int i = 0; i < resource->dimension; i++) {
        grad_norm += gradient[i] * gradient[i];
    }
    grad_norm = sqrt(grad_norm);
    resource->gradient_norm = grad_norm;
    resource->iterations++;

    // Build result list
    ERL_NIF_TERM result_list = enif_make_list(env, 0);
    for (int i = resource->dimension - 1; i >= 0; i--) {
        result_list = enif_make_list_cell(env, make_double(env, resource->current_point[i]), result_list);
    }

    enif_free(gradient);

    ERL_NIF_TERM result = enif_make_tuple4(env,
        enif_make_atom(env, "ok"),
        result_list,
        enif_make_int(env, resource->iterations),
        make_double(env, grad_norm)
    );

    return result;
}

static ERL_NIF_TERM cleanup_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    lbfgspp_resource_t* resource;
    if (!enif_get_resource(env, argv[0], LBFGSPP_RESOURCE, (void**)&resource)) {
        return make_error_tuple(env, "invalid_handle");
    }

    // TODO: Cleanup actual LBFGS++ solver
    if (resource->current_point) {
        enif_free(resource->current_point);
        resource->current_point = NULL;
    }

    return enif_make_atom(env, "ok");
}

// NIF module load callback
static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
    LBFGSPP_RESOURCE = enif_open_resource_type(env, NULL, "lbfgspp_resource",
        NULL, ERL_NIF_RT_CREATE, NULL);
    if (!LBFGSPP_RESOURCE) {
        return 1;
    }
    return 0;
}

ERL_NIF_INIT(Elixir.AriaLbfgspp.Native, nif_funcs, load, NULL, NULL, NULL)
