export GITHUB_TOKEN=$(cat ~/.logins/gh)
export GITLAB_TOKEN_NAME=flux
export GITLAB_TOKEN=$(cat ~/.logins/gl)
export GITHUB_USER=$(whoami)
export GITLAB_USER=$(whoami)
export LAB_CORE_HOST=https://gitlab.com
export LAB_CORE_TOKEN=$(cat ~/.logins/gl)
export LAB_CORE_USER=$(whoami)
. <(flux completion bash)
source <(lab completion)
