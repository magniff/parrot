/* dynext.c
 *  Copyright: 2001-2003 The Perl Foundation.  All Rights Reserved.
 *  CVS Info
 *     $Id$
 *  Overview:
 *     Dynamic extension stuff
 *  Data Structure and Algorithms:
 *  History:
 *     Initial rev by leo 2003.08.06
 *  Notes:
 *  References:
 */

#include "parrot/parrot.h"
#include "parrot/dynext.h"


/*
 * dynamic library loader
 * the initializer is currently unused
 *
 * calls Parrot_lib_load_%s which performs the registration of the lib once
 *       Parrot_lib_init_%s gets called (if exists) to perform thread specific setup
 */

static void
store_lib_pmc(Parrot_Interp interpreter, PMC* lib_pmc, STRING *path)
{
    PMC *iglobals, *dyn_libs, *prop;
    STRING *key;

    iglobals = interpreter->iglobals;
    dyn_libs = VTABLE_get_pmc_keyed_int(interpreter, iglobals,
            IGLOBALS_DYN_LIBS);
    if (!dyn_libs) {
        dyn_libs = pmc_new(interpreter, enum_class_PerlArray);
        VTABLE_set_pmc_keyed_int(interpreter, iglobals,
                IGLOBALS_DYN_LIBS, dyn_libs);
    }
    /*
     * remember path/file in props
     */
    prop = pmc_new(interpreter, enum_class_PerlString);
    VTABLE_set_string_native(interpreter, prop, path);
    key = string_from_cstring(interpreter, "_filename", 0);
    VTABLE_setprop(interpreter, lib_pmc, key, prop);

    VTABLE_push_pmc(interpreter, dyn_libs, lib_pmc);
}

static PMC*
is_loaded(Parrot_Interp interpreter, STRING *path)
{
    PMC *iglobals, *dyn_libs, *prop, *lib_pmc;
    STRING *key;
    INTVAL i, n;

    iglobals = interpreter->iglobals;
    dyn_libs = VTABLE_get_pmc_keyed_int(interpreter, iglobals,
            IGLOBALS_DYN_LIBS);
    if (!dyn_libs)
        return NULL;
    n = VTABLE_elements(interpreter, dyn_libs);
    key = string_from_cstring(interpreter, "_filename", 0);
    /* we could use an ordered hash for faster lookup here */
    for (i = 0; i < n; i++) {
        lib_pmc = VTABLE_get_pmc_keyed_int(interpreter, dyn_libs, i);
        prop = VTABLE_getprop(interpreter, lib_pmc, key);
        if (!string_compare(interpreter,
                    VTABLE_get_string(interpreter, prop), path))
            return lib_pmc;
    }
    return NULL;
}

/*
 * return path and handle of a dynamic lib
 */
STRING *
get_path(Interp *interpreter, STRING *lib, void **handle)
{
    char *cpath;
    STRING *path;
    /* TODO runtime path for dynamic extensions */
    /* TODO $SO extension */
#ifndef RUNTIME_DYNEXT
#  define RUNTIME_DYNEXT "runtime/parrot/dynext/"
#endif
#ifndef SO_EXTENSION
#  define SO_EXTENSION ".so"
#endif

    /*
     * first look in current dir
     */
    path = Parrot_sprintf_c(interpreter, "%Ss%s",
            lib,
            SO_EXTENSION);
    cpath = string_to_cstring(interpreter, path);
    *handle = Parrot_dlopen(cpath);
    if (!*handle) {
        /*
         * then in runtime/ ...
         */
        /* TODO only if not an absolute path */
        string_cstring_free(cpath);
        path = Parrot_sprintf_c(interpreter, "%s%Ss%s",
                RUNTIME_DYNEXT,
                lib,
                SO_EXTENSION);
        cpath = string_to_cstring(interpreter, path);
        *handle = Parrot_dlopen(cpath);
    }
    if (!*handle) {
        const char * err = Parrot_dlerror();
        fprintf(stderr, "Couldn't load '%s': %s\n",
                cpath, err ? err : "unknow reason");
        /*
         * XXX internal_exception? return a PerlUndef?
         */
        string_cstring_free(cpath);
        return NULL;
    }
    string_cstring_free(cpath);
    return path;
}

PMC *
Parrot_load_lib(Interp *interpreter, STRING *lib, PMC *initializer)
{
    STRING *path, *load_func_name, *init_func_name;
    void * handle;
    PMC *(*load_func)(Interp *);
    void (*init_func)(Interp *, PMC *);
    char *cinit_func_name, *cload_func_name;
    PMC *lib_pmc;

    UNUSED(initializer);
    path = get_path(interpreter, lib, &handle);
    lib_pmc = is_loaded(interpreter, path);
    if (lib_pmc) {
        Parrot_dlclose(handle);
        return lib_pmc;
    }
    load_func_name = Parrot_sprintf_c(interpreter, "Parrot_lib_%Ss_load", lib);
    cload_func_name = string_to_cstring(interpreter, load_func_name);
    load_func = (PMC * (*)(Interp *))D2FPTR(Parrot_dlsym(handle,
                cload_func_name));
    string_cstring_free(cload_func_name);
    if (!load_func) {
        /* seems to be a native/NCI lib */
        lib_pmc = pmc_new(interpreter, enum_class_ConstParrotLibrary);
    }
    else {
        lib_pmc = (*load_func)(interpreter);
        /*
         * TODO call init, if it exists
         */
    }
    PMC_data(lib_pmc) = handle;
    /*
     * remember lib_pmc in iglobals
     */
    store_lib_pmc(interpreter, lib_pmc, path);
    return lib_pmc;
}

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 *
 * vim: expandtab shiftwidth=4:
*/
