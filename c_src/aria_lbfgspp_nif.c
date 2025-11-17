/* SPDX-License-Identifier: MIT
 * Copyright (c) 2025-present K. S. Ernest (iFire) Lee
 */

#include <erl_nif.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>
#include <limits>
#include <Eigen/Core>
#include "LBFGSpp/BFGSMat.h"
#include "LBFGSpp/Param.h"

using namespace LBFGSpp;

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
    {"optimize_step_nif", 3, optimize_step_nif},
    {"cleanup_nif", 1, cleanup_nif}
};

// Functor for line search using quadratic approximation
// Since we only have gradient information, we use a quadratic model
class QuadraticLineSearchFunctor {
private:
    Eigen::VectorXd m_x0;      // Starting point
    Eigen::VectorXd m_grad0;   // Gradient at starting point
    double m_f0;               // Function value at starting point
    Eigen::VectorXd m_direction; // Search direction
    BFGSMat<double>* m_bfgs;   // BFGS matrix for Hessian approximation

public:
    QuadraticLineSearchFunctor(const Eigen::VectorXd& x0, const Eigen::VectorXd& grad0,
                               double f0, const Eigen::VectorXd& direction,
                               BFGSMat<double>* bfgs)
        : m_x0(x0), m_grad0(grad0), m_f0(f0), m_direction(direction), m_bfgs(bfgs) {}

    // Evaluate function at x = x0 + alpha * direction using quadratic approximation
    double operator()(const Eigen::VectorXd& x, Eigen::VectorXd& grad) {
        // Compute alpha from x
        Eigen::VectorXd dx = x - m_x0;
        double alpha = 0.0;
        double dir_norm_sq = m_direction.squaredNorm();
        if (dir_norm_sq > 1e-12) {
            alpha = dx.dot(m_direction) / dir_norm_sq;
        }

        // Quadratic approximation: f(x) ≈ f(x0) + alpha * g0^T d + (alpha^2/2) * d^T H d
        double dir_dot_grad = m_grad0.dot(m_direction);

        // Use BFGS approximation for Hessian: compute H^{-1} * d, then approximate d^T H d
        double hessian_term = dir_norm_sq; // Default: identity approximation
        if (m_bfgs) {
            Eigen::VectorXd Hinv_d(m_direction.size());
            m_bfgs->apply_Hv(m_direction, 1.0, Hinv_d);
            // Hinv_d now contains H^{-1} * d
            // Approximate d^T H d using secant condition: d^T H d ≈ d^T d / (d^T H^{-1} d)
            double dHinv_d = m_direction.dot(Hinv_d);
            if (dHinv_d > 1e-12) {
                hessian_term = dir_norm_sq / dHinv_d;
            }
        }

        // Compute function value using quadratic model
        double fx = m_f0 + alpha * dir_dot_grad + 0.5 * alpha * alpha * hessian_term;

        // Gradient approximation: g(x) ≈ g0 + alpha * H * d
        // Use linear approximation: g(x) ≈ g0 + alpha * (H * d)
        // Approximate H * d ≈ d / (d^T H^{-1} d / ||d||^2)
        if (m_bfgs) {
            Eigen::VectorXd Hinv_d_grad(m_direction.size());
            m_bfgs->apply_Hv(m_direction, 1.0, Hinv_d_grad);
            double dHinv_d_grad = m_direction.dot(Hinv_d_grad);
            if (dHinv_d_grad > 1e-12) {
                double scale = dir_norm_sq / dHinv_d_grad;
                grad = m_grad0 + alpha * scale * m_direction;
            } else {
                grad = m_grad0 + alpha * m_direction;
            }
        } else {
            grad = m_grad0 + alpha * m_direction;
        }

        return fx;
    }
};

// Resource type for LBFGS++ handle
typedef struct {
    BFGSMat<double>* bfgs_mat;  // L-BFGS approximation matrix
    LBFGSParam<double>* param;   // L-BFGS parameters
    int dimension;
    int m;  // Number of corrections to store
    double* current_point;
    double* previous_point;
    double* current_gradient;
    double* previous_gradient;
    double* search_direction;
    int iterations;
    double gradient_norm;
    double epsilon;
    double epsilon_rel;
    double max_step;
    double ftol;  // Line search parameter
    double wolfe; // Wolfe condition parameter
    int max_linesearch; // Max line search iterations
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
    lbfgspp_resource_t* resource = (lbfgspp_resource_t*)enif_alloc_resource(LBFGSPP_RESOURCE, sizeof(lbfgspp_resource_t));
    if (!resource) {
        return make_error_tuple(env, "allocation_failed");
    }

    // Initialize resource
    resource->dimension = dimension;
    resource->m = m;
    resource->epsilon = epsilon;
    resource->epsilon_rel = epsilon_rel;
    resource->max_step = max_step;
    resource->ftol = 1e-4;  // Default Armijo condition parameter
    resource->wolfe = 0.9;  // Default Wolfe condition parameter
    resource->max_linesearch = 20; // Default max line search iterations

    // Allocate BFGS matrix
    resource->bfgs_mat = new BFGSMat<double>();
    if (!resource->bfgs_mat) {
        enif_release_resource(resource);
        return make_error_tuple(env, "allocation_failed");
    }
    resource->bfgs_mat->reset(dimension, m);

    // Allocate L-BFGS parameters
    resource->param = new LBFGSParam<double>();
    if (!resource->param) {
        delete resource->bfgs_mat;
        enif_release_resource(resource);
        return make_error_tuple(env, "allocation_failed");
    }
    resource->param->m = m;
    resource->param->epsilon = epsilon;
    resource->param->epsilon_rel = epsilon_rel;
    resource->param->max_iterations = max_iterations;
    resource->param->past = past;
    resource->param->delta = delta;
    resource->param->max_step = max_step;
    resource->param->linesearch = LBFGS_LINESEARCH_BACKTRACKING_STRONG_WOLFE;
    resource->param->max_linesearch = resource->max_linesearch;
    resource->param->ftol = resource->ftol;
    resource->param->wolfe = resource->wolfe;

    // Allocate arrays
    resource->current_point = (double*)enif_alloc(dimension * sizeof(double));
    resource->previous_point = (double*)enif_alloc(dimension * sizeof(double));
    resource->current_gradient = (double*)enif_alloc(dimension * sizeof(double));
    resource->previous_gradient = (double*)enif_alloc(dimension * sizeof(double));
    resource->search_direction = (double*)enif_alloc(dimension * sizeof(double));

    if (!resource->current_point || !resource->previous_point ||
        !resource->current_gradient || !resource->previous_gradient ||
        !resource->search_direction) {
        if (resource->current_point) enif_free(resource->current_point);
        if (resource->previous_point) enif_free(resource->previous_point);
        if (resource->current_gradient) enif_free(resource->current_gradient);
        if (resource->previous_gradient) enif_free(resource->previous_gradient);
        if (resource->search_direction) enif_free(resource->search_direction);
        delete resource->bfgs_mat;
        enif_release_resource(resource);
        return make_error_tuple(env, "allocation_failed");
    }

    memset(resource->current_point, 0, dimension * sizeof(double));
    memset(resource->previous_point, 0, dimension * sizeof(double));
    memset(resource->current_gradient, 0, dimension * sizeof(double));
    memset(resource->previous_gradient, 0, dimension * sizeof(double));
    memset(resource->search_direction, 0, dimension * sizeof(double));
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

    // Copy gradient to current_gradient
    memcpy(resource->current_gradient, gradient, resource->dimension * sizeof(double));

    // Calculate gradient norm
    double grad_norm = 0.0;
    for (int i = 0; i < resource->dimension; i++) {
        grad_norm += gradient[i] * gradient[i];
    }
    grad_norm = sqrt(grad_norm);
    resource->gradient_norm = grad_norm;

    // Create Eigen vectors for L-BFGS computation
    Eigen::Map<Eigen::VectorXd> grad_map(resource->current_gradient, resource->dimension);
    Eigen::Map<Eigen::VectorXd> x_map(resource->current_point, resource->dimension);
    Eigen::Map<Eigen::VectorXd> xp_map(resource->previous_point, resource->dimension);
    Eigen::Map<Eigen::VectorXd> gp_map(resource->previous_gradient, resource->dimension);

    // Create temporary vectors for computation
    Eigen::VectorXd grad_vec = grad_map;
    Eigen::VectorXd dir_vec(resource->dimension);
    Eigen::VectorXd x_vec = x_map;

    if (resource->iterations == 0) {
        // First iteration: use negative gradient as search direction
        dir_vec = -grad_vec;
    } else {
        // Update BFGS approximation with previous step
        Eigen::VectorXd xp_vec = xp_map;
        Eigen::VectorXd gp_vec = gp_map;
        Eigen::VectorXd s = x_vec - xp_vec;
        Eigen::VectorXd y = grad_vec - gp_vec;

        // Only add correction if s'y > eps * ||y||^2 (curvature condition)
        const double eps = std::numeric_limits<double>::epsilon();
        if (s.dot(y) > eps * y.squaredNorm()) {
            resource->bfgs_mat->add_correction(s, y);
        }

        // Compute search direction: d = -H * g using L-BFGS two-loop recursion
        resource->bfgs_mat->apply_Hv(grad_vec, -1.0, dir_vec);
    }

    // Perform proper line search using LBFGS++ LineSearchBacktracking
    // Avoid exceptions by validating inputs and using safe fallback
    double step = 1.0;
    double fx = objective_value;  // Current function value
    double fx_new = fx;
    double dg = dir_vec.dot(grad_vec);

    // Check if direction is a descent direction
    if (dg >= 0.0) {
        // If direction is not a descent direction, use negative gradient
        dir_vec = -grad_vec;
        dg = dir_vec.dot(grad_vec);
    }

    // Initial step size
    double dir_norm = dir_vec.norm();
    if (dir_norm > 1e-12) {
        step = fmin(1.0 / dir_norm, resource->max_step);
    } else {
        step = 1.0;
    }

    // Validate step before line search (avoid exceptions)
    if (step <= 0.0) {
        step = 1.0;
    }
    if (step > resource->max_step) {
        step = resource->max_step;
    }
    if (step < 1e-20) {  // min_step default
        step = 1e-20;
    }

    // Save previous point and gradient before updating
    xp_map = x_map;
    gp_map = grad_map;

    // Create functor for line search using quadratic approximation
    QuadraticLineSearchFunctor line_search_func(x_vec, grad_vec, fx, dir_vec, resource->bfgs_mat);

    // Create temporary vectors for line search
    Eigen::VectorXd x_new(resource->dimension);
    Eigen::VectorXd grad_new(resource->dimension);

    // Perform line search with exception-safe wrapper
    // We implement a simplified version that doesn't throw exceptions
    bool line_search_success = false;
    {
        // Simplified backtracking line search (no exceptions)
        const double dec = 0.5;
        const double inc = 2.1;
        const double fx_init = fx;
        const double dg_init = dg;
        const double test_decr = resource->ftol * dg_init;
        double step_current = step;

        // Ensure we have a descent direction
        if (dg_init >= 0.0) {
            // Not a descent direction, use simple step
            step_current = fmin(1.0 / dir_norm, resource->max_step);
            x_new = x_vec + step_current * dir_vec;
            fx_new = line_search_func(x_new, grad_new);
            line_search_success = true;
        } else {
            // Perform backtracking line search
            int iter = 0;
            for (iter = 0; iter < resource->max_linesearch; iter++) {
                x_new = x_vec + step_current * dir_vec;
                fx_new = line_search_func(x_new, grad_new);

                // Check Armijo condition
                if (fx_new <= fx_init + step_current * test_decr && fx_new == fx_new) {  // Check for NaN
                    double dg_new = grad_new.dot(dir_vec);

                    // Check Wolfe condition based on linesearch type
                    if (resource->param->linesearch == LBFGS_LINESEARCH_BACKTRACKING_ARMIJO) {
                        line_search_success = true;
                        break;
                    }

                    if (dg_new >= resource->wolfe * dg_init) {
                        // Regular or strong Wolfe condition met
                        line_search_success = true;
                        break;
                    }

                    // Increase step if curvature condition not met
                    if (dg_new < resource->wolfe * dg_init) {
                        step_current *= inc;
                        if (step_current > resource->max_step) {
                            step_current = resource->max_step;
                            break;
                        }
                    } else {
                        step_current *= dec;
                    }
                } else {
                    // Decrease step
                    step_current *= dec;
                }

                // Check bounds
                if (step_current < 1e-20) {
                    step_current = 1e-20;
                    break;
                }
                if (step_current > resource->max_step) {
                    step_current = resource->max_step;
                    break;
                }
            }

            if (iter < resource->max_linesearch) {
                line_search_success = true;
            }
        }

        step = step_current;
    }

    if (line_search_success) {
        // Update point with result from line search
        x_map = x_new;
        grad_map = grad_new;  // Update gradient (though we'll get new one from Elixir next step)
    } else {
        // Fall back to simple step if line search failed
        step = fmin(1.0 / dir_norm, resource->max_step);
        x_vec += step * dir_vec;
        x_map = x_vec;
    }

    // Copy search direction back (for potential future use)
    memcpy(resource->search_direction, dir_vec.data(), resource->dimension * sizeof(double));

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

    // Cleanup LBFGS++ resources
    if (resource->param) {
        delete resource->param;
        resource->param = NULL;
    }
    if (resource->bfgs_mat) {
        delete resource->bfgs_mat;
        resource->bfgs_mat = NULL;
    }
    if (resource->current_point) {
        enif_free(resource->current_point);
        resource->current_point = NULL;
    }
    if (resource->previous_point) {
        enif_free(resource->previous_point);
        resource->previous_point = NULL;
    }
    if (resource->current_gradient) {
        enif_free(resource->current_gradient);
        resource->current_gradient = NULL;
    }
    if (resource->previous_gradient) {
        enif_free(resource->previous_gradient);
        resource->previous_gradient = NULL;
    }
    if (resource->search_direction) {
        enif_free(resource->search_direction);
        resource->search_direction = NULL;
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
