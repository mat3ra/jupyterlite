#!/bin/bash
# PYTHON_VERSION="3.10.12"
# NODE_VERSION="18"
THIS_SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGE_ROOT_PATH="$(realpath "${THIS_SCRIPT_DIR_PATH}/../")"
REQUIREMENTS_FILENAME="dependencies/requirements.txt"
TMP_DIR="tmp"
CONTENT_DIR="content"
PYODIDE_VERSION="0.24.1"
PYODIDE_LOCAL_DIR="dist/pyodide"
PYODIDE_LOCAL_URL="./pyodide/pyodide.js"

source "${THIS_SCRIPT_DIR_PATH}"/functions.sh

## Build JupyterLite with extension(s)
cd "${PACKAGE_ROOT_PATH}" || exit 1

export PIP_VERSION=24.3.1
export SETUPTOOLS_VERSION=75.8.0
export WHEEL_VERSION=0.37.1
export BUILD_VERSION=0.7.0
export TWINE_VERSION=3.7.1
export DEV_MODE=${DEV_MODE:-0}

pip install --upgrade \
  pip==$PIP_VERSION \
  setuptools==$SETUPTOOLS_VERSION \
  wheel==$WHEEL_VERSION \
  build==$BUILD_VERSION \
  twine==$TWINE_VERSION

[[ -n ${INSTALL} ]] && python -m pip install -r ${REQUIREMENTS_FILENAME}
pip list

# Update the content dir to latest commit
if [[ -n ${UPDATE_CONTENT} ]]; then
    mkdir -p ${TMP_DIR} && cd ${TMP_DIR} || exit 1
    REPO_NAME="api-examples"
    BRANCH_NAME="experiment/mlff-nb"

    # Always clone fresh to avoid stale cached state
    rm -rf "${REPO_NAME}"
    echo "Cloning ${REPO_NAME} on branch ${BRANCH_NAME}"
    git clone --branch ${BRANCH_NAME} --single-branch https://github.com/Exabyte-io/${REPO_NAME}.git || exit 1
    # or copy with from local:
    # cp -r "/Users/mat3ra/code/GREEN/api-examples" . || exit 1

    # Pull all required files
    cd ${REPO_NAME} || exit 1
    # Install git-lfs and pull LFS files
    git lfs install && git lfs pull
    git --no-pager log --decorate=short --pretty=oneline -n1

    # Re-arrange resolved folders
    cd - || exit 1
    # Resolve links inside the ${REPO_NAME}
    rm -rf ${REPO_NAME}-resolved
    cp -rL ${REPO_NAME} ${REPO_NAME}-resolved
    # Sync with the content directory
    cd "${PACKAGE_ROOT_PATH}" || exit 1
    RESOLVED_CONTENT_DIR="tmp/${REPO_NAME}-resolved"
    rm -rf ${CONTENT_DIR} && mkdir -p ${CONTENT_DIR}
    # Copy the notebooks
    cp -r ${RESOLVED_CONTENT_DIR}/examples ${CONTENT_DIR}/api
    cp -r ${RESOLVED_CONTENT_DIR}/other/materials_designer ${CONTENT_DIR}/made
    cp -r ${RESOLVED_CONTENT_DIR}/other/experiments/jupyterlite ${CONTENT_DIR}/experiments
    # Copy other required files
    cp -r ${RESOLVED_CONTENT_DIR}/{packages,utils,config.yml,README*} ${CONTENT_DIR}/
    # Update path references in README*
    perl -pi -e "s/examples\//api\//g" ${CONTENT_DIR}/README.*

fi


if [[ -n ${BUILD} ]]; then
    jupyter lite build --contents ${CONTENT_DIR} --output-dir dist
    # Pin the IPython version to 8.31.0 -- otherwise it resolves to the latest version requiring Python 3.12+
    find dist/extensions/@jupyterlite/pyodide-kernel-extension/static -name "*.js" \
        | xargs grep -l "install(\['ipython'\]" \
        | xargs perl -i -pe "s/install\(\['ipython'\]/install(\['ipython==8.31.0'\]/g"
    download_pyodide "${PYODIDE_VERSION}" "${PYODIDE_LOCAL_DIR}"
    patch_pyodide_url "dist/jupyter-lite.json" "${PYODIDE_LOCAL_URL}"
    if [[ ${DEV_MODE} == 1 ]]; then
        WHEEL_PATH=$(build_and_copy_mat3ra_wheel "tmp/api-examples" "${PYODIDE_LOCAL_DIR}")
    else
        WHEEL_PATH=$(download_mat3ra_wheel "${PYODIDE_LOCAL_DIR}")
    fi
    patch_pyodide_lock "${PYODIDE_LOCAL_DIR}/pyodide-lock.json" "${WHEEL_PATH}"
    # Example how to patch the pyodide-lock.json file to add a dependency:
    # patch_pyodide_lock_depends "${PYODIDE_LOCAL_DIR}/pyodide-lock.json" "micropip" "pyyaml"
    patch_jupyter_lite_packages "dist/jupyter-lite.json"
fi

# Exit with zero (for GH workflow)
exit 0
